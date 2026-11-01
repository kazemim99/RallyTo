// Saves the public club directory from the API into src/data/venues.json, the snapshot every build reads (the build
// itself never goes to the network, so a build is reproducible and a down API cannot break one). Run before a
// production build, and again whenever clubs change:
//   npm run venues                                  # https://api.rallyto.ir
//   VENUES_API=http://localhost:5100 npm run venues # a local API
// The API lists active clubs only, with name, sports, province and city (owner decision 2026-11-01); this script
// keeps exactly those fields, so nothing else can reach the site even if the API ever returned more.
import { writeFile } from 'node:fs/promises'

const API = (process.env.VENUES_API ?? 'https://api.rallyto.ir').replace(/\/$/, '')
const url = `${API}/api/v1/public/venues`

const response = await fetch(url, { headers: { Accept: 'application/json' } })
if (!response.ok) throw new Error(`${url} answered ${response.status}`)
const body = await response.json()
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
  }
  if (!club.name || !club.provinceName || !club.cityName || !Number.isInteger(club.cityId) || !Number.isInteger(club.provinceId))
    throw new Error(`club #${i} is incomplete: ${JSON.stringify(v)}`)
  return club
})

await writeFile(new URL('../src/data/venues.json', import.meta.url), `${JSON.stringify(clubs, null, 2)}\n`)
console.log(`saved ${clubs.length} clubs from ${url}`)
