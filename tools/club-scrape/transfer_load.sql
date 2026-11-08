-- Loads the venue catalog bundle (transfer.sh) into a database whose catalog is empty. All or nothing: any failed check
-- or mismatch rolls the whole load back. Accounts, matches and every other context are not touched.
\set ON_ERROR_STOP on
\cd /tmp/rallyto-transfer
begin;

create temp table want_sports (id uuid, code text) on commit drop;
create temp table want_cities (id int, name text) on commit drop;
\copy want_sports from 'sports.csv' csv header
\copy want_cities from 'cities.csv' csv header

do $$
declare n int;
begin
  select count(*) into n from catalog.venues;
  if n > 0 then raise exception 'catalog.venues already has % rows; nothing loaded', n; end if;
  select count(*) into n from want_sports w left join catalog.sports s on s.id = w.id and s.code = w.code where s.id is null;
  if n > 0 then raise exception '% sports differ from the bundle; nothing loaded', n; end if;
  select count(*) into n from want_cities w left join catalog.cities c on c.id = w.id and c.name = w.name where c.id is null;
  if n > 0 then raise exception '% cities differ from the bundle; nothing loaded', n; end if;
end $$;

\copy catalog.venues (id, name, normalized_name, city_id, address, phone, latitude, longitude, status, google_place_id, created_at, created_by, last_modified_at, last_modified_by, amenities, court_types, description, instagram, source_ref, source_url, tagline, telegram, website, working_hours, google_rating, google_review_count) from 'venues.csv' csv header
\copy catalog.venue_sports (id, sport_id, court_count, setting, surface, has_lighting, venue_id) from 'venue_sports.csv' csv header
\copy catalog.venue_images (id, path, sort_order, venue_id) from 'venue_images.csv' csv header

select setval(pg_get_serial_sequence('catalog.venue_sports', 'id'), (select max(id) from catalog.venue_sports));
select setval(pg_get_serial_sequence('catalog.venue_images', 'id'), (select max(id) from catalog.venue_images));

select status, count(*) from catalog.venues group by 1 order by 1;
select (select count(*) from catalog.venue_sports) as sport_rows, (select count(*) from catalog.venue_images) as photo_rows;
commit;
