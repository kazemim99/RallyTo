import { SITE } from '../config/site'
import {
  CLUBS_CRUMB,
  CLUBS_PATH,
  DIRECTORY,
  INDEX_MIN_CLUBS,
  allClubs,
  areaOf,
  citySportPath,
  clubsOf,
  directoryPublished,
  sportsIn,
  totalClubs,
  type CityGroup,
  type Club,
  type ProvinceGroup,
} from './clubs'
import type { Crumb } from '../lib/seo'
import { GUIDES, GUIDES_PATH, type Guide } from './guides'
import { PRIVACY, TERMS } from './policies'
import { SPORTS, type Sport } from './sports'

export interface PageMeta {
  path: string
  title: string
  /** Title for link previews (og:title) when the page title is not the share title. */
  shareTitle?: string
  description: string
  indexable: boolean
  crumbs?: Crumb[]
  /** A 1200×630 PNG for link previews instead of the site's default one. */
  shareImage?: { path: string; alt: string }
}

const HOME: Crumb = { name: 'رالیتو', path: '/' }

/**
 * Titles and descriptions of every page in one place: the sitemap is built from this list and the tests hold each
 * entry to the metadata rules (unique, title ≤ 60 characters, description 70–160). Titles use the words people type
 * («زمین تنیس», «پارتنر تنیس», «هم‌بازی»), never «پارتنر یابی» on its own (it reads as dating).
 */
export const PAGES = {
  home: {
    path: '/',
    title: 'رالیتو | پارتنر تنیس، پدل، بدمینتون و اسکواش هم‌سطح',
    shareTitle: 'رالیتو: هم‌بازی هم‌سطح، نزدیک باشگاهت',
    description:
      'با رالیتو هم‌بازی هم‌سطح برای تنیس، پدل، بدمینتون و اسکواش پیدا کن: بازی باز بگذار یا زمان‌های آزادت را اعلام کن و خوش‌قولی هم‌بازی‌ها را از قبل ببین.',
    indexable: true,
  },
  privacy: {
    path: '/privacy',
    title: PRIVACY.title,
    description: PRIVACY.description,
    indexable: true,
    crumbs: [HOME, { name: PRIVACY.h1, path: '/privacy' }],
  },
  terms: {
    path: '/terms',
    title: TERMS.title,
    description: TERMS.description,
    indexable: true,
    crumbs: [HOME, { name: TERMS.h1, path: '/terms' }],
  },
  contact: {
    path: '/contact',
    title: 'تماس با رالیتو',
    description:
      'مسئول رالیتو، نشانی و شماره‌ی تماس برای پرسش‌ها، پیشنهادها و پیگیری درباره‌ی اپ رالیتو و هم‌بازی تنیس، پدل، بدمینتون و اسکواش.',
    indexable: true,
    crumbs: [HOME, { name: 'تماس با ما', path: '/contact' }],
  },
  notFound: {
    path: '/404',
    title: 'صفحه پیدا نشد | رالیتو',
    description: 'این صفحه در رالیتو وجود ندارد. از صفحه‌ی اصلی ادامه بده و هم‌بازی هم‌سطحت را برای تنیس، پدل، بدمینتون و اسکواش پیدا کن.',
    indexable: false,
  },
} satisfies Record<string, PageMeta>

export function sportPage(sport: Sport): PageMeta {
  return {
    path: `/${sport.slug}`,
    title: sport.title,
    description: sport.description,
    indexable: true,
    crumbs: [HOME, { name: sport.name, path: `/${sport.slug}` }],
  }
}

/** The sport pages that are built and linked: none until the venue catalog has clubs (`SITE.sportPagesPublished`). */
export function publishedSports(): Sport[] {
  return SITE.sportPagesPublished ? SPORTS : []
}

