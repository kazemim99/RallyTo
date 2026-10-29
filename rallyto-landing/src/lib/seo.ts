import { SITE } from '../config/site'

/** Absolute URL on the canonical host for a site path ("/" for the home page). */
export function absolute(path: string): string {
  return path === '/' ? `${SITE.url}/` : `${SITE.url}${path}`
}

/** The logo Google may show for the organization: a square PNG on the site itself. */
export const LOGO_PATH = '/brand/logo-512.png'
/** The link-preview image every page shares (1200×630, rendered by scripts/render-og.mjs). */
export const OG_IMAGE_PATH = '/og/default.png'

export function organizationLd() {
  return {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    name: SITE.name,
    alternateName: SITE.latinName,
    url: absolute('/'),
    logo: absolute(LOGO_PATH),
    contactPoint: {
      '@type': 'ContactPoint',
      telephone: SITE.responsible.phoneE164,
      contactType: 'customer support',
      areaServed: 'IR',
      availableLanguage: 'fa',
    },
    ...(SITE.sameAs.length > 0 ? { sameAs: [...SITE.sameAs] } : {}),
  }
}

/** What Google reads for the site name in results. No SearchAction: the sitelinks search box was retired in 2024. */
export function websiteLd() {
  return {
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    name: SITE.name,
    alternateName: [SITE.latinName, 'Rallyto app'],
    url: absolute('/'),
    inLanguage: SITE.locale,
  }
}

/**
 * The Android app, free (owner decision, 2026-10-29). No `aggregateRating`: there are no store ratings yet, and ratings
 * copied from elsewhere are not allowed.
 */
export function mobileApplicationLd() {
  return {
    '@context': 'https://schema.org',
    '@type': 'MobileApplication',
    name: SITE.name,
    alternateName: SITE.latinName,
    url: absolute('/'),
    applicationCategory: 'SportsApplication',
    operatingSystem: 'ANDROID',
    inLanguage: SITE.locale,
    description: SITE.tagline,
    offers: { '@type': 'Offer', price: '0', priceCurrency: 'IRR' },
  }
}

export interface Crumb {
  name: string
  path: string
}

export function breadcrumbLd(crumbs: readonly Crumb[]) {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: crumbs.map((c, i) => ({
      '@type': 'ListItem',
      position: i + 1,
      name: c.name,
      item: absolute(c.path),
    })),
  }
}
