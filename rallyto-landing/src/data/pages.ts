import { SITE } from '../config/site'
import {
  CLUBS_CRUMB,
  CLUBS_PATH,
  DIRECTORY,
  INDEX_MIN_CLUBS,
  citySportPath,
  clubsOf,
  directoryPublished,
  sportsIn,
  totalClubs,
  type CityGroup,
  type ProvinceGroup,
} from './clubs'
import type { Crumb } from '../lib/seo'
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
}

const HOME: Crumb = { name: 'رالیتو', path: '/' }

/**
 * Titles and descriptions of every page in one place: the sitemap is built from this list and the tests hold each
 * entry to the metadata rules (unique, title ≤ 60 characters, description 70–160). Titles use the words people type
 * («پارتنر تنیس», «هم‌بازی»), never «پارتنر یابی» on its own (it reads as dating).
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
/** The first title that fits the 60-character limit, so long place names fall back to a shorter form. */
const fitTitle = (...candidates: string[]) => candidates.find((t) => [...t].length <= 60) ?? candidates.at(-1)!

/** A city's name, with its province when another province has a city of the same name (titles stay unique). */
function cityLabel(city: CityGroup, province: ProvinceGroup, directory: readonly ProvinceGroup[]): string {
  const twins = directory.filter((p) => p.cities.some((c) => c.name === city.name)).length
  return twins > 1 ? `${city.name} (${province.name})` : city.name
}

export function clubsHubPage(directory: readonly ProvinceGroup[] = DIRECTORY): PageMeta {
  return {
    path: CLUBS_PATH,
    title: 'باشگاه‌های تنیس، پدل، بدمینتون و اسکواش' + BRAND,
    description: `فهرست ${fa(totalClubs(directory))} باشگاه تنیس، پدل، بدمینتون و اسکواش در ${fa(directory.length)} استان ایران، به تفکیک استان، شهر و ورزش؛ برای هر باشگاه در رالیتو هم‌بازی هم‌سطح پیدا کن.`,
    indexable: totalClubs(directory) >= INDEX_MIN_CLUBS,
    crumbs: [HOME, CLUBS_CRUMB],
  }
}

export function provinceClubsPage(province: ProvinceGroup): PageMeta {
  return {
    path: province.path,
    title: fitTitle(`باشگاه‌های تنیس، پدل و اسکواش استان ${province.name}${BRAND}`, `باشگاه‌های استان ${province.name}${BRAND}`),
    description: `${fa(province.clubCount)} باشگاه تنیس، پدل، بدمینتون و اسکواش در ${fa(province.cities.length)} شهر استان ${province.name}. شهرت را انتخاب کن و در رالیتو هم‌بازی هم‌سطح پیدا کن.`,
    indexable: province.clubCount >= INDEX_MIN_CLUBS,
    crumbs: [HOME, CLUBS_CRUMB, { name: `استان ${province.name}`, path: province.path }],
  }
}

export function cityClubsPage(province: ProvinceGroup, city: CityGroup, directory: readonly ProvinceGroup[] = DIRECTORY): PageMeta {
  const label = cityLabel(city, province, directory)
  const sports = joinFa(sportsIn(city).map((s) => s.name))
  return {
    path: city.path,
    title: fitTitle(`باشگاه‌های ${sports} در ${label}${BRAND}`, `باشگاه‌های ورزشی ${label}${BRAND}`, `باشگاه‌های ${label}${BRAND}`),
    description: `فهرست ${fa(city.clubs.length)} باشگاه ${sports} در ${city.name}، استان ${province.name}. در رالیتو برای همین باشگاه‌ها هم‌بازی هم‌سطح پیدا کن یا بازی باز بگذار.`,
    indexable: city.clubs.length >= INDEX_MIN_CLUBS,
    crumbs: [HOME, CLUBS_CRUMB, { name: `استان ${province.name}`, path: province.path }, { name: city.name, path: city.path }],
  }
}

export function citySportClubsPage(province: ProvinceGroup, city: CityGroup, sport: Sport, directory: readonly ProvinceGroup[] = DIRECTORY): PageMeta {
  const label = cityLabel(city, province, directory)
  const count = clubsOf(city, sport).length
  const path = citySportPath(city, sport)
  return {
    path,
    title: fitTitle(`باشگاه ${sport.name} در ${label}${BRAND}`, `باشگاه ${sport.name} ${city.name}${BRAND}`),
    description: `فهرست ${fa(count)} باشگاه ${sport.name} در ${city.name}، استان ${province.name}. در رالیتو برای همین باشگاه‌ها هم‌بازی ${sport.name} هم‌سطح پیدا کن یا بازی باز بگذار.`,
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

/** Every page of the club directory, built or not indexable; empty while the directory snapshot is empty. */
export function clubPages(directory: readonly ProvinceGroup[] = DIRECTORY): PageMeta[] {
  if (directory.length === 0) return []
  return [
    clubsHubPage(directory),
    ...directory.flatMap((p) => [
      provinceClubsPage(p),
      ...p.cities.flatMap((c) => [cityClubsPage(p, c, directory), ...sportsIn(c).map((s) => citySportClubsPage(p, c, s, directory))]),
    ]),
  ]
}

/** Every page that belongs in the sitemap, in order. */
export function indexablePages(): PageMeta[] {
  const [home, ...rest] = Object.values(PAGES).filter((p) => p.indexable)
  const clubs = directoryPublished() ? clubPages().filter((p) => p.indexable) : []
  return [home, ...publishedSports().map(sportPage), ...clubs, ...rest]
}