const fa = (n: number) => n.toLocaleString('fa-IR')
const joinFa = (names: string[]) => (names.length < 2 ? names.join('') : `${names.slice(0, -1).join('، ')} و ${names.at(-1)}`)
const BRAND = ' | رالیتو'
const length = (s: string) => [...s].length
/** The first title that fits the 60-character limit, so long place names fall back to a shorter form. */
const fitTitle = (...candidates: string[]) => candidates.find((t) => length(t) <= 60) ?? candidates.at(-1)!
/** The first description of 70–160 characters; the last candidate is the fallback. */
const fitDescription = (...candidates: string[]) => candidates.find((d) => length(d) >= 70 && length(d) <= 160) ?? candidates.at(-1)!
/** A label cut at a word so that it and the brand fit in a title, marked with an ellipsis. */
function brandedWithin60(label: string): string {
  const room = 60 - length(BRAND)
  if (length(label) <= room) return label + BRAND
  const words = label.split(' ')
  while (words.length > 1 && length(words.join(' ')) + 1 > room) words.pop()
  return `${words.join(' ')}…${BRAND}`
}

/**
 * The facts a list of clubs offers, as a title may promise them: «نشانی» only when a club there has an exact address,
 * «تلفن» only when one has a phone, «نقشه» only when one has a position.
 */
function factsOf(clubs: readonly Club[], addressWord = 'نشانی'): string[] {
  return [
    clubs.some((c) => c.address) && addressWord,
    clubs.some((c) => c.phone) && 'تلفن',
    clubs.some((c) => c.map) && 'نقشه',
  ].filter((f): f is string => typeof f === 'string')
}
const withFacts = (label: string, facts: string[]) => (facts.length > 0 ? [`${label}: ${joinFa(facts)}${BRAND}`] : [])

/** A city's name, with its province when another province has a city of the same name (titles stay unique). */
function cityLabel(city: CityGroup, province: ProvinceGroup, directory: readonly ProvinceGroup[]): string {
  const twins = directory.filter((p) => p.cities.some((c) => c.name === city.name)).length
  return twins > 1 ? `${city.name} (${province.name})` : city.name
}

/*
 * The directory's titles name courts as well as clubs: in Iran «زمین تنیس» is searched more than «باشگاه تنیس» and
 * «زمین پدل» three times «باشگاه پدل» (Google Trends, 2026-11-07). A sport page says «باشگاه و زمین تنیس شیراز», the
 * words people type; the lists of a city, a province and the whole directory say it in the plural («باشگاه‌ها و
 * زمین‌های…»), which also keeps a one-sport city's title apart from its sport page's. When the plural does not fit, the
 * singular is tried, then the form without «زمین».
 */
const CLUBS_AND_COURTS = 'باشگاه‌ها و زمین‌های'
const CLUB_AND_COURT = 'باشگاه و زمین'

export function clubsHubPage(directory: readonly ProvinceGroup[] = DIRECTORY): PageMeta {
  return {
    path: CLUBS_PATH,
    title: `${CLUBS_AND_COURTS} تنیس، پدل، بدمینتون و اسکواش${BRAND}`,
    description: fitDescription(
      `زمین تنیس، پدل، بدمینتون و اسکواش شهرت را پیدا کن: ${fa(totalClubs(directory))} باشگاه در ${fa(directory.length)} استان ایران، با نشانی، تلفن و نقشه، به تفکیک استان، شهر و ورزش.`,
      `فهرست ${fa(totalClubs(directory))} باشگاه تنیس، پدل، بدمینتون و اسکواش در ${fa(directory.length)} استان ایران، با نشانی، تلفن و نقشه، به تفکیک استان، شهر و ورزش؛ در رالیتو هم‌بازی هم‌سطح پیدا کن.`,
    ),
    indexable: totalClubs(directory) >= INDEX_MIN_CLUBS,
    crumbs: [HOME, CLUBS_CRUMB],
  }
}

/** The sports a province has at least one club for, in the site's order. */
export function sportsInProvince(province: ProvinceGroup): Sport[] {
  return SPORTS.filter((s) => province.cities.some((c) => sportsIn(c).includes(s)))
}

