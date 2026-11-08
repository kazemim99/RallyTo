# Club scrape and import

Collects tennis clubs from tennix.ir and tennisor.ir (their public JSON APIs; both allow crawling in robots.txt) and
loads them into Rallyto through the admin API.

```bash
# 1. Collect: output/clubs.json, output/clubs.csv, output/images/<source>/<slug>/NN.ext  (git-ignored)
python scrape_clubs.py

# 2. Load (credentials from the environment, never arguments). Safe to re-run.
export RALLYTO_ADMIN_EMAIL=... RALLYTO_ADMIN_PASSWORD=...
python import_to_rallyto.py --api http://localhost:5100 --dry-run     # city matching only
python import_to_rallyto.py --api http://localhost:5100
```

- A club is identified by its source reference (`tennix.ir:<slug>`). Clubs already in the catalog are left as they are
  and only receive photos while they have none.
- A club whose name is similar to one already in its city is skipped and listed; check the list, then use
  `--allow-similar` (optionally with `--skip-ref <ref>` for real duplicates).
- Places missing from the province/city dataset are mapped to the city they belong to in `CITY_ALIASES`.
- Ratings from the source sites are not imported.
- The API allows 300 requests a minute per user; the script paces itself and waits out a 429.

## Google Maps list (`google/`)

Replaces the catalog with the Google Maps spreadsheet (`باشگاه_های_تنیس_ایران_گوگل_مپ.xlsx`). The data files in
`google/` are git-ignored; only the scripts are kept.

1. `rows.json` is read from the spreadsheet; `chunkN.json` → `outN.json` are the Persian translations (name, town,
   readable address without plus codes, hours, useful notes, surface/indoor/court count).
2. `python build_items.py` maps each town to its county in the city dataset (`COUNTY`), formats phones as `0…`
   and writes `items.json`. `cities.txt` is `id|city|province` exported from `catalog.cities`.
3. `python plan.py` writes `plan.json`: medium-confidence places and the weaker listings of a place listed twice
   (within 60 m) are hidden for review. `hidden_for_review.csv` lists them with the reason.
4. `python import_google.py --api <url> snapshot hide-old import hide-plan carry`
   - `hide-old` hides the tennix/tennisor clubs (not deleted; `old_venues.json` is the snapshot).
   - `carry` gives a visible Google place the photos and profile of the old club within 150 m. Check `carry.json`
     for two different clubs side by side and undo those by hand. Run it once only: it appends descriptions.

## Padel, squash and badminton (`racket/`)

From the spreadsheet `ورزش_های_راکتی_ایران.xlsx` (sheet «همه مکان‌ها»; a place with several sports is one row).

1. `rows.json` → `chunkN.json` → Persian translations `outN.json` (as for the tennis list, plus `indoor` and `public`).
2. `python build_items.py` writes `items.json` (one venue per place, one sport entry per sport) and `plan.json`
   (hidden for review: medium confidence, not public — school yards and federation offices — and second listings of
   one place sharing a sport within 60 m). It reuses the town→county table of `google/build_items.py`.
3. `python import_racket.py --api <url> [--allow-similar]`. A place already in the catalog under the same Google
   place gains the sports it lacks instead of being created twice.

## Addresses from the map

Some imported clubs hold only their city's name as an address. `geocode_addresses.mjs` asks OpenStreetMap (Nominatim)
what is at each such club's position and writes `output/address_proposal.json` in the catalog's format, «شهر، محله،
مجموعه، خیابان». A part is left out rather than guessed, and a club stays without an address when the map adds nothing
to its city or names another city there. The address is the nearest thing the map names, so it can be a street off.

1. `node geocode_addresses.mjs`, then read the proposal.
2. `node apply_addresses.mjs sql`, and run `output/address_update.sql` on the catalog database after a backup.
3. `node apply_addresses.mjs snapshot` for the site's saved directory (or `npm run venues` once the API serves them).

The site credits OpenStreetMap in its footer (ODbL); keep that while these addresses are used.
