// The only inline script the site emits besides Astro's own. It lives here so astro.config.mjs can hash exactly
// this string into the Content-Security-Policy and the layout renders exactly the same string.
import { createHash } from 'node:crypto'

/** Prerender same-site pages when a visitor shows intent (hover, pointerdown): instant navigation in Chromium. */
export const SPECULATION_RULES = JSON.stringify({
  prerender: [{ where: { href_matches: '/*' }, eagerness: 'moderate' }],
})

/** @param {string} text @returns {`sha256-${string}`} */
export const sha256 = (text) => `sha256-${createHash('sha256').update(text).digest('base64')}`
