import { SITE } from '../config/site'

/** Absolute URL on the canonical host for a site path ("/" for the home page). Persian path segments (the club
 * directory's places) are percent-encoded, as a sitemap requires. */
export function absolute(path: string): string {
  return path === '/' ? `${SITE.url}/` : `${SITE.url}${encodeURI(path)}`
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

/**
 * A directory page's clubs as an ItemList of sports places. Each carries its name, sports and town only: Rallyto
 * publishes no club address, phone number or position (owner decision 2026-11-01).
 */
export function clubListLd(
  name: string,
  path: string,
  clubs: readonly { name: string; sports: readonly string[]; city: string; province: string }[],
) {
  return {
    '@context': 'https://schema.org',
    '@type': 'ItemList',
    name,
    url: absolute(path),
    numberOfItems: clubs.length,
    itemListElement: clubs.map((c, i) => ({
      '@type': 'ListItem',
      position: i + 1,
      item: {
        '@type': 'SportsActivityLocation',
        name: c.name,
        sport: c.sports,
        address: { '@type': 'PostalAddress', addressLocality: c.city, addressRegion: c.province, addressCountry: 'IR' },
      },
    })),
  }
}
