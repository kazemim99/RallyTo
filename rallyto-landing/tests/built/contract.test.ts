import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { beforeAll, describe, expect, it } from 'vitest'
import { SITE } from '../../src/config/site'
import { indexablePages } from '../../src/data/pages'
import { DIST, builtPages, fileInDist, jsonLd, page, pngSize, visibleText, type BuiltPage } from './built-site'

/** The built site: metadata, structured data, crawl control, Persian text, honesty and links. */

const INVENTED = ['هزاران', 'کاربر فعال', '+۱۰۰', '۱۰۰٪', '★', 'بهترین اپ', 'برنده', 'تومان', 'شماره‌ی ثبت', 'اینماد']
const SPORT_PATHS = ['/tennis', '/padel', '/badminton', '/squash']

let pages: BuiltPage[]
let indexable: BuiltPage[]

beforeAll(() => {
  pages = builtPages()
  indexable = indexablePages().map((m) => page(pages, m.path))
})

const meta = (p: BuiltPage, selector: string) => p.root.querySelector(selector)?.getAttribute('content') ?? ''
// Persian path segments (the club directory) are percent-encoded in every absolute URL.
const canonicalOf = (path: string) => (path === '/' ? `${SITE.url}/` : `${SITE.url}${encodeURI(path)}`)

