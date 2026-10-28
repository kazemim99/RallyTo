// @ts-check
import { defineConfig } from 'astro/config'
import { SPECULATION_RULES, sha256 } from './src/config/inline-scripts.mjs'

// `npm run build:test` builds into dist-test/ (no visit statistics), the folder the dist tests and Lighthouse read,
// so a test build can never be the one that gets deployed (the deploy ships dist/).
const testBuild = process.env.LANDING_BUILD === 'test'

export default defineConfig({
  site: 'https://rallyto.ir',
  outDir: testBuild ? './dist-test' : './dist',
  trailingSlash: 'never',
  build: {
    // /tennis is served from tennis.html (nginx: try_files $uri $uri.html =404).
    format: 'file',
    // Every page's CSS is small; inlining it removes the only render-blocking request besides the fonts.
    inlineStylesheets: 'always',
  },
  compressHTML: true,
  devToolbar: { enabled: false },
  vite: {
    // The brand geometry is read from ../branding/mark.json, outside this project.
    server: { fs: { allow: ['..'] } },
  },
  security: {
    // A CSP <meta> with the hashes of the inline scripts and styles Astro emits, plus the speculation rules.
    csp: {
      algorithm: 'SHA-256',
      directives: [
        "default-src 'self'",
        "img-src 'self' data:",
        "font-src 'self'",
        "connect-src 'self'",
        "base-uri 'self'",
        "form-action 'self'",
        "object-src 'none'",
      ],
      scriptDirective: { hashes: [sha256(SPECULATION_RULES)] },
    },
  },
})
