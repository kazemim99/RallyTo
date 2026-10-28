import type { APIRoute } from 'astro'
import { indexablePages } from '../data/pages'
import { absolute } from '../lib/seo'

// Exactly the indexable pages, canonical URLs only. No lastmod: a build date on every page would be false.
export const GET: APIRoute = () => {
  const urls = indexablePages()
    .map((p) => `  <url><loc>${absolute(p.path)}</loc></url>`)
    .join('\n')
  return new Response(
    `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}\n</urlset>\n`,
    { headers: { 'Content-Type': 'application/xml; charset=utf-8' } },
  )
}
