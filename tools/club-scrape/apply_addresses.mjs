// Stores the reviewed proposal of geocode_addresses.mjs, in the two places a club's address lives:
//   node apply_addresses.mjs sql        writes output/address_update.sql for the catalog database
//   node apply_addresses.mjs snapshot   updates rallyto-landing/src/data/venues.json, the site's saved directory
// Both change only a published club whose address is still just its city's name, so neither can overwrite an address
// someone has entered since, reach a hidden club, or change any other field. The SQL rolls back unless every proposed
// club was updated.
import { readFileSync, writeFileSync } from 'node:fs'

const OUT = new URL('./output/', import.meta.url)
const VENUES = new URL('../../rallyto-landing/src/data/venues.json', import.meta.url)
const squash = (s) => s.replace(/[\s‌]+/g, '')
const quote = (s) => `'${s.replace(/'/g, "''")}'`
const proposal = JSON.parse(readFileSync(new URL('address_proposal.json', OUT), 'utf8')).filter((r) => r.address)

function sql() {
  const values = proposal.map((r) => `  (${quote(r.placeId)}, ${quote(r.address)})`).join(',\n')
  const script = `\\set ON_ERROR_STOP on
begin;
create temp table proposed (place_id text primary key, address text not null) on commit drop;
insert into proposed values
${values};
update catalog.venues v set address = p.address, last_modified_at = now()
from proposed p, catalog.cities c
where v.google_place_id = p.place_id
  and v.status = 'Active'
  and c.id = v.city_id
  and regexp_replace(v.address, '[[:space:]‌]+', '', 'g') = regexp_replace(c.name, '[[:space:]‌]+', '', 'g');
do $check$
declare still_missing int;
begin
  select count(*) into still_missing from proposed p where not exists (select 1 from catalog.venues v where v.google_place_id = p.place_id and v.address = p.address and v.status = 'Active');
  if still_missing > 0 then raise exception '% proposed clubs were not updated', still_missing; end if;
end $check$;
commit;
select 'updated', count(*) from catalog.venues v where v.address like '%،%' and v.last_modified_at > now() - interval '1 minute';
`
  writeFileSync(new URL('address_update.sql', OUT), script)
  console.log(`output/address_update.sql: ${proposal.length} clubs`)
}

function snapshot() {
  const clubs = JSON.parse(readFileSync(VENUES, 'utf8'))
  const byPlace = new Map(proposal.map((r) => [r.placeId, r.address]))
  let changed = 0
  for (const club of clubs) {
    const address = byPlace.get(club.googlePlaceId)
    if (address && squash(club.address ?? '') === squash(club.cityName)) {
      club.address = address
      changed++
    }
  }
  if (changed !== proposal.length) throw new Error(`${changed} of ${proposal.length} clubs matched; nothing written`)
  writeFileSync(VENUES, `${JSON.stringify(clubs, null, 2)}\n`)
  console.log(`venues.json: ${changed} clubs`)
}

const command = { sql, snapshot }[process.argv[2]]
if (!command) throw new Error('usage: apply_addresses.mjs sql|snapshot')
command()
