# Rallyto brand assets

Rallyto (رالیتو) was named on 2026-10-28; until then the product was TennisYar (تنیس‌یار). Everything shipped — Flutter launcher
icons, adaptive icons, native splash images, the notification icon, web favicons, store listing icons, and the inline
marks in the app, the admin panel and the landing site — is built from one source: **`mark.json`**. Nothing is edited
by hand downstream. Change the geometry or a colour there, then run:

```
pip install pillow
python branding/build_brand.py --render
```

Without `--render` the script only rewrites the SVGs in this folder. Rendering uses headless Chrome (the default
install path, `$CHROME`, or `--chrome`), so every PNG follows the SVGs exactly; Pillow only resamples and writes
PNG/ICO.

## The mark: the rally loop

Two tapered arcs close a loop on a 100×100 grid. Each arc is the path of a ball from one player to the other: it starts
as a point beside its own player's ball and widens to a round head under the partner's ball. The second arc and ball
are the first turned half a turn. White trail → yellow ball, yellow trail → white ball: each player's shot reaches the
partner, and together they make the rally (and a circle of people who rally together). It belongs to no single sport,
so padel, badminton and squash players see themselves in it as much as tennis players do.

| `mark.json` | Meaning |
|---|---|
| `ringRadius` 25 | the loop the trails and balls sit on |
| `trail` −205° → −36°, width 13, taper 0.85 | the arc (screen angles, clockwise): half-width = width/2 · t^taper |
| `ball` −36°, radius 10.5 | the ball at the arc's head |
| `tile` radius 23, #187658 → #0B4C3A | the app icon's rounded square; the mark sits inside it at 90% |

## The files

| File | What it is |
|---|---|
| `symbol-reversed.svg` | The mark for brand-green or dark backgrounds: white and ball yellow (#D9EF70). |
| `symbol-color.svg` | The mark for light backgrounds: court green (#146B52) and clay (#E9783C). |
| `symbol-mono.svg` | One colour (ink). Its silhouette, in white, is the Android notification icon and themed-icon layer. |
| `appicon.svg` | The app icon: the reversed mark on the rounded court-green tile. |
| `fullbleed.svg` | An uncut square for platforms that apply their own mask (iOS, store listings, maskable web icons). |
| `lockup-persian.svg`, `lockup-latin.svg` | Reference lockups (tile + wordmark). Not embedded: the apps and sites set the wordmark in their own fonts. |
| `store/rallyto-{512,1024}.png` | Cafe Bazaar / Myket listing icons: opaque, uncut squares (the stores round them). |

## Where each one goes (`--render`)

| Output | From |
|---|---|
| Android `mipmap-*/ic_launcher.png` (48 dp) | `appicon` |
| Android adaptive icon `mipmap-*/ic_launcher_foreground.png`, `_monochrome.png` (108 dp, mark in the 66 dp safe zone) | `symbol-reversed`, `symbol-mono` (white) |
| Android `drawable-*/launch_mark.png` (96 dp, pre-12 splash), `splash_icon.png` (288 dp, Android 12+ splash) | `appicon` |
| Android `drawable-*/ic_notification.png` (24 dp, white silhouette) | `symbol-mono` |
| iOS `AppIcon.appiconset` (opaque) and `LaunchImage.imageset` (96 pt) | `fullbleed`, `appicon` |
| Admin `public/favicon.*`, `apple-touch-icon.png`, `src/assets/brand/appicon.svg` | `appicon`, `fullbleed` |
| Landing `public/favicon.*`, `apple-touch-icon.png`, `brand/logo-512.png`, `icons/*` | `appicon`, `fullbleed` |

Drawn in code from the same numbers (never from a PNG): the Flutter `BrandMark`/`BrandTile` widgets and the animated
launch splash (`rallyto-app/lib/core/widgets/`, pinned to `mark.json` by `brand_mark_test.dart`), and the landing's
`BrandMark` component (`rallyto-landing/src/lib/brand.ts`, pinned to the SVGs by `tests/unit/brand.test.ts`). The
landing's share image is rendered by `rallyto-landing/scripts/render-og.mjs`.

## Colours

| Token | Hex | Use |
|---|---|---|
| Court green | `#146B52` | primary actions, the mark on light backgrounds |
| Deep green | `#0B4C3A` | dark sections, the tile's gradient end |
| Ball yellow | `#D9EF70` | the yellow ball and trail; the action colour on dark backgrounds |
| Clay | `#E9783C` | the second colour of the light-background mark; fills only (text on it is ink) |
| Canvas | `#F5F8F7` | page and splash background |
| Ink | `#172522` | text, the one-colour mark |

These are the player app's own tokens (`AppColors`), so the brand needed no palette change anywhere.
