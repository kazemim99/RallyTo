import { SITE } from '../config/site'
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

/** Every page that belongs in the sitemap, in order. */
export function indexablePages(): PageMeta[] {
  const [home, ...rest] = Object.values(PAGES).filter((p) => p.indexable)
  return [home, ...publishedSports().map(sportPage), ...rest]
}
