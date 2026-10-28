import type { APIRoute } from 'astro'
import { SITE } from '../config/site'

// Lets a visitor add the site to the home screen with the brand's own icon and colours.
export const GET: APIRoute = () =>
  new Response(
    JSON.stringify({
      name: SITE.name,
      short_name: SITE.name,
      description: SITE.tagline,
      lang: 'fa',
      dir: 'rtl',
      start_url: '/',
      display: 'browser',
      background_color: '#F5F8F7',
      theme_color: SITE.themeColor,
      icons: [
        { src: '/icons/icon-192.png', sizes: '192x192', type: 'image/png' },
        { src: '/icons/icon-512.png', sizes: '512x512', type: 'image/png' },
        { src: '/icons/maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
      ],
    }),
    { headers: { 'Content-Type': 'application/manifest+json; charset=utf-8' } },
  )