describe('every page', () => {
  it('is Persian, right to left', () => {
    for (const p of pages) {
      const html = p.root.querySelector('html')!
      expect(html.getAttribute('lang'), p.path).toBe('fa-IR')
      expect(html.getAttribute('dir'), p.path).toBe('rtl')
    }
  })

  it('uses Persian ی and ک, never Arabic ي and ك, in visible text', () => {
    for (const p of pages) expect(visibleText(p).match(/[يك]/g) ?? [], p.path).toEqual([])
  })

  it('makes no invented claim and states no price', () => {
    for (const p of pages) for (const claim of INVENTED) expect(visibleText(p), `${p.path}: ${claim}`).not.toContain(claim)
  })

  it('links the terms, the privacy policy and the contact page from its footer, and the sports once published', () => {
    const expected = ['/terms', '/privacy', '/contact', ...(SITE.sportPagesPublished ? SPORT_PATHS : [])]
    for (const p of pages) {
      const hrefs = p.root.querySelectorAll('footer a').map((a) => a.getAttribute('href'))
      expect(hrefs, p.path).toEqual(expect.arrayContaining(expected))
    }
  })

  it('has no inline event handlers and no inline style attributes (the CSP forbids both)', () => {
    for (const p of pages) {
      expect(p.html, p.path).not.toMatch(/\son[a-z]+=/i)
      expect(p.root.querySelectorAll('body [style]').map((e) => e.rawTagName), p.path).toEqual([])
    }
  })

  it('carries a content security policy and the speculation rules', () => {
    for (const p of pages) {
      expect(p.root.querySelector('meta[http-equiv="content-security-policy"]'), p.path).not.toBeNull()
      expect(p.root.querySelector('script[type="speculationrules"]'), p.path).not.toBeNull()
    }
  })

  it('turns motion off for visitors who ask for reduced motion', () => {
    for (const p of pages) expect(p.html, p.path).toContain('prefers-reduced-motion')
  })

  it('loads nothing from another origin', () => {
    for (const p of pages) {
      const refs = p.root
        .querySelectorAll('[src], link[href]')
        .map((e) => e.getAttribute('src') ?? e.getAttribute('href') ?? '')
        .filter((u) => /^(https?:)?\/\//.test(u) && !u.startsWith(SITE.url))
      expect(refs, p.path).toEqual([])
    }
  })

  it('links only to pages and files that exist', () => {
    for (const p of pages) {
      for (const a of p.root.querySelectorAll('a[href^="/"]')) {
        const href = a.getAttribute('href')!
        // The APK is not part of the build: nginx serves it from beside the site (deploy/nginx/rallyto-landing.conf).
        if (href === SITE.direct.apk) continue
        expect(fileInDist(href), `${p.path} → ${href}`).toBeDefined()
      }
    }
  })

  it('gives every image an alt text, and every svg a label or hides it from assistive technology', () => {
    for (const p of pages) {
      for (const img of p.root.querySelectorAll('img')) expect(img.hasAttribute('alt'), `${p.path} img`).toBe(true)
      for (const svg of p.root.querySelectorAll('body svg')) {
        const labelled =
          svg.getAttribute('aria-label') || svg.getAttribute('aria-hidden') === 'true' || svg.getAttribute('role') === 'presentation'
        expect(labelled, `${p.path} svg`).toBeTruthy()
      }
    }
  })
})

describe('metadata of indexable pages', () => {
  it('has exactly one h1', () => {
    for (const p of indexable) expect(p.root.querySelectorAll('h1'), p.path).toHaveLength(1)
  })

  it('has a unique title of at most 60 characters and a unique description of 70–160', () => {
    const titles = indexable.map((p) => p.root.querySelector('title')!.text)
    const descriptions = indexable.map((p) => meta(p, 'meta[name="description"]'))
    for (const [i, p] of indexable.entries()) {
      expect([...titles[i]].length, `${p.path} title`).toBeLessThanOrEqual(60)
      expect([...descriptions[i]].length, `${p.path} description`).toBeGreaterThanOrEqual(70)
      expect([...descriptions[i]].length, `${p.path} description`).toBeLessThanOrEqual(160)
    }
    expect(new Set(titles).size).toBe(titles.length)
    expect(new Set(descriptions).size).toBe(descriptions.length)
  })

  it('declares an absolute canonical and matching Open Graph data', () => {
    for (const p of indexable) {
      expect(p.root.querySelector('link[rel="canonical"]')?.getAttribute('href'), p.path).toBe(canonicalOf(p.path))
      expect(meta(p, 'meta[property="og:url"]'), p.path).toBe(canonicalOf(p.path))
      expect(meta(p, 'meta[property="og:title"]'), p.path).not.toBe('')
      expect(meta(p, 'meta[property="og:locale"]'), p.path).toBe('fa_IR')
    }
  })

  it('shares a 1200×630 image that exists on the site', () => {
    for (const p of indexable) {
      const image = meta(p, 'meta[property="og:image"]')
      expect(image.startsWith(`${SITE.url}/`), p.path).toBe(true)
      const file = fileInDist(new URL(image).pathname)
      expect(file, `${p.path}: ${image}`).toBeDefined()
      expect(pngSize(file!)).toEqual({ width: 1200, height: 630 })
    }
  })

  it('proves site ownership to Google Search Console on the home page', () => {
    expect(meta(page(pages, '/'), 'meta[name="google-site-verification"]')).toBe(SITE.googleSiteVerification)
  })

  it('keeps the 404 page out of the index', () => {
    expect(meta(page(pages, '/404'), 'meta[name="robots"]')).toContain('noindex')
  })
})

describe('structured data', () => {
  it('describes the organization, the site and the app on the home page', () => {
    const types = jsonLd(page(pages, '/')).map((d) => d['@type'])
    expect(types).toEqual(expect.arrayContaining(['Organization', 'WebSite', 'MobileApplication']))
  })

  it('gives every inner page a breadcrumb ending at its canonical URL', () => {
    for (const p of indexable.filter((x) => x.path !== '/')) {
      const crumbs = jsonLd(p).find((d) => d['@type'] === 'BreadcrumbList') as { itemListElement: { item: string }[] } | undefined
      expect(crumbs, p.path).toBeDefined()
      expect(crumbs!.itemListElement.at(-1)!.item, p.path).toBe(canonicalOf(p.path))
    }
  })

  it('claims no rating anywhere, and describes the app as free', () => {
    for (const p of pages) expect(JSON.stringify(jsonLd(p)), p.path).not.toMatch(/AggregateRating/)
    const app = jsonLd(page(pages, '/')).find((d) => d['@type'] === 'MobileApplication') as { offers: { price: string } }
    expect(app.offers.price).toBe('0')
  })
})

describe('crawl files', () => {
  const read = (name: string) => readFileSync(join(DIST, name), 'utf8')

  it('lists exactly the indexable pages in the sitemap', () => {
    const locs = [...read('sitemap.xml').matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1])
    expect(locs).toEqual(indexablePages().map((p) => canonicalOf(p.path)))
  })

  it('allows crawling and points to the sitemap', () => {
    expect(read('robots.txt')).toContain(`Sitemap: ${SITE.url}/sitemap.xml`)
  })

  it('ships a web manifest whose icons exist', () => {
    const manifest = JSON.parse(read('manifest.webmanifest')) as { icons: { src: string }[] }
    for (const icon of manifest.icons) expect(fileInDist(icon.src), icon.src).toBeDefined()
  })
})

