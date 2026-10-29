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

## Owner decisions (2026-10-29) and what is still open

- **Store links**: none yet. `SITE.stores.bazaar` / `myket` stay `null`, so the download block says «به‌زودی» and links
  nowhere. Set the real URLs in `src/config/site.ts` only once a store publishes the app.
- **Pricing**: the app is free. The hero, the download block, the FAQ and the terms say so, and the app's structured
  data carries a price of 0.
- **Retention**: chat messages (including message requests) and reports, with their saved copies, are kept for one
  month at most. The privacy page states it in each section that touches them and in a summary; the FAQ and terms
  agree. **The backend does not delete them yet**: a scheduled purge of messages and reports older than 30 days must
  ship before the site goes live, or the privacy page is not true.
- **Responsible person and contact**: مصطفی کاظمی, اردبیل، پارس‌آباد، بلوار ۳, ۰۹۱۲۳۱۳۵۱۴۳ (`SITE.responsible`), on
  `/contact`, in both policies, and as the Organization's contact point. No company name, registration number or
  eNamad is stated; add them only once they exist.
- **Sport pages**: published since 2026-10-29, once task 11.1 filled the venue catalog (515 active venues; tennis 340,
  badminton 105, padel 58, squash 30, each with clubs in Tehran). `SITE.sportPagesPublished` is the switch: off, the
  four pages are not built, not in the sitemap and not linked (remove them from `lighthouserc.cjs` too).
- **Statistics**: `SITE.analytics` is `null`; a cookieless, self-hosted counter can be plugged in there.
- **Hosting**: nginx serves `dist/` with `try_files $uri $uri.html =404`, `gzip_static on`, and the share links
  `/m/{token}` proxied to the API.
