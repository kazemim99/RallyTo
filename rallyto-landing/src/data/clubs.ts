// The club directory: every active club in Rallyto's catalog, by province, city and sport, as `npm run venues` saved it
// from the API's public directory (GET /api/v1/public/venues). Owner decision 2026-11-01: a club is published with its
// name, sports, province and city and what it takes to reach it (address, phone, map, hours, its own links); a fact the
// catalog does not have stays empty, and hidden clubs are not in the directory at all (the API leaves them out).
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import type { Crumb } from '../lib/seo'
import { SPORTS, type Sport } from './sports'
import snapshot from './venues.json'

export interface ClubRecord {
  name: string
  provinceId: number
  provinceName: string
  cityId: number
  cityName: string
  sports: string[]
  address: string | null
  phone: string | null
  latitude: number | null
  longitude: number | null
  googlePlaceId: string | null
  workingHours: string | null
  website: string | null
  instagram: string | null
  telegram: string | null
  description: string | null
}

export interface ClubPhone {
  text: string
  href: string
}

export interface ClubMapLinks {
  google: string
  balad: string
}

export interface Club {
  name: string
  /** The club's own page: its URL segment, unique within its city, and the full path. */
  slug: string
  path: string
  sports: Sport[]
  /** The street-level address; null when the catalog holds no more than the city's name. */
  address: string | null
  phone: ClubPhone | null
  latitude: number | null
  longitude: number | null
  map: ClubMapLinks | null
  workingHours: string | null
  website: string | null
  instagram: string | null
  telegram: string | null
  description: string | null
}

export interface CityGroup {
  id: number
  name: string
  slug: string
  path: string
  clubs: Club[]
}

export interface ProvinceGroup {
  id: number
  name: string
  slug: string
  path: string
  cities: CityGroup[]
  clubCount: number
}

/**
 * A page lists at least this many clubs before search engines are invited to index it; a page with fewer is still
 * built and linked (a visitor from that town wants it) but carries `noindex` and stays out of the sitemap.
 */
export const INDEX_MIN_CLUBS = 2

export const CLUBS_PATH = '/clubs'

/**
 * The saved directory. `LANDING_VENUES` (a path from the project folder) points the test build and the tests at a
 * fixture; every other build reads the snapshot.
 */
export function loadClubRecords(): ClubRecord[] {
  const override = process.env.LANDING_VENUES
  return override ? (JSON.parse(readFileSync(resolve(process.cwd(), override), 'utf8')) as ClubRecord[]) : (snapshot as ClubRecord[])
}

/** A URL segment for a Persian place name: spaces and zero-width non-joiners become hyphens; nothing else changes. */
export function placeSlug(name: string): string {
  return name.trim().replace(/[\s‌]+/g, '-')
}

/**
 * A URL segment for a club name: every run of characters that is not a letter, a mark or a digit (spaces, zero-width
 * non-joiners, brackets, commas) becomes one hyphen. A name that would read as a sport segment of the same city gets a
 * suffix, so a club page never takes the URL of a sport page.
 */
export function clubSlug(name: string): string {
  const slug = name.trim().replace(/[^\p{L}\p{M}\p{N}]+/gu, '-').replace(/^-+|-+$/g, '')
  return sportBySlug.has(slug.toLowerCase() as Sport['slug']) ? `${slug}-club` : slug
}

const present = (value: string | null | undefined): string | null => value?.trim() || null
const withoutSpaces = (value: string) => value.replace(/[\s‌]+/g, '')

/** The address to show. Some imported clubs hold only their city's name there, which is not an address to go to. */
export function exactAddress(address: string | null | undefined, cityName: string): string | null {
  const text = present(address)
  return text && withoutSpaces(text) !== withoutSpaces(cityName) ? text : null
}

export function phoneOf(phone: string | null | undefined): ClubPhone | null {
  const text = present(phone)
  return text ? { text, href: `tel:${text.replace(/[^\d+]/g, '')}` } : null
}

/** Links to the club's position; on Google Maps to the place itself when its id is known, so the pin carries its name. */
export function mapLinks(latitude: number | null, longitude: number | null, placeId: string | null): ClubMapLinks | null {
  if (latitude === null || longitude === null) return null
  const place = placeId ? `&query_place_id=${encodeURIComponent(placeId)}` : ''
  return {
    google: `https://www.google.com/maps/search/?api=1&query=${latitude},${longitude}${place}`,
    balad: `https://balad.ir/location?latitude=${latitude}&longitude=${longitude}&zoom=17`,
  }
}

/** The club's description, unless it is a research note that says it is not sure: the list states only what we know. */
export function certainDescription(description: string | null | undefined): string | null {
  const text = present(description)
  return text && !/احتمال|تأیید نشده|تایید نشده/.test(text) ? text : null
}

/** A club's own link, only if it really is a web address. */
export function ownLink(url: string | null | undefined): string | null {
  const text = present(url)
  return text && /^https?:\/\//i.test(text) ? text : null
}

const faOrder = new Intl.Collator('fa-IR')
const sportBySlug = new Map(SPORTS.map((s) => [s.slug, s]))