describe('the home page', () => {
  it('lets the visitor pick each of the four sports without JavaScript', () => {
    const home = page(pages, '/')
    const radios = home.root.querySelectorAll('input[type="radio"][name="hero-sport"]').map((r) => r.getAttribute('value'))
    expect(radios).toEqual(['tennis', 'padel', 'badminton', 'squash'])
    expect(home.root.querySelectorAll('script:not([type])')).toHaveLength(0)
  })

  it('offers the Android APK and the web app for iPhone in the download block (owner decision 2026-11-07)', () => {
    const block = page(pages, '/').root.querySelector('#download')!
    const hrefs = block.querySelectorAll('a').map((a) => a.getAttribute('href'))
    expect(hrefs).toEqual(expect.arrayContaining([SITE.direct.apk, SITE.direct.webApp]))
    expect(block.querySelector(`a[href="${SITE.direct.apk}"]`)!.getAttribute('download')).toBe('rallyto.apk')
    expect(block.text).toContain('آیفون')
    expect(block.text).toContain('Add to Home Screen')
  })

  it('no longer says anywhere that the Android app is only coming', () => {
    for (const p of pages) expect(visibleText(p), p.path).not.toMatch(/نسخه‌ی اندروید(?: آن)? به‌زودی/)
  })

  it('never links to a store listing that does not exist yet', () => {
    const home = page(pages, '/')
    const storeLinks = home.root.querySelectorAll('a[href*="cafebazaar"], a[href*="myket"]')
    expect(storeLinks.length).toBe(Object.values(SITE.stores).filter(Boolean).length)
  })
})

describe('owner decisions (2026-10-29)', () => {
  it('builds the four sport pages and links them from every footer, now that the venue catalog has clubs', () => {
    expect(SITE.sportPagesPublished).toBe(true)
    for (const path of SPORT_PATHS) expect(fileInDist(path), path).toBeDefined()
    for (const p of pages) {
      const hrefs = p.root.querySelectorAll('footer a').map((a) => a.getAttribute('href'))
      expect(hrefs, p.path).toEqual(expect.arrayContaining(SPORT_PATHS))
    }
  })

  it('says on the home page that the app is free, and keeps the stores at «به‌زودی»', () => {
    const text = visibleText(page(pages, '/'))
    expect(text).toContain('رالیتو رایگان است')
    expect(text).toContain('به‌زودی در')
  })

  it('shows the responsible person, location and a dialable phone on the contact page', () => {
    const contact = page(pages, '/contact')
    const text = visibleText(contact)
    expect(text).toContain(SITE.responsible.name)
    expect(text).toContain(SITE.responsible.location)
    expect(text).toContain(SITE.responsible.phone)
    expect(contact.root.querySelector(`a[href="tel:${SITE.responsible.phoneE164}"]`)).not.toBeNull()
  })

  it('states the one-month retention for chats and reports on the privacy page', () => {
    const text = visibleText(page(pages, '/privacy'))
    expect(text).toContain('پیام‌های گفتگو و درخواست‌های پیام: حداکثر یک ماه')
    expect(text).toContain('گزارش‌ها و نسخه‌ی ذخیره‌شده‌ی محتوای گزارش‌شده: حداکثر یک ماه')
  })
})

