import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { join, relative, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import { parse, type HTMLElement } from 'node-html-parser'

/** The test build (`npm run build:test`), never the deployable dist/. */
export const DIST = fileURLToPath(new URL('../../dist-test', import.meta.url))

export interface BuiltPage {
  /** Site path: "/", "/tennis", "/404". */
  path: string
  html: string
  root: HTMLElement
}

function walk(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(join(dir, e.name)) : [join(dir, e.name)]))
}

export function builtPages(): BuiltPage[] {
  if (!existsSync(DIST)) throw new Error(`No test build at ${DIST}: run "npm run build:test" first`)
  return walk(DIST)
    .filter((f) => f.endsWith('.html'))
    .map((file) => {
      const rel = relative(DIST, file).split(sep).join('/')
      const path = rel === 'index.html' ? '/' : `/${rel.replace(/\.html$/, '')}`
      const html = readFileSync(file, 'utf8')
      return { path, html, root: parse(html) }
    })
}

export function page(pages: BuiltPage[], path: string): BuiltPage {
  const found = pages.find((p) => p.path === path)
  if (!found) throw new Error(`no built page ${path}; have ${pages.map((p) => p.path).join(', ')}`)
  return found
}

/** The visible text of a page: body text without scripts and styles. */
export function visibleText(p: BuiltPage): string {
  const body = parse(p.html).querySelector('body')!
  for (const el of body.querySelectorAll('script, style, noscript')) el.remove()
  return body.text
}

export function jsonLd(p: BuiltPage): Record<string, unknown>[] {
  return p.root.querySelectorAll('script[type="application/ld+json"]').map((s) => JSON.parse(s.rawText) as Record<string, unknown>)
}

/** The built file a site path is served from, if any (nginx: try_files $uri $uri.html). */
export function fileInDist(sitePath: string): string | undefined {
  const clean = sitePath.split(/[?#]/)[0]
  const candidates = clean === '/' ? ['index.html'] : [clean.slice(1), `${clean.slice(1)}.html`]
  return candidates.map((c) => join(DIST, c)).find((f) => existsSync(f))
}

/** Width and height from a PNG's IHDR chunk. */
export function pngSize(file: string): { width: number; height: number } {
  const bytes = readFileSync(file)
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) }
}