/** Groups the records by province and city, in Persian order; sports in the site's order; unknown sports dropped. */
export function groupClubs(records: readonly ClubRecord[]): ProvinceGroup[] {
  const provinces = new Map<number, ProvinceGroup>()
  for (const r of records) {
    const sports = SPORTS.filter((s) => r.sports.includes(s.slug))
    if (sports.length === 0) continue
    let province = provinces.get(r.provinceId)
    if (!province) {
      const slug = placeSlug(r.provinceName)
      province = { id: r.provinceId, name: r.provinceName, slug, path: `${CLUBS_PATH}/${slug}`, cities: [], clubCount: 0 }
      provinces.set(r.provinceId, province)
    }
    let city = province.cities.find((c) => c.id === r.cityId)
    if (!city) {
      const slug = placeSlug(r.cityName)
      city = { id: r.cityId, name: r.cityName, slug, path: `${province.path}/${slug}`, clubs: [] }
      province.cities.push(city)
    }
    city.clubs.push({
      name: r.name.trim(),
      slug: '',
      path: '',
      sports,
      address: exactAddress(r.address, r.cityName),
      phone: phoneOf(r.phone),
      latitude: r.latitude,
      longitude: r.longitude,
      map: mapLinks(r.latitude, r.longitude, r.googlePlaceId),
      workingHours: present(r.workingHours),
      website: ownLink(r.website),
      instagram: ownLink(r.instagram),
      telegram: ownLink(r.telegram),
      description: certainDescription(r.description),
    })
    province.clubCount += 1
  }
  const list = [...provinces.values()].sort((a, b) => faOrder.compare(a.name, b.name))
  for (const p of list) {
    p.cities.sort((a, b) => faOrder.compare(a.name, b.name))
    for (const c of p.cities) {
      c.clubs.sort((a, b) => faOrder.compare(a.name, b.name))
      // Two records of one name in one city (two branches) get -2, -3 in the order the catalog lists them.
      const taken = new Set<string>()
      for (const club of c.clubs) {
        const base = clubSlug(club.name)
        let slug = base
        for (let n = 2; taken.has(slug); n++) slug = `${base}-${n}`
        taken.add(slug)
        club.slug = slug
        club.path = `${c.path}/${slug}`
      }
    }
  }
  return list
}

/** A club with the city and province it belongs to, for its own page. */
export interface PlacedClub {
  club: Club
  city: CityGroup
  province: ProvinceGroup
}

export function allClubs(directory: readonly ProvinceGroup[] = DIRECTORY): PlacedClub[] {
  return directory.flatMap((province) => province.cities.flatMap((city) => city.clubs.map((club) => ({ club, city, province }))))
}

/**
 * Where in its city a club is, as its address says it: the first part after the city's name («تهران، سعادت‌آباد، …» is
 * سعادت‌آباد). Null when the address names nothing more than the city. Nothing is inferred beyond the address.
 */
export function areaOf(club: Club, cityName: string): string | null {
  if (!club.address) return null
  const parts = club.address.split(/[،,]/).map((s) => s.trim()).filter(Boolean)
  const rest = withoutSpaces(parts[0] ?? '') === withoutSpaces(cityName) ? parts.slice(1) : parts
  return rest[0] ?? null
}

/** Great-circle distance in kilometres between two clubs that both have a position; null otherwise. */
export function distanceKm(a: Club, b: Club): number | null {
  if (a.latitude === null || a.longitude === null || b.latitude === null || b.longitude === null) return null
  const rad = Math.PI / 180
  const dLat = (b.latitude - a.latitude) * rad
  const dLng = (b.longitude - a.longitude) * rad
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.latitude * rad) * Math.cos(b.latitude * rad) * Math.sin(dLng / 2) ** 2
  return 2 * 6371 * Math.asin(Math.sqrt(h))
}

/**
 * Other clubs of the same city that share a sport with this one, nearest first when both have a position (then the
 * rest in Persian order), for the club page's "nearby" list.
 */
export function nearbyClubs(club: Club, city: CityGroup, limit: number): { club: Club; km: number | null }[] {
  return city.clubs
    .filter((c) => c !== club && c.sports.some((s) => club.sports.includes(s)))
    .map((c) => ({ club: c, km: distanceKm(club, c) }))
    .sort((a, b) => (a.km ?? Infinity) - (b.km ?? Infinity) || faOrder.compare(a.club.name, b.club.name))
    .slice(0, limit)
}

export function clubsOf(city: CityGroup, sport: Sport): Club[] {
  return city.clubs.filter((c) => c.sports.includes(sport))
}

/** The sports a city has at least one club for, in the site's order. */
export function sportsIn(city: CityGroup): Sport[] {
  return SPORTS.filter((s) => city.clubs.some((c) => c.sports.includes(s)))
}

export function citySportPath(city: CityGroup, sport: Sport): string {
  return `${city.path}/${sport.slug}`
}

export function sportFromSlug(slug: string): Sport | undefined {
  return sportBySlug.get(slug as Sport['slug'])
}

/** The directory as built: grouped once per build. Empty while the snapshot is empty, and then nothing is built. */
export const DIRECTORY: ProvinceGroup[] = groupClubs(loadClubRecords())

export const directoryPublished = (): boolean => DIRECTORY.length > 0

export const totalClubs = (directory: readonly ProvinceGroup[] = DIRECTORY): number =>
  directory.reduce((n, p) => n + p.clubCount, 0)

/** Cities with the most clubs for a sport, for the sport pages' "where to play" links. */
export function topCitiesFor(sport: Sport, limit: number, directory: readonly ProvinceGroup[] = DIRECTORY) {
  return directory
    .flatMap((p) => p.cities.map((city) => ({ province: p, city, count: clubsOf(city, sport).length })))
    .filter((x) => x.count > 0)
    .sort((a, b) => b.count - a.count || faOrder.compare(a.city.name, b.city.name))
    .slice(0, limit)
}

export const HOME_CRUMB: Crumb = { name: 'رالیتو', path: '/' }
export const CLUBS_CRUMB: Crumb = { name: 'باشگاه‌ها', path: CLUBS_PATH }