describe('the club directory (owner decision 2026-11-01, built from tests/fixtures/venues.sample.json)', () => {
  const directoryPages = () => pages.filter((p) => p.path === '/clubs' || p.path.startsWith('/clubs/'))

  it('offers a sport, province and city finder at the top of the home page that opens the directory', () => {
    const home = page(pages, '/')
    const form = home.root.querySelector('.hero__copy form[data-club-finder]')!
    expect(form.getAttribute('action')).toBe('/clubs')
    for (const name of ['sport', 'province', 'city']) expect(form.querySelector(`select[name="${name}"]`), name).not.toBeNull()
    const sports = form.querySelectorAll('select[name="sport"] option').map((o) => o.getAttribute('value'))
    expect(sports).toEqual(['', 'tennis', 'padel', 'badminton', 'squash'])
    const cities = form.querySelectorAll('select[name="city"] option[value^="/clubs/"]').map((o) => o.getAttribute('value')!)
    for (const path of cities) expect(fileInDist(path), path).toBeDefined()
  })

  it('credits OpenStreetMap, the source of the addresses taken from the map, in every footer', () => {
    for (const p of pages) expect(p.root.querySelectorAll('footer a').map((a) => a.getAttribute('href')), p.path).toContain('https://www.openstreetmap.org/copyright')
  })

  it('links the directory from the header and every footer', () => {
    for (const p of pages) expect(p.root.querySelectorAll('footer a').map((a) => a.getAttribute('href')), p.path).toContain('/clubs')
    expect(page(pages, '/').root.querySelectorAll('header a').map((a) => a.getAttribute('href'))).toContain('/clubs')
  })

  it('lists on each city page exactly the clubs of that city', () => {
    const shiraz = page(pages, '/clubs/فارس/شیراز')
    const names = shiraz.root.querySelectorAll('.club__name').map((n) => n.text.trim())
    expect(names).toEqual(['باشگاه تنیس شیراز', 'سالن اسکواش شیراز', 'مجموعه ورزشی پارس'])
    expect(page(pages, '/clubs/فارس/شیراز/padel').root.querySelectorAll('.club__name').map((n) => n.text.trim())).toEqual(['مجموعه ورزشی پارس'])
  })

  it('marks what the sport filter needs on a province page, which still lists every club without it', () => {
    const province = page(pages, '/clubs/تهران')
    const clubs = province.root.querySelectorAll('#results .club')
    expect(clubs.length).toBeGreaterThan(1)
    for (const club of clubs) {
      const shown = club.querySelectorAll('.chip').map((c) => c.text.trim())
      expect(club.getAttribute('data-sports')!.split(' ')).toHaveLength(shown.length)
      expect(club.hasAttribute('hidden')).toBe(false)
    }
    const filter = province.root.querySelector('[data-sport-filter]')!
    expect(filter.hasAttribute('hidden')).toBe(true)
    expect(filter.getAttribute('data-place')).toBe('استان تهران')
    expect(filter.querySelector('a')!.getAttribute('href')).toBe('/clubs/تهران#results')
    expect(province.root.querySelector('[data-results-title]')).not.toBeNull()
    expect(province.root.querySelectorAll('[data-city-section]').length).toBeGreaterThan(0)
  })

  it('tells the finder which sports each province and city has, and how many clubs', () => {
    const form = page(pages, '/').root.querySelector('form[data-club-finder]')!
    const shiraz = form.querySelector('select[name="city"] option[value="/clubs/فارس/شیراز"]')!
    expect(shiraz.getAttribute('data-sports')!.split(' ')).toContain('tennis')
    expect(shiraz.getAttribute('data-counts')).toMatch(/tennis:\d/)
    expect(shiraz.getAttribute('data-total')).toBe('3')
    expect(form.querySelector('select[name="province"] option[value="/clubs/فارس"]')!.getAttribute('data-sports')).toContain('tennis')
  })

  it('keeps pages with too few clubs out of the index and the sitemap, but builds and links them', () => {
    const thin = page(pages, '/clubs/تهران/اسلام-شهر')
    expect(meta(thin, 'meta[name="robots"]')).toContain('noindex')
    const sitemap = readFileSync(join(DIST, 'sitemap.xml'), 'utf8')
    expect(sitemap).not.toContain(encodeURI('/clubs/تهران/اسلام-شهر'))
    expect(sitemap).toContain(encodeURI('/clubs/تهران/تهران/tennis'))
    expect(page(pages, '/clubs/تهران').root.querySelectorAll('a').map((a) => a.getAttribute('href'))).toContain('/clubs/تهران/اسلام-شهر')
  })

  const clubRow = (path: string, name: string) =>
    page(pages, path).root.querySelectorAll('.club').find((c) => c.querySelector('.club__name')!.text.trim() === name)!

  it('shows a club’s address, phone, hours, map and own links in the results', () => {
    const club = clubRow('/clubs/فارس/شیراز', 'باشگاه تنیس شیراز')
    expect(club.querySelector('address')!.text).toBe('شیراز، بلوار چمران، کوچه‌ی ۲۴')
    const phone = club.querySelector('a[href^="tel:"]')!
    expect(phone.getAttribute('href')).toBe('tel:07136260000')
    expect(phone.text.trim()).toBe('۰۷۱۳۶۲۶۰۰۰۰')
    expect(club.text).toContain('همه‌روزه ۷ تا ۲۴')
    const hrefs = club.querySelectorAll('a').map((a) => a.getAttribute('href'))
    expect(hrefs).toContain('https://www.google.com/maps/search/?api=1&query=29.6365,52.5219&query_place_id=ChIJshirazclub')
    expect(hrefs).toContain('https://balad.ir/location?latitude=29.6365&longitude=52.5219&zoom=17')
    expect(hrefs).toEqual(expect.arrayContaining(['https://shiraztennis.example.ir', 'https://www.instagram.com/shiraztennis', 'https://t.me/shiraztennis']))
    expect(club.querySelector('details')!.text).toContain('۴ زمین خاک رس')
    expect(club.text).toContain('مشاهده روی نقشه')
  })

  it('says when a club has no exact address, and shows no phone, map or link it does not have', () => {
    const club = clubRow('/clubs/فارس/شیراز', 'سالن اسکواش شیراز')
    expect(club.text).toContain('نشانی دقیق ثبت نشده')
    expect(club.querySelector('address')).toBeNull()
    // Only its name, which leads to its own page.
    expect(club.querySelectorAll('a').map((a) => a.getAttribute('class'))).toEqual(['club__name'])
    expect(club.querySelector('details')).toBeNull()
  })

  it('opens every outside link safely, in a new tab', () => {
    for (const p of directoryPages()) {
      for (const a of p.root.querySelectorAll('.club a[href^="http"]')) {
        expect(a.getAttribute('target'), p.path).toBe('_blank')
        expect(a.getAttribute('rel'), p.path).toContain('noopener')
        expect(a.getAttribute('rel'), p.path).toContain('nofollow')
      }
    }
  })

  it('shows the results on the pages the finder opens without a city too', () => {
    const province = page(pages, '/clubs/فارس')
    expect(province.root.querySelector('#results')).not.toBeNull()
    expect(province.root.querySelector('#results a[href^="tel:"]')).not.toBeNull()
    expect(province.root.querySelector('#results .results-title')!.text).toContain('استان فارس')
    expect(page(pages, '/clubs/فارس/شیراز').root.querySelector('#results .list-title')!.text).toContain('شیراز')
    const sport = page(pages, '/clubs/فارس/شیراز/tennis').root.querySelector('#results .results-title')!.text
    expect(sport).toContain('تنیس')
    expect(sport).toContain('شیراز')
  })

  it('describes each page’s clubs as sports places with what the catalog knows, and nothing else', () => {
    const list = jsonLd(page(pages, '/clubs/فارس/شیراز')).find((d) => d['@type'] === 'ItemList') as {
      itemListElement: { item: { name: string } & Record<string, unknown> }[]
    }
    expect(list.itemListElement).toHaveLength(3)
    const full = list.itemListElement.find((i) => i.item.name === 'باشگاه تنیس شیراز')!.item
    expect(full).toMatchObject({
      '@type': 'SportsActivityLocation',
      telephone: '07136260000',
      url: 'https://shiraztennis.example.ir',
      address: { streetAddress: 'شیراز، بلوار چمران، کوچه‌ی ۲۴', addressLocality: 'شیراز' },
      geo: { '@type': 'GeoCoordinates', latitude: 29.6365, longitude: 52.5219 },
    })
    const bare = list.itemListElement.find((i) => i.item.name === 'سالن اسکواش شیراز')!.item
    expect(bare).toMatchObject({ address: { addressLocality: 'شیراز' } })
    expect(JSON.stringify(bare)).not.toMatch(/streetAddress|telephone|geo|"url"/)
  })

  it('points every sport page to the cities with clubs for that sport', () => {
    const hrefs = page(pages, '/tennis').root.querySelectorAll('#clubs a').map((a) => a.getAttribute('href'))
    expect(hrefs).toContain('/clubs/تهران/تهران/tennis')
  })
})