export function provinceClubsPage(province: ProvinceGroup): PageMeta {
  const sports = joinFa(sportsInProvince(province).map((s) => s.name))
  return {
    path: province.path,
    title: fitTitle(
      `${CLUBS_AND_COURTS} ${sports} استان ${province.name}${BRAND}`,
      `${CLUB_AND_COURT} ${sports} استان ${province.name}${BRAND}`,
      `باشگاه‌های ${sports} استان ${province.name}${BRAND}`,
      `${CLUBS_AND_COURTS} ورزشی استان ${province.name}${BRAND}`,
      `باشگاه‌های ورزشی استان ${province.name}${BRAND}`,
      `باشگاه‌های استان ${province.name}${BRAND}`,
    ),
    description: fitDescription(
      `${fa(province.clubCount)} باشگاه ${sports} در ${fa(province.cities.length)} شهر استان ${province.name}، با نشانی، تلفن و نقشه برای پیدا کردن زمین بازی. در رالیتو هم‌بازی هم‌سطح پیدا کن.`,
      `${fa(province.clubCount)} باشگاه ${sports} در ${fa(province.cities.length)} شهر استان ${province.name}، با نشانی، تلفن و نقشه. در رالیتو هم‌بازی هم‌سطح پیدا کن.`,
    ),
    // A province whose clubs are all in one city lists exactly what that city's page lists; only the city is indexed.
    indexable: province.clubCount >= INDEX_MIN_CLUBS && province.cities.length > 1,
    crumbs: [HOME, CLUBS_CRUMB, { name: `استان ${province.name}`, path: province.path }],
  }
}

export function cityClubsPage(province: ProvinceGroup, city: CityGroup, directory: readonly ProvinceGroup[] = DIRECTORY): PageMeta {
  const label = cityLabel(city, province, directory)
  const sports = joinFa(sportsIn(city).map((s) => s.name))
  // The singular is a sport page's form: a city list may use it only when it names more than one sport.
  const singular = sportsIn(city).length > 1 ? [...withFacts(`${CLUB_AND_COURT} ${sports} ${label}`, factsOf(city.clubs)), `${CLUB_AND_COURT} ${sports} ${label}${BRAND}`] : []
  return {
    path: city.path,
    title: fitTitle(
      ...withFacts(`${CLUBS_AND_COURTS} ${sports} ${label}`, factsOf(city.clubs)),
      `${CLUBS_AND_COURTS} ${sports} ${label}${BRAND}`,
      ...singular,
      ...withFacts(`باشگاه‌های ${sports} ${label}`, factsOf(city.clubs)),
      `باشگاه‌های ${sports} در ${label}${BRAND}`,
      `${CLUBS_AND_COURTS} ورزشی ${label}${BRAND}`,
      `باشگاه‌های ورزشی ${label}${BRAND}`,
      `باشگاه‌های ${label}${BRAND}`,
    ),
    description: fitDescription(
      `فهرست ${fa(city.clubs.length)} باشگاه ${sports} در ${city.name}، استان ${province.name}، با نشانی، تلفن و نقشه برای پیدا کردن زمین بازی. در رالیتو هم‌بازی هم‌سطح پیدا کن.`,
      `فهرست ${fa(city.clubs.length)} باشگاه ${sports} در ${city.name}، استان ${province.name}، با نشانی، تلفن و نقشه. در رالیتو هم‌بازی هم‌سطح پیدا کن.`,
    ),
    indexable: city.clubs.length >= INDEX_MIN_CLUBS,
    crumbs: [HOME, CLUBS_CRUMB, { name: `استان ${province.name}`, path: province.path }, { name: city.name, path: city.path }],
  }
}

