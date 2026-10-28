import type { APIRoute } from 'astro'
import { SITE } from '../config/site'
import { indexablePages } from '../data/pages'
import { absolute } from '../lib/seo'

// A plain index of the site for language-model tools. Google Search ignores it; it costs one tiny file.
export const GET: APIRoute = () => {
  const pages = indexablePages()
    .map((p) => `- [${p.title}](${absolute(p.path)}): ${p.description}`)
    .join('\n')
  return new Response(`# ${SITE.name} (${SITE.latinName})\n\n> ${SITE.tagline}.\n\n## صفحه‌ها\n\n${pages}\n`, {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  })
}
