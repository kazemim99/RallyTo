# رالیتو — Rallyto landing site

The public site for **rallyto.ir**: what Rallyto is, one page per sport (tennis, padel, badminton, squash), download
links, and the privacy and terms pages. Static Astro build, Persian and right to left, no JavaScript on any page.

```
npm ci
npm run dev           # http://localhost:4321
npm run test:unit     # copy, metadata, contrast, logo drift, structured data
npm run build:test    # → dist-test/ (no statistics; what the built-site tests and Lighthouse read)
npm run test:built    # the built site against its contract
npm run lhci          # Lighthouse over dist-test/ (mobile; thresholds in lighthouserc.cjs)
npm run build         # → dist/ (the deployable build, precompressed .gz/.br next to every text file)
npm run og            # re-render public/og/default.png after a brand or tagline change
```

## How it is put together

- **Content** lives in `src/data/`: `pages.ts` (every title and description; the sitemap is built from it),
  `sports.ts` (the four sport pages: levels from the backend's catalog seeder, formats, questions), `faq.ts`, and
  `policies.ts` (privacy, terms). Every product statement is checked against the specs and the code; nothing states a
  price, a user count, a rating or a city the system does not have.
- **Brand**: the logo is drawn inline from `../branding/mark.json` (`src/lib/brand.ts`), the same numbers every app
  icon is rendered from; `tests/unit/brand.test.ts` fails if the two drift apart. Favicons and icons in `public/` come
  from `python ../branding/build_brand.py --render`.
- **Type**: Estedad Black for display headings, Vazir (read from the player app's own font files) for everything else,
  both subset to the Persian characters at build time (`scripts/subset-font.mjs`, about 62 KB for a first view).
- **The hero**: a top-down court redrawn for the sport the visitor picks (a radio group and `:has()`, no script), the
  rally on a CSS motion path, and the open game card. Motion runs a few times and stops; it never runs for visitors
  who ask for reduced motion.
- **Security**: a Content-Security-Policy `<meta>` with the hashes of every inline script and style; nothing loads from
  another origin.

## Before going live (owner decisions)

- **Store links**: set `SITE.stores.bazaar` / `myket` in `src/config/site.ts` once the listings are live; until then
  the download block says «به‌زودی» and links nowhere.
- **Clubs**: the sport pages talk about finding partners at clubs in Tehran and other cities; publish them once the
  venue catalog holds real clubs (main change task 11.1).
- **Policies**: `policies.ts` describes what the system does today. Have it reviewed, and decide retention periods for
  chats, reports and ratings (none is defined yet, and the privacy page says so).
- **Contact and legal entity**: none is stated anywhere; add them (and eNamad once there is a business registration).
- **Pricing**: the site never says the app is free; say so only once it is decided.
- **Statistics**: `SITE.analytics` is `null`; a cookieless, self-hosted counter can be plugged in there.
- **Hosting**: nginx serves `dist/` with `try_files $uri $uri.html =404`, `gzip_static on`, and the share links
  `/m/{token}` proxied to the API.
