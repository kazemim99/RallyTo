// The club directory: every active club in Rallyto's catalog, by province, city and sport, as `npm run venues` saved it
// from the API's public directory (GET /api/v1/public/venues). Owner decision 2026-11-01: a club is published with
// its name, sports, province and city only — never an address, a phone number or a map position — and hidden clubs
// are not in the directory at all (the API leaves them out).
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
}

export interface Club {
  name: string
  sports: Sport[]
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
    city.clubs.push({ name: r.name, sports })
    province.clubCount += 1
  }
  const list = [...provinces.values()].sort((a, b) => faOrder.compare(a.name, b.name))
  for (const p of list) {
    p.cities.sort((a, b) => faOrder.compare(a.name, b.name))
    for (const c of p.cities) c.clubs.sort((a, b) => faOrder.compare(a.name, b.name))
  }
  return list
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
