import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import {
  DIRECTORY,
  INDEX_MIN_CLUBS,
  areaOf,
  certainDescription,
  clubSlug,
  exactAddress,
  groupClubs,
  mapLinks,
  nearbyClubs,
  ownLink,
  phoneOf,
  placeSlug,
  sportsIn,
  topCitiesFor,
  type ClubRecord,
} from '../../src/data/clubs'
import { cityClubsPage, citySportClubsPage, clubPage, clubPages, provinceClubsPage } from '../../src/data/pages'
import { SPORTS } from '../../src/data/sports'

// The club directory (owner decisions 2026-11-01): clubs by sport, province and city, with how to find and reach each.
// These tests read tests/fixtures/venues.sample.json (LANDING_VENUES, set by `npm run test:unit`).

const record = (name: string, cityName: string, provinceName: string, sports: string[], cityId = 1, provinceId = 1): ClubRecord => ({
  name,
  provinceId,
  provinceName,
  cityId,
  cityName,
  sports,
  address: null,
  phone: null,
  latitude: null,
  longitude: null,
  googlePlaceId: null,
  workingHours: null,
  website: null,
  instagram: null,
  telegram: null,
  description: null,
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

  it('carries only the published fields: no id, status, import reference or rating', () => {
    const published = [
      'address', 'cityId', 'cityName', 'description', 'googlePlaceId', 'instagram', 'latitude', 'longitude', 'name', 'phone',
      'provinceId', 'provinceName', 'sports', 'telegram', 'website', 'workingHours',
    ]
    for (const file of ['tests/fixtures/venues.sample.json', 'src/data/venues.json']) {
      const records = JSON.parse(readFileSync(file, 'utf8')) as Record<string, unknown>[]
      for (const r of records) expect(Object.keys(r).sort(), file).toEqual(published)
    }
  })

  it('does not pass a bare city name off as an exact address', () => {
    expect(exactAddress('رشت، بلوار گیلان، خیابان ۱۹۲', 'رشت')).toBe('رشت، بلوار گیلان، خیابان ۱۹۲')
    expect(exactAddress('کرج، عظیمیه', 'کرج')).toBe('کرج، عظیمیه')
    expect(exactAddress('بروجرد', 'بروجرد')).toBeNull()
    expect(exactAddress(' بندر انزلی ', 'بندرانزلی')).toBeNull()
    expect(exactAddress('', 'تهران')).toBeNull()
    expect(exactAddress(null, 'تهران')).toBeNull()
  })

  it('gives a phone a dialable link, and no link when there is no phone', () => {
    expect(phoneOf('021 2263-8043')).toEqual({ text: '021 2263-8043', href: 'tel:02122638043' })
    expect(phoneOf(null)).toBeNull()
    expect(phoneOf('  ')).toBeNull()
  })

  it('links a map only for a club with a position, on the place itself when known', () => {
    const links = mapLinks(35.77, 51.44, 'ChIJ abc')!
    expect(links.google).toBe('https://www.google.com/maps/search/?api=1&query=35.77,51.44&query_place_id=ChIJ%20abc')
    expect(links.balad).toBe('https://balad.ir/location?latitude=35.77&longitude=51.44&zoom=17')
    expect(mapLinks(35.77, 51.44, null)!.google).toBe('https://www.google.com/maps/search/?api=1&query=35.77,51.44')
    expect(mapLinks(null, 51.44, 'x')).toBeNull()
    expect(mapLinks(35.77, null, 'x')).toBeNull()
  })

  it('keeps a research note that is not sure of itself off the public list', () => {
    expect(certainDescription('۴ زمین خاک رس و ۲ زمین هارد.')).toBe('۴ زمین خاک رس و ۲ زمین هارد.')
    expect(certainDescription('احتمالاً در مجموعه ورزشی خیریه امل.')).toBeNull()
    expect(certainDescription('برنامه کلاس‌ها هنوز از منبع رسمی تأیید نشده است.')).toBeNull()
    expect(certainDescription('  ')).toBeNull()
    expect(certainDescription(null)).toBeNull()
  })

  it('keeps only web links from a club profile', () => {
    expect(ownLink('https://club.ir')).toBe('https://club.ir')
    expect(ownLink('http://club.ir')).toBe('http://club.ir')
    expect(ownLink('javascript:alert(1)')).toBeNull()
    expect(ownLink('club.ir')).toBeNull()
    expect(ownLink(null)).toBeNull()
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

  it('builds a page per province, city, sport a city has and club, plus the directory front page', () => {
    const cities = DIRECTORY.flatMap((p) => p.cities)
    const sportPages = cities.reduce((n, c) => n + sportsIn(c).length, 0)
    const clubs = cities.reduce((n, c) => n + c.clubs.length, 0)
    expect(pages).toHaveLength(1 + DIRECTORY.length + cities.length + sportPages + clubs)
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

  // Google Trends, Iran, 2026-11-07: «زمین تنیس» is searched more than «باشگاه تنیس» (60 to 36), and «زمین پدل» three
  // times «باشگاه پدل». The list titles name both words; a sport page says them as one phrase, the way people type it.
  it('names the sport and the city in a sport page title the way people search, with what the page gives them', () => {
    const fars = DIRECTORY.find((p) => p.name === 'فارس')!
    const tehran = DIRECTORY.find((p) => p.name === 'تهران')!
    const tennis = SPORTS.find((s) => s.slug === 'tennis')!
    expect(citySportClubsPage(fars, fars.cities[0], tennis).title).toBe('باشگاه و زمین تنیس شیراز: نشانی، تلفن و نقشه | رالیتو')
    // No club there has an address, phone or position yet: the title promises none of them.
    const tehranCity = tehran.cities.find((c) => c.name === 'تهران')!
    expect(citySportClubsPage(tehran, tehranCity, tennis).title).toBe('باشگاه و زمین تنیس تهران | رالیتو')
  })

  it('says «زمین» with the sport in a sport page description too', () => {
    const fars = DIRECTORY.find((p) => p.name === 'فارس')!
    const tennis = SPORTS.find((s) => s.slug === 'tennis')!
    expect(citySportClubsPage(fars, fars.cities[0], tennis).description).toContain('زمین تنیس')
  })

  it('names clubs and courts in a city title, and keeps it apart from the sport page of a one-sport city', () => {
    const [gilan] = groupClubs([
      { ...record('الف', 'رشت', 'گیلان', ['tennis', 'padel']), address: 'رشت، بلوار گیلان', phone: '01333334444' },
      record('ب', 'لاهیجان', 'گیلان', ['tennis'], 2),
    ])
    const tennis = SPORTS.find((s) => s.slug === 'tennis')!
    expect(cityClubsPage(gilan, gilan.cities[0], [gilan]).title).toBe('باشگاه‌ها و زمین‌های تنیس و پدل رشت: نشانی و تلفن | رالیتو')
    const lahijan = gilan.cities.find((c) => c.name === 'لاهیجان')!
    expect(cityClubsPage(gilan, lahijan, [gilan]).title).not.toBe(citySportClubsPage(gilan, lahijan, tennis, [gilan]).title)
    expect(cityClubsPage(gilan, gilan.cities[0], [gilan]).description).toContain('زمین')
  })

  it('keeps «زمین» in the title of a city with all four sports, where the plural does not fit', () => {
    const [azarbaijan] = groupClubs([record('الف', 'تبریز', 'آذربایجان شرقی', ['tennis', 'padel', 'badminton', 'squash'])])
    expect(cityClubsPage(azarbaijan, azarbaijan.cities[0], [azarbaijan]).title).toBe('باشگاه و زمین تنیس، پدل، بدمینتون و اسکواش تبریز | رالیتو')
    const [esfahan] = groupClubs([record('الف', 'اصفهان', 'اصفهان', ['tennis', 'padel', 'badminton', 'squash']), record('ب', 'کاشان', 'اصفهان', ['tennis'], 2)])
    expect(provinceClubsPage(esfahan).title).toBe('باشگاه‌ها و زمین‌های ورزشی استان اصفهان | رالیتو')
  })

  it('names every sport a province has in its title, falling back to a shorter title for a long name', () => {
    const [fars] = groupClubs([record('الف', 'شیراز', 'فارس', ['tennis', 'padel'])])
    expect(provinceClubsPage(fars).title).toBe('باشگاه‌ها و زمین‌های تنیس و پدل استان فارس | رالیتو')
    // All four sports and «زمین‌های» do not fit with «استان تهران»: the sports stay, «زمین‌های» goes.
    expect(provinceClubsPage(DIRECTORY.find((p) => p.name === 'تهران')!).title).toBe('باشگاه‌های تنیس، پدل، بدمینتون و اسکواش استان تهران | رالیتو')
    const [kohgiluyeh] = groupClubs([record('الف', 'دهدشت', 'کهگیلویه و بویراحمد', ['tennis', 'padel', 'badminton', 'squash'])])
    expect(provinceClubsPage(kohgiluyeh).title).toBe('باشگاه‌های ورزشی استان کهگیلویه و بویراحمد | رالیتو')
  })

  it('names clubs and courts of all four sports on the directory front page', () => {
    const hub = clubPages()[0]
    expect(hub.title).toBe('باشگاه‌ها و زمین‌های تنیس، پدل، بدمینتون و اسکواش | رالیتو')
    expect(hub.description).toContain('زمین تنیس')
  })

  it('indexes a province only when its clubs are in more than one city (otherwise its city page says the same)', () => {
    expect(provinceClubsPage(DIRECTORY.find((p) => p.name === 'تهران')!).indexable).toBe(true)
    expect(provinceClubsPage(DIRECTORY.find((p) => p.name === 'فارس')!).indexable).toBe(false)
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

describe('club pages', () => {
  const placed = (directory: ReturnType<typeof groupClubs>, name: string) => {
    const province = directory.find((p) => p.cities.some((c) => c.clubs.some((k) => k.name === name)))!
    const city = province.cities.find((c) => c.clubs.some((k) => k.name === name))!
    return { province, city, club: city.clubs.find((k) => k.name === name)! }
  }

  it('gives each club a page under its city, its name as the URL segment', () => {
    const [p] = groupClubs([record('زمین تنیس (شاهرود)', 'شاهرود', 'سمنان', ['tennis'])])
    expect(p.cities[0].clubs[0].path).toBe('/clubs/سمنان/شاهرود/زمین-تنیس-شاهرود')
    expect(clubSlug('باشگاه تنیس آریانا')).toBe('باشگاه-تنیس-آریانا')
    expect(clubSlug('اسلام‌شهر پدل')).toBe('اسلام-شهر-پدل')
  })

  it('never gives a club the URL of a sport page of its city', () => {
    expect(clubSlug('Padel')).toBe('Padel-club')
  })

  it('tells two branches of one name in one city apart, by the area their address names', () => {
    const directory = groupClubs([
      { ...record('آکادمی بدمینتون عزیزی', 'تهران', 'تهران', ['badminton']), address: 'تهران، تجریش، نیاوران' },
      { ...record('آکادمی بدمینتون عزیزی', 'تهران', 'تهران', ['badminton']), address: 'تهران، منطقه ۲، شهرک غرب', phone: '09120000000' },
    ])
    const [a, b] = directory[0].cities[0].clubs
    expect([a.path, b.path]).toEqual(['/clubs/تهران/تهران/آکادمی-بدمینتون-عزیزی', '/clubs/تهران/تهران/آکادمی-بدمینتون-عزیزی-2'])
    const titles = [a, b].map((club) => clubPage(directory[0], directory[0].cities[0], club, directory).title)
    expect(titles[0]).toContain('(تجریش)')
    expect(titles[1]).toContain('(منطقه ۲)')
  })

  it('reads the area from the address and infers nothing else', () => {
    const [p] = groupClubs([
      { ...record('الف', 'تهران', 'تهران', ['padel']), address: 'تهران، سعادت‌آباد، خیابان سرو' },
      { ...record('ب', 'تهران', 'تهران', ['padel']), address: 'سعادت‌آباد، خیابان سرو' },
      { ...record('پ', 'تهران', 'تهران', ['padel']), address: 'تهران' },
    ])
    expect(p.cities[0].clubs.map((c) => areaOf(c, 'تهران'))).toEqual(['سعادت‌آباد', 'سعادت‌آباد', null])
  })

  it('promises in the title only the facts the club has, with «آدرس» as people search a club', () => {
    const directory = groupClubs([
      { ...record('باشگاه تنیس آریانا', 'کرج', 'البرز', ['tennis']), address: 'کرج، عظیمیه', phone: '02612345678', latitude: 35.8, longitude: 50.9 },
      { ...record('پدل کرج', 'کرج', 'البرز', ['padel']), address: 'کرج، گوهردشت' },
      record('باشگاه تنیس کرج', 'کرج', 'البرز', ['tennis']),
    ])
    const page = (name: string) => {
      const { province, city, club } = placed(directory, name)
      return clubPage(province, city, club, directory)
    }
    expect(page('باشگاه تنیس آریانا').title).toBe('باشگاه تنیس آریانا کرج: آدرس، تلفن و نقشه | رالیتو')
    expect(page('پدل کرج').title).toBe('پدل کرج: آدرس | رالیتو')
    // Named like the city's tennis list, and nothing to promise: the province keeps the two titles apart.
    expect(page('باشگاه تنیس کرج').title).toBe('باشگاه تنیس کرج، استان البرز | رالیتو')
    expect(page('باشگاه تنیس آریانا').description).toContain('نشانی دقیق، تلفن و مسیر روی نقشه')
    expect(page('باشگاه تنیس آریانا').description).toContain('عظیمیه')
  })

  // «اجاره زمین تنیس» rose 40% in Iran (Google Trends, 2026-11-07); a club's phone is how a court is rented.
  it('asks to call about renting a court only on the page of a club with a phone', () => {
    const directory = groupClubs([
      { ...record('باشگاه تنیس آریانا', 'کرج', 'البرز', ['tennis']), address: 'کرج، عظیمیه', phone: '02612345678', latitude: 35.8, longitude: 50.9 },
      { ...record('پدل کرج', 'کرج', 'البرز', ['padel']), address: 'کرج، گوهردشت' },
    ])
    const page = (name: string) => {
      const { province, city, club } = placed(directory, name)
      return clubPage(province, city, club, directory)
    }
    expect(page('باشگاه تنیس آریانا').description).toContain('برای اجاره زمین تنیس تماس بگیر')
    expect(page('پدل کرج').description).not.toContain('اجاره')
  })

  it('indexes a club page only with an exact address and a phone or a position', () => {
    const directory = groupClubs([
      { ...record('الف', 'کرج', 'البرز', ['tennis']), address: 'کرج، عظیمیه', phone: '02612345678' },
      { ...record('ب', 'کرج', 'البرز', ['tennis']), address: 'کرج، گوهردشت', latitude: 35.8, longitude: 50.9 },
      { ...record('پ', 'کرج', 'البرز', ['tennis']), address: 'کرج، مهرشهر' },
      { ...record('ت', 'کرج', 'البرز', ['tennis']), address: 'کرج', phone: '02612345678', latitude: 35.8, longitude: 50.9 },
    ])
    const indexable = directory[0].cities[0].clubs.map((club) => clubPage(directory[0], directory[0].cities[0], club, directory).indexable)
    expect(indexable).toEqual([true, true, false, false])
  })

  it('lists the nearest clubs of the same sports first, and no club without a shared sport', () => {
    const directory = groupClubs([
      { ...record('مبدأ', 'تهران', 'تهران', ['tennis']), latitude: 35.7, longitude: 51.4 },
      { ...record('دور', 'تهران', 'تهران', ['tennis']), latitude: 35.8, longitude: 51.4 },
      { ...record('نزدیک', 'تهران', 'تهران', ['tennis', 'padel']), latitude: 35.701, longitude: 51.4 },
      record('بی‌مکان', 'تهران', 'تهران', ['tennis']),
      { ...record('پدل', 'تهران', 'تهران', ['padel']), latitude: 35.7, longitude: 51.4 },
    ])
    const city = directory[0].cities[0]
    const from = city.clubs.find((c) => c.name === 'مبدأ')!
    const near = nearbyClubs(from, city, 5)
    expect(near.map((n) => n.club.name)).toEqual(['نزدیک', 'دور', 'بی‌مکان'])
    expect(near[0].km).toBeCloseTo(0.111, 2)
    expect(near[2].km).toBeNull()
  })
})
