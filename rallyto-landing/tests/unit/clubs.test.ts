import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { DIRECTORY, INDEX_MIN_CLUBS, groupClubs, placeSlug, sportsIn, topCitiesFor, type ClubRecord } from '../../src/data/clubs'
import { cityClubsPage, citySportClubsPage, clubPages, provinceClubsPage } from '../../src/data/pages'
import { SPORTS } from '../../src/data/sports'

// The club directory (owner decision 2026-11-01): clubs by sport, province and city; name, sports and town only.
// These tests read tests/fixtures/venues.sample.json (LANDING_VENUES, set by `npm run test:unit`).

const record = (name: string, cityName: string, provinceName: string, sports: string[], cityId = 1, provinceId = 1): ClubRecord => ({
  name,
  provinceId,
  provinceName,
  cityId,
  cityName,
  sports,
})

describe('the directory data', () => {
  it('groups clubs by province and city in Persian order, with sports in the site order', () => {
    const directory = groupClubs([
      record('ب', 'شیراز', 'فارس', ['squash', 'tennis'], 2, 17),
      record('آ', 'شیراز', 'فارس', ['padel'], 2, 17),
      record('پ', 'اصفهان', 'اصفهان', ['tennis'], 3, 4),
    ])

    expect(directory.map((p) => p.name)).toEqual(['اصفهان', 'فارس'])
    const shiraz = directory[1].cities[0]
    expect(shiraz.clubs.map((c) => c.name)).toEqual(['آ', 'ب'])
    expect(shiraz.clubs[1].sports.map((s) => s.slug)).toEqual(['tennis', 'squash'])
    expect(directory[1].clubCount).toBe(2)
  })

  it('drops sports the site does not know, and clubs left with none', () => {
    const directory = groupClubs([record('الف', 'تهران', 'تهران', ['tennis', 'golf']), record('ب', 'تهران', 'تهران', ['golf'])])

    expect(directory[0].cities[0].clubs.map((c) => c.name)).toEqual(['الف'])
    expect(directory[0].cities[0].clubs[0].sports.map((s) => s.slug)).toEqual(['tennis'])
  })

  it('makes a URL segment from a place name without changing its letters', () => {
    expect(placeSlug('اسلام‌شهر')).toBe('اسلام-شهر')
    expect(placeSlug(' کهگیلویه و بویراحمد ')).toBe('کهگیلویه-و-بویراحمد')
    expect(placeSlug('تهران')).toBe('تهران')
  })

  it('carries nothing but name, sports, province and city (no address, phone or position)', () => {
    for (const file of ['tests/fixtures/venues.sample.json', 'src/data/venues.json']) {
      const records = JSON.parse(readFileSync(file, 'utf8')) as Record<string, unknown>[]
      for (const r of records) expect(Object.keys(r).sort(), file).toEqual(['cityId', 'cityName', 'name', 'provinceId', 'provinceName', 'sports'])
    }
  })

  it('ranks the cities with the most clubs for a sport first', () => {
    const tennis = SPORTS.find((s) => s.slug === 'tennis')!
    const top = topCitiesFor(tennis, 3)
    expect(top[0].city.name).toBe('تهران')
    expect(top.map((t) => t.count)).toEqual([...top.map((t) => t.count)].sort((a, b) => b - a))
  })
})

describe('the directory pages', () => {
  const pages = clubPages()

  it('builds a page per province, city and sport a city has, plus the directory front page', () => {
    const cities = DIRECTORY.flatMap((p) => p.cities)
    const sportPages = cities.reduce((n, c) => n + sportsIn(c).length, 0)
    expect(pages).toHaveLength(1 + DIRECTORY.length + cities.length + sportPages)
  })

  it('keeps every title within 60 characters and every description within 70–160, indexable or not', () => {
    for (const p of pages) {
      expect([...p.title].length, p.title).toBeLessThanOrEqual(60)
      expect([...p.description].length, p.path).toBeGreaterThanOrEqual(70)
      expect([...p.description].length, p.path).toBeLessThanOrEqual(160)
    }
  })

  it('gives every page a unique title, description and path', () => {
    for (const key of ['title', 'description', 'path'] as const) expect(new Set(pages.map((p) => p[key])).size, key).toBe(pages.length)
  })

  it(`invites search engines only to pages listing at least ${INDEX_MIN_CLUBS} clubs`, () => {
    const tehran = DIRECTORY.find((p) => p.name === 'تهران')!
    const islamshahr = tehran.cities.find((c) => c.name === 'اسلام‌شهر')!
    const tehranCity = tehran.cities.find((c) => c.name === 'تهران')!
    const tennis = SPORTS.find((s) => s.slug === 'tennis')!

    expect(cityClubsPage(tehran, islamshahr).indexable).toBe(false)
    expect(citySportClubsPage(tehran, islamshahr, tennis).indexable).toBe(false)
    expect(cityClubsPage(tehran, tehranCity).indexable).toBe(true)
    expect(citySportClubsPage(tehran, tehranCity, tennis).indexable).toBe(true)
  })

  it('indexes a sport page only when it lists fewer clubs than its city page (no duplicate pages)', () => {
    const esfahan = DIRECTORY.find((p) => p.name === 'اصفهان')!
    const kashan = esfahan.cities.find((c) => c.name === 'کاشان')!
    const tennis = SPORTS.find((s) => s.slug === 'tennis')!
    const karaj = DIRECTORY.find((p) => p.name === 'البرز')!.cities[0]
    const alborz = DIRECTORY.find((p) => p.name === 'البرز')!

    expect(citySportClubsPage(esfahan, kashan, tennis).indexable).toBe(false)
    expect(cityClubsPage(alborz, karaj).indexable).toBe(true)
    for (const sport of sportsIn(karaj)) expect(citySportClubsPage(alborz, karaj, sport).indexable).toBe(false)
  })

  it('names the sport and the city in a sport page title, the way people search', () => {
    const fars = DIRECTORY.find((p) => p.name === 'فارس')!
    const tennis = SPORTS.find((s) => s.slug === 'tennis')!
    expect(citySportClubsPage(fars, fars.cities[0], tennis).title).toBe('باشگاه تنیس در شیراز | رالیتو')
  })

  it('falls back to a shorter title for a long province name', () => {
    const kohgiluyeh = DIRECTORY.find((p) => p.name === 'کهگیلویه و بویراحمد')!
    expect(provinceClubsPage(kohgiluyeh).title).toBe('باشگاه‌های استان کهگیلویه و بویراحمد | رالیتو')
  })

  it('adds the province to a city title when another province has a city of the same name', () => {
    const directory = groupClubs([
      record('الف', 'بهار', 'همدان', ['tennis'], 10, 13),
      record('ب', 'بهار', 'همدان', ['tennis'], 10, 13),
      record('پ', 'بهار', 'گیلان', ['tennis'], 20, 25),
    ])
    const [gilan, hamedan] = directory

    expect(cityClubsPage(hamedan, hamedan.cities[0], directory).title).toContain('بهار (همدان)')
    expect(cityClubsPage(gilan, gilan.cities[0], directory).title).toContain('بهار (گیلان)')
  })

  it('builds nothing while the snapshot is empty', () => {
    expect(clubPages([])).toEqual([])
  })
})