describe('club pages (SEO audit 2026-11-02)', () => {
  const shirazClub = '/clubs/فارس/شیراز/باشگاه-تنیس-شیراز'

  it('links every club in a list to its own page', () => {
    const links = page(pages, '/clubs/فارس/شیراز').root.querySelectorAll('a.club__name')
    expect(links.map((a) => a.getAttribute('href'))).toEqual([shirazClub, '/clubs/فارس/شیراز/سالن-اسکواش-شیراز', '/clubs/فارس/شیراز/مجموعه-ورزشی-پارس'])
  })

  it('names the club in the h1 and shows how to reach it', () => {
    const club = page(pages, shirazClub)
    expect(club.root.querySelector('h1')!.text.trim()).toBe('باشگاه تنیس شیراز')
    expect(club.root.querySelector('#results address')!.text).toBe('شیراز، بلوار چمران، کوچه‌ی ۲۴')
    expect(club.root.querySelector('#results a[href^="tel:"]')!.getAttribute('href')).toBe('tel:07136260000')
    expect(club.root.querySelector('#results .club__name')).toBeNull()
    expect(club.root.querySelector('title')!.text).toBe('باشگاه تنیس شیراز: آدرس، تلفن و نقشه | رالیتو')
  })

  it('describes the club as one sports place belonging to the page', () => {
    const place = jsonLd(page(pages, shirazClub)).find((d) => d['@type'] === 'SportsActivityLocation')!
    expect(place).toMatchObject({
      name: 'باشگاه تنیس شیراز',
      telephone: '07136260000',
      mainEntityOfPage: canonicalOf(shirazClub),
      hasMap: 'https://www.google.com/maps/search/?api=1&query=29.6365,52.5219&query_place_id=ChIJshirazclub',
    })
  })

  it('lists the other clubs of its sports in the city, with the distance when both have a position', () => {
    const nearby = page(pages, shirazClub).root.querySelectorAll('.nearby__list li')
    expect(nearby).toHaveLength(1)
    expect(nearby[0].querySelector('a')!.getAttribute('href')).toBe('/clubs/فارس/شیراز/مجموعه-ورزشی-پارس')
    expect(nearby[0].text).toContain('فاصله')
  })

  it('indexes a club page only when it says where the club is and how to reach it', () => {
    const sitemap = readFileSync(join(DIST, 'sitemap.xml'), 'utf8')
    expect(sitemap).toContain(encodeURI(shirazClub))
    const bare = page(pages, '/clubs/فارس/شیراز/سالن-اسکواش-شیراز')
    expect(meta(bare, 'meta[name="robots"]')).toContain('noindex')
    expect(sitemap).not.toContain(encodeURI('/clubs/فارس/شیراز/سالن-اسکواش-شیراز'))
  })
})