export function citySportClubsPage(province: ProvinceGroup, city: CityGroup, sport: Sport, directory: readonly ProvinceGroup[] = DIRECTORY): PageMeta {
  const label = cityLabel(city, province, directory)
  const clubs = clubsOf(city, sport)
  const count = clubs.length
  const path = citySportPath(city, sport)
  return {
    path,
    // «باشگاه و زمین تنیس تبریز»: both words people search, and what the page gives them.
    title: fitTitle(
      ...withFacts(`${CLUB_AND_COURT} ${sport.name} ${label}`, factsOf(clubs)),
      `${CLUB_AND_COURT} ${sport.name} ${label}${BRAND}`,
      ...withFacts(`باشگاه ${sport.name} ${label}`, factsOf(clubs)),
      `باشگاه ${sport.name} ${label}${BRAND}`,
      `باشگاه ${sport.name} ${city.name}${BRAND}`,
    ),
    description: fitDescription(
      `فهرست ${fa(count)} باشگاه ${sport.name} در ${city.name}، استان ${province.name}، با نشانی، تلفن و نقشه برای پیدا کردن زمین ${sport.name}. در رالیتو هم‌بازی هم‌سطح پیدا کن.`,
      `فهرست ${fa(count)} باشگاه ${sport.name} در ${city.name}، استان ${province.name}، با نشانی، تلفن و نقشه. در رالیتو هم‌بازی ${sport.name} هم‌سطح پیدا کن.`,
    ),
    // A sport page that lists every club of its city repeats the city page; only the city page is indexed then.
    indexable: count >= INDEX_MIN_CLUBS && count < city.clubs.length,
    crumbs: [
      HOME,
      CLUBS_CRUMB,
      { name: `استان ${province.name}`, path: province.path },
      { name: city.name, path: city.path },
      { name: sport.name, path },
    ],
  }
}

/**
 * What sets a club apart from another of the same name in the same city (two branches): where its address puts it,
 * or its place in the list when the addresses do not tell them apart. Empty for a club with no namesake.
 */
function namesakeMark(club: Club, city: CityGroup): string {
  const namesakes = city.clubs.filter((c) => c.name === club.name)
  if (namesakes.length < 2) return ''
  const area = areaOf(club, city.name)
  const unique = area !== null && namesakes.filter((c) => areaOf(c, city.name) === area).length === 1
  return ` (${unique ? area : fa(namesakes.indexOf(club) + 1)})`
}

/**
 * A club's own page. Indexed when it says where the club is and how to reach it: an exact address and a phone or a
 * position. A club the catalog knows less about still has its page, out of the index.
 */
