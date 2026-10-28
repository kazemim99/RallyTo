import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { beforeAll, describe, expect, it } from 'vitest'
import { SITE } from '../../src/config/site'
import { indexablePages } from '../../src/data/pages'
import { DIST, builtPages, fileInDist, jsonLd, page, pngSize, visibleText, type BuiltPage } from './built-site'

/** The built site: metadata, structured data, crawl control, Persian text, honesty and links. */

const INVENTED = ['هزاران', 'کاربر فعال', '+۱۰۰', '۱۰۰٪', '★', 'رایگان', 'بهترین اپ', 'برنده']

let pages: BuiltPage[]
let indexable: BuiltPage[]

beforeAll(() => {
  pages = builtPages()
  indexable = indexablePages().map((m) => page(pages, m.path))
})

const meta = (p: BuiltPage, selector: string) => p.root.querySelector(selector)?.getAttribute('content') ?? ''
const canonicalOf = (path: string) => (path === '/' ? `${SITE.url}/` : `${SITE.url}${path}`)

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

  it('links the sport pages, the terms and the privacy policy from its footer', () => {
    for (const p of pages) {
      const hrefs = p.root.querySelectorAll('footer a').map((a) => a.getAttribute('href'))
      expect(hrefs, p.path).toEqual(expect.arrayContaining(['/tennis', '/padel', '/badminton', '/squash', '/terms', '/privacy']))
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

  it('claims no rating or price anywhere', () => {
    for (const p of pages) expect(JSON.stringify(jsonLd(p)), p.path).not.toMatch(/AggregateRating|"offers"/)
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

  it('never links to a store listing that does not exist yet', () => {
    const home = page(pages, '/')
    const storeLinks = home.root.querySelectorAll('a[href*="cafebazaar"], a[href*="myket"]')
    expect(storeLinks.length).toBe(Object.values(SITE.stores).filter(Boolean).length)
  })
})