describe('guides (SEO audit 2026-11-02)', () => {
  it('links the guides from every footer, and each sport page to its rules', () => {
    for (const p of pages) expect(p.root.querySelectorAll('footer a').map((a) => a.getAttribute('href')), p.path).toContain('/guides')
    expect(page(pages, '/padel').root.querySelectorAll('.facts a').map((a) => a.getAttribute('href'))).toEqual(['/guides/find-partner', '/guides/padel', '/guides/padel-vs-tennis'])
  })

  it('links the finding-a-partner guide from all four sport pages, and sends its reader to all four', () => {
    for (const path of SPORT_PATHS) {
      expect(page(pages, path).root.querySelectorAll('.facts a').map((a) => a.getAttribute('href')), path).toContain('/guides/find-partner')
    }
    const hrefs = page(pages, '/guides/find-partner').root.querySelectorAll('.guide__aside a').map((a) => a.getAttribute('href'))
    expect(hrefs).toEqual(expect.arrayContaining(SPORT_PATHS))
  })

  it('shows every figure of a guide with its description and its real size, so the page does not jump', () => {
    const images = page(pages, '/guides/find-partner').root.querySelectorAll('.guide__body figure img')
    expect(images.length).toBeGreaterThanOrEqual(3)
    for (const img of images) {
      const src = img.getAttribute('src')!
      const file = fileInDist(src)
      expect(file, src).toBeDefined()
      expect(img.getAttribute('alt')!.length, src).toBeGreaterThan(20)
      expect(pngSize(file!), src).toEqual({ width: Number(img.getAttribute('width')), height: Number(img.getAttribute('height')) })
    }
    for (const figure of page(pages, '/guides/find-partner').root.querySelectorAll('.guide__body figure')) {
      expect(figure.querySelector('figcaption')?.text.trim()).toBeTruthy()
    }
  })

  it('shares a guide with its own image when it has one, in the preview and in the article', () => {
    const guide = page(pages, '/guides/find-partner')
    const share = `${SITE.url}/guides/find-partner/level-time-club.png`
    expect(meta(guide, 'meta[property="og:image"]')).toBe(share)
    expect(meta(guide, 'meta[property="og:image:alt"]')).toContain('سطح')
    expect(jsonLd(guide).find((d) => d['@type'] === 'Article')).toMatchObject({ image: share, datePublished: '2026-11-03' })
    expect(meta(page(pages, '/guides/padel'), 'meta[property="og:image"]')).toBe(`${SITE.url}/og/default.png`)
  })

  it('publishes each guide as an article by Rallyto, with its date', () => {
    const article = jsonLd(page(pages, '/guides/padel')).find((d) => d['@type'] === 'Article')!
    expect(article).toMatchObject({ headline: 'پدل چیست و چطور بازی می‌شود؟', datePublished: '2026-11-02', author: { name: 'رالیتو' } })
  })

  it('sends a guide reader to the partner page and the club lists of its sport', () => {
    const hrefs = page(pages, '/guides/tennis-scoring').root.querySelectorAll('.guide__aside a').map((a) => a.getAttribute('href'))
    expect(hrefs).toContain('/tennis')
    expect(hrefs).toContain('/clubs/تهران/تهران/tennis')
  })
})