export function clubPage(province: ProvinceGroup, city: CityGroup, club: Club, directory: readonly ProvinceGroup[] = DIRECTORY): PageMeta {
  const mark = namesakeMark(club, city)
  const name = club.name + mark
  const cityName = cityLabel(city, province, directory)
  const label = club.name.includes(city.name) ? name : `${name} ${cityName}`
  const sports = joinFa(club.sports.map((s) => s.name))
  const area = areaOf(club, city.name)
  const facts = [
    club.address && 'نشانی دقیق',
    club.phone && 'تلفن',
    club.workingHours && 'ساعت کاری',
    club.map && 'مسیر روی نقشه',
  ].filter((f): f is string => typeof f === 'string')
  const see = facts.length > 0 ? `${joinFa(facts)} را ببین و ` : ''
  const where = (withArea: boolean) => `${city.name}${withArea && area && !mark.includes(area) ? `، ${area}` : ''}، استان ${province.name}`
  const firstSport = club.sports[0].name
  // «اجاره زمین تنیس» is searched more and more (Google Trends, Iran, 2026-11-07); a phone is how a court is rented.
  // The title already lists the facts, so a description too long with them still asks to call without them.
  const rent = club.phone
    ? [
        ...[true, false].map((withArea) => `${name} در ${where(withArea)}، برای ${sports}. ${joinFa(facts)} را ببین، برای اجاره زمین ${firstSport} تماس بگیر و در رالیتو هم‌بازی پیدا کن.`),
        ...[true, false].map((withArea) => `${name} در ${where(withArea)}، برای ${sports}. برای اجاره زمین ${firstSport} تماس بگیر و در رالیتو هم‌بازی هم‌سطح پیدا کن.`),
      ]
    : []
  return {
    path: club.path,
    // «آدرس», the word people type after a club's name; list titles say «نشانی». A club with none of those facts names
    // its province instead. Either way a club named like its list («باشگاه تنیس کاشان») never shares that list's title.
    title: fitTitle(...withFacts(label, factsOf([club], 'آدرس')), `${label}، استان ${province.name}${BRAND}`, brandedWithin60(label)),
    description: fitDescription(
      ...rent,
      `${name} در ${where(true)}، برای ${sports}. ${see}در رالیتو هم‌بازی هم‌سطح پیدا کن.`,
      `${name} در ${where(false)}، برای ${sports}. ${see}در رالیتو هم‌بازی هم‌سطح پیدا کن.`,
      `${name} در ${where(false)}. ${see}در رالیتو هم‌بازی پیدا کن.`,
      `${name} در ${where(false)}، برای ${sports}. فهرست باشگاه‌های ${firstSport} ${city.name} و هم‌بازی هم‌سطح در رالیتو.`,
    ),
    indexable: club.address !== null && (club.phone !== null || club.map !== null),
    crumbs: [
      HOME,
      CLUBS_CRUMB,
      { name: `استان ${province.name}`, path: province.path },
      { name: city.name, path: city.path },
      { name, path: club.path },
    ],
  }
}

/** Every page of the club directory, built or not indexable; empty while the directory snapshot is empty. */
export function clubPages(directory: readonly ProvinceGroup[] = DIRECTORY): PageMeta[] {
  if (directory.length === 0) return []
  return [
    clubsHubPage(directory),
    ...directory.flatMap((p) => [
      provinceClubsPage(p),
      ...p.cities.flatMap((c) => [
        cityClubsPage(p, c, directory),
        ...sportsIn(c).map((s) => citySportClubsPage(p, c, s, directory)),
        ...c.clubs.map((club) => clubPage(p, c, club, directory)),
      ]),
    ]),
  ]
}

/** Every club's page with what it needs to be built, in directory order. */
export const clubPageEntries = (directory: readonly ProvinceGroup[] = DIRECTORY) =>
  allClubs(directory).map((placed) => ({ ...placed, meta: clubPage(placed.province, placed.city, placed.club, directory) }))

export function guidesHubPage(): PageMeta {
  return {
    path: GUIDES_PATH,
    title: 'راهنمای تنیس، پدل، بدمینتون و اسکواش' + BRAND,
    description:
      'قوانین و امتیازشماری تنیس، پدل، بدمینتون و اسکواش به زبان ساده، و تفاوت پدل و تنیس؛ برای شروع بازی و پیدا کردن هم‌بازی هم‌سطح در رالیتو.',
    indexable: true,
    crumbs: [HOME, { name: 'راهنماها', path: GUIDES_PATH }],
  }
}

export function guidePage(guide: Guide): PageMeta {
  return {
    path: `${GUIDES_PATH}/${guide.slug}`,
    title: guide.title + BRAND,
    description: guide.description,
    indexable: true,
    crumbs: [HOME, { name: 'راهنماها', path: GUIDES_PATH }, { name: guide.crumb, path: `${GUIDES_PATH}/${guide.slug}` }],
    shareImage: guide.figure && { path: guide.figure.src, alt: guide.figure.alt },
  }
}

/** Every page that belongs in the sitemap, in order. */
export function indexablePages(): PageMeta[] {
  const [home, ...rest] = Object.values(PAGES).filter((p) => p.indexable)
  const clubs = directoryPublished() ? clubPages().filter((p) => p.indexable) : []
  return [home, ...publishedSports().map(sportPage), guidesHubPage(), ...GUIDES.map(guidePage), ...clubs, ...rest]
}
