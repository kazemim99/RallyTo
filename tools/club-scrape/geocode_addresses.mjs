// Proposes an address, from the map, for each published club whose catalog address is only its city's name. Nothing is
// stored by this script: it writes output/address_proposal.json for review, which the update then uses.
//   node geocode_addresses.mjs
// Source: OpenStreetMap through Nominatim's public reverse geocoder, one request a second as its policy asks, answers
// cached in output/geocode_cache.json so a rerun asks nothing again. © OpenStreetMap contributors, ODbL.
//
// The format is the catalog's own: «شهر، محله، مجموعه، خیابان». A part is left out rather than guessed, and a club keeps
// no address when the map adds nothing to its city, or names another city there (then the pin or the map is wrong).
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'

const VENUES = new URL('../../rallyto-landing/src/data/venues.json', import.meta.url)
const OUT = new URL('./output/', import.meta.url)
const CACHE = new URL('geocode_cache.json', OUT)
const PROPOSAL = new URL('address_proposal.json', OUT)
const GEOCODER = 'https://nominatim.openstreetmap.org/reverse'

const fa = (s) => s.replace(/ي/g, 'ی').replace(/ك/g, 'ک').replace(/\d/g, (d) => '۰۱۲۳۴۵۶۷۸۹'[+d]).replace(/\s+/g, ' ').trim()
const squash = (s) => fa(s).replace(/[\s‌]+/g, '')
const place = (s) => fa(s ?? '').replace(/^(شهر|شهرستان)\s+/, '')
const persian = (s) => !!s && !/[A-Za-z]/.test(s)
// Administrative names say nothing to a visitor looking for the club.
const administrative = (s) => /^(منطقه|ناحیه|بخش|ایران|شهر |شهرستان|دهستان)/.test(fa(s))
const VENUE = /ورزش|باشگاه|سالن|مجموعه|مجتمع|استادیوم|تنیس|بدمینتون|پدل|اسکواش/
// A hall named for another sport would send a visitor looking for the wrong sign.
const OTHER_SPORT = /جودو|کشتی|شنا|استخر|فوتبال|والیبال|بسکتبال|کاراته|تیراندازی/
// «اول» or «سی و دوم» is a side street of something the map does not name.
const ORDINAL = /^(فرعی )?(اول|دوم|سوم|چهارم|پنجم|ششم|هفتم|هشتم|نهم|دهم|[^ ]+ و [^ ]+م)$/

export function proposeAddress(club, answer) {
  const a = answer.address ?? {}
  const city = squash(club.cityName)
  const named = [a.city, a.town, a.village, a.county].filter(Boolean).map(place).map(squash)
  if (!named.some((n) => n === city || n.includes(city) || city.includes(n))) return { reject: `نقشه: ${a.city ?? a.town ?? a.county ?? '?'}` }

  const detail = []
  const area = [a.neighbourhood, a.quarter, a.suburb, a.residential, a.hamlet, a.village, a.city_district].find((v) => v && persian(v) && !administrative(v))
  if (area) detail.push(fa(area))
  const venue = a.leisure ?? a.amenity ?? a.building
  if (persian(venue) && VENUE.test(venue) && !OTHER_SPORT.test(venue)) detail.push(fa(venue))
  if (persian(a.road) && !/_link$/.test(answer.type ?? '')) {
    const road = fa(a.road).replace(/\s*-\s*/g, ' - ')
    if (/^[۰-۹]+$/.test(road)) {
      if (/^(trunk|primary|secondary|tertiary|motorway)$/.test(answer.type ?? '')) detail.push(`جاده ${road}`)
    } else if (/^(trunk|motorway)$/.test(answer.type ?? '') && !/^(جاده|بزرگراه|آزادراه|اتوبان)/.test(road)) detail.push(`جاده ${road}`)
    else if (!/^خروجی/.test(road) && !ORDINAL.test(road)) detail.push(road)
  }
  // A rural district is the last resort: it is too wide when the map knows a street, and often wrong inside a city.
  if (detail.length === 0) {
    const rural = [a.city, a.town, a.village].find((v) => v && /^دهستان/.test(fa(v)))
    if (rural) detail.push(fa(rural))
  }
  const parts = [fa(club.cityName)]
  for (const part of detail) if (!parts.some((p) => squash(p).includes(squash(part)))) parts.push(part)
  return parts.length > 1 ? { address: parts.join('، ') } : { reject: 'نقشه جزئیاتی بیش از شهر ندارد' }
}

async function reverse(club, zoom) {
  const url = `${GEOCODER}?format=jsonv2&lat=${club.latitude}&lon=${club.longitude}&zoom=${zoom}&addressdetails=1&accept-language=fa`
  const response = await fetch(url, { headers: { 'User-Agent': 'rallyto-catalog/1.0 (https://rallyto.ir)' }, signal: AbortSignal.timeout(30000) })
  if (!response.ok) throw new Error(`the geocoder answered ${response.status}`)
  await new Promise((resolve) => setTimeout(resolve, 1200))
  return response.json()
}

mkdirSync(OUT, { recursive: true })
const cache = existsSync(CACHE) ? JSON.parse(readFileSync(CACHE, 'utf8')) : {}
const clubs = JSON.parse(readFileSync(VENUES, 'utf8'))
const missing = clubs.filter((c) => (!c.address || squash(c.address) === squash(c.cityName)) && c.latitude !== null && c.longitude !== null && c.googlePlaceId)
const rows = []
for (const club of missing) {
  // Closest first; when that says nothing, the coarser zoom may still name the main road the club is on.
  let result
  for (const zoom of [18, 16]) {
    const key = zoom === 18 ? club.googlePlaceId : `${club.googlePlaceId}@${zoom}`
    cache[key] ??= await reverse(club, zoom)
    writeFileSync(CACHE, JSON.stringify(cache))
    result = proposeAddress(club, cache[key])
    if (result.address) break
  }
  rows.push({ placeId: club.googlePlaceId, name: club.name, city: club.cityName, ...result })
}
writeFileSync(PROPOSAL, `${JSON.stringify(rows, null, 1)}\n`)

const usable = rows.filter((r) => r.address)
console.log(`${missing.length} clubs without an address, ${usable.length} with a proposal\n`)
for (const r of usable) console.log(`${r.name} => ${r.address}`)
console.log('\nleft without one:')
for (const r of rows.filter((x) => !x.address)) console.log(`${r.name} (${r.city}): ${r.reject}`)
