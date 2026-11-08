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

export interface PlaceFacts {
  name: string
  sports: readonly string[]
  city: string
  province: string
  address: string | null
  phone: { text: string } | null
  latitude: number | null
  longitude: number | null
  website: string | null
}

/** One club as a sports place, with what the catalog knows about it and nothing more: a missing fact is left out. */
function sportsPlace(c: PlaceFacts) {
  return {
    '@type': 'SportsActivityLocation',
    name: c.name,
    sport: c.sports,
    ...(c.phone ? { telephone: c.phone.text } : {}),
    ...(c.website ? { url: c.website } : {}),
    address: {
      '@type': 'PostalAddress',
      ...(c.address ? { streetAddress: c.address } : {}),
      addressLocality: c.city,
      addressRegion: c.province,
      addressCountry: 'IR',
    },
    ...(c.latitude !== null && c.longitude !== null ? { geo: { '@type': 'GeoCoordinates', latitude: c.latitude, longitude: c.longitude } } : {}),
  }
}

/** A directory page's clubs as an ItemList of sports places. */
export function clubListLd(name: string, path: string, clubs: readonly PlaceFacts[]) {
  return {
    '@context': 'https://schema.org',
    '@type': 'ItemList',
    name,
    url: absolute(path),
    numberOfItems: clubs.length,
    itemListElement: clubs.map((c, i) => ({ '@type': 'ListItem', position: i + 1, item: sportsPlace(c) })),
  }
}

/** A club's own page: the place itself, tied to the page by `mainEntityOfPage`, with its map when it has a position. */
export function clubLd(path: string, club: PlaceFacts, map: string | null) {
  return {
    '@context': 'https://schema.org',
    ...sportsPlace(club),
    mainEntityOfPage: absolute(path),
    ...(map ? { hasMap: map } : {}),
  }
}

/** A guide as an Article by Rallyto, with its real date of writing; no author is invented. */
export function articleLd(path: string, headline: string, description: string, published: string, image = OG_IMAGE_PATH) {
  return {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline,
    description,
    inLanguage: SITE.locale,
    datePublished: published,
    mainEntityOfPage: absolute(path),
    image: absolute(image),
    author: { '@type': 'Organization', name: SITE.name, url: absolute('/') },
    publisher: { '@type': 'Organization', name: SITE.name, logo: { '@type': 'ImageObject', url: absolute(LOGO_PATH) } },
  }
}
