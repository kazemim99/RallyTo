/** Facts about the product that every page states. One place, so they can never disagree. */
export const SITE = {
  /** The canonical origin. The domain is rallyto.ir (the product was TennisYar until 2026-10-28). */
  url: 'https://rallyto.ir',
  name: 'رالیتو',
  latinName: 'Rallyto',
  tagline: 'هم‌بازی هم‌سطح برای تنیس، پدل، بدمینتون و اسکواش',
  locale: 'fa-IR',
  themeColor: '#0B4C3A',

  /** The Android package; the store links below are built from it. */
  androidPackage: 'ir.rallyto.app',

  /**
   * Where the app can be installed. `null` until the listing is live (tasks 11.4–11.7 in the main change): the
   * download block then says «به‌زودی» and links nowhere. Set a URL and rebuild once a store publishes the app.
   */
  stores: {
    bazaar: null as string | null,
    myket: null as string | null,
  },

  /** Profiles Google may connect to the organization (Organization.sameAs). Empty until they exist. */
  sameAs: [] as string[],

  /** Self-hosted, cookieless statistics, loaded only by production builds. `null` until it is set up. */
  analytics: null as { script: string; websiteId: string } | null,
} as const

/** Store links once live: Cafe Bazaar and Myket address an app by its package name. */
export const STORE_URLS = {
  bazaar: (pkg: string) => `https://cafebazaar.ir/app/${pkg}`,
  myket: (pkg: string) => `https://myket.ir/app/${pkg}`,
}
