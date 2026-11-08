// Saves the public club directory from the API into src/data/venues.json, the snapshot every build reads (the build
// itself never goes to the network, so a build is reproducible and a down API cannot break one). Run before a
// production build, and again whenever clubs change:
//   npm run venues                                  # https://api.rallyto.ir
//   VENUES_API=http://localhost:5100 npm run venues # a local API
//   VENUES_FROM=clubs.json npm run venues           # a saved answer, same shape, while the API is down
// The API lists active clubs only (owner decision 2026-11-01); this script keeps exactly the published fields, so nothing
// else can reach the site even if the API ever returned more, and refuses an API too old to send the contact details.
import { readFile, writeFile } from 'node:fs/promises'

const API = (process.env.VENUES_API ?? 'https://api.rallyto.ir').replace(/\/$/, '')
const FILE = process.env.VENUES_FROM
const url = FILE ?? `${API}/api/v1/public/venues`

async function fromApi() {
  const response = await fetch(url, { headers: { Accept: 'application/json' } })
  if (!response.ok) throw new Error(`${url} answered ${response.status}`)
  return response.json()
}

const text = (value) => (typeof value === 'string' && value.trim() ? value.trim() : null)
const number = (value) => (typeof value === 'number' && Number.isFinite(value) ? value : null)

const body = FILE ? JSON.parse(await readFile(FILE, 'utf8')) : await fromApi()
const list = Array.isArray(body) ? body : body?.data
if (!Array.isArray(list)) throw new Error(`${url} did not return a list of clubs`)

const clubs = list.map((v, i) => {
  const club = {
    name: String(v.name ?? '').trim(),
    provinceId: Number(v.provinceId),
    provinceName: String(v.provinceName ?? '').trim(),
    cityId: Number(v.cityId),
    cityName: String(v.cityName ?? '').trim(),
    sports: Array.isArray(v.sports) ? v.sports.map(String) : [],
    address: text(v.address),
    phone: text(v.phone),
    latitude: number(v.latitude),
    longitude: number(v.longitude),
    googlePlaceId: text(v.googlePlaceId),
    workingHours: text(v.workingHours),
    website: text(v.website),
    instagram: text(v.instagram),
    telegram: text(v.telegram),
    description: text(v.description),
  }
  if (!('address' in v)) throw new Error(`${url} sends no contact details; deploy the current API first`)
  if (!club.name || !club.provinceName || !club.cityName || !Number.isInteger(club.cityId) || !Number.isInteger(club.provinceId))
    throw new Error(`club #${i} is incomplete: ${JSON.stringify(v)}`)
  return club
})

await writeFile(new URL('../src/data/venues.json', import.meta.url), `${JSON.stringify(clubs, null, 2)}\n`)
console.log(`saved ${clubs.length} clubs from ${url}`)
