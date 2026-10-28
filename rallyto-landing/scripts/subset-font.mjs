// Cuts the site's three faces down to the characters a Persian page can contain, as small WOFF2 files:
//   - Vazir regular and bold, read straight from the player app (`*-app/assets/fonts/vazir/`), so the site and the
//     app share one body face and can never drift apart;
//   - Estedad 900 (OFL, @fontsource/estedad) for display headings, its Arabic-script and Latin halves separately, so a
//     page whose headings are all Persian never downloads the Latin half (the @font-face unicode-range picks).
import { readdirSync } from 'node:fs'
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import subsetFont from 'subset-font'

const REPO = new URL('../../', import.meta.url)
const appFolder = readdirSync(REPO).find((name) => name.endsWith('-app') && readdirSync(new URL(name, REPO)).includes('pubspec.yaml'))
if (!appFolder) throw new Error('player app folder (*-app) not found next to rallyto-landing')
const APP_FONTS = new URL(`${appFolder}/assets/fonts/vazir/`, REPO)
const ESTEDAD = new URL('../node_modules/@fontsource/estedad/files/', import.meta.url)

/** Inclusive code point ranges: Persian letters and marks, Persian digits, the punctuation in use. */
export const PERSIAN = [
  [0x00a0, 0x00a0], // no-break space
  [0x00ab, 0x00ab], // «
  [0x00bb, 0x00bb], // »
  [0x00d7, 0x00d7], // ×
  [0x060c, 0x060c], // ،
  [0x061b, 0x061b], // ؛
  [0x061f, 0x061f], // ؟
  [0x0621, 0x063a], // Arabic letters used in Persian
  [0x0640, 0x0655], // tatweel, letters, harakat (kasre-ye ezafe)
  [0x066a, 0x066c], // ٪ ٫ ٬
  [0x0670, 0x0670], // superscript alef
  [0x067e, 0x067e], // پ
  [0x0686, 0x0686], // چ
  [0x0698, 0x0698], // ژ
  [0x06a9, 0x06a9], // ک
  [0x06af, 0x06af], // گ
  [0x06c0, 0x06c0], // ۀ
  [0x06cc, 0x06cc], // ی
  [0x06f0, 0x06f9], // ۰–۹
  [0x200c, 0x200f], // ZWNJ, ZWJ, LRM, RLM
  [0x2013, 0x2014], // – —
  [0x2018, 0x201d], // quotes
  [0x2022, 0x2022], // •
  [0x2026, 0x2026], // …
  [0x2212, 0x2212], // −
]
export const ASCII = [[0x0020, 0x007e]]

const chars = (ranges) =>
  ranges.flatMap(([from, to]) => Array.from({ length: to - from + 1 }, (_, i) => String.fromCodePoint(from + i))).join('')

const FACES = [
  { source: new URL('Vazir.ttf', APP_FONTS), target: 'vazir-regular.woff2', text: chars([...ASCII, ...PERSIAN]) },
  { source: new URL('Vazir-Bold.ttf', APP_FONTS), target: 'vazir-bold.woff2', text: chars([...ASCII, ...PERSIAN]) },
  { source: new URL('estedad-arabic-900-normal.woff2', ESTEDAD), target: 'estedad-black-fa.woff2', text: chars(PERSIAN) },
  { source: new URL('estedad-latin-900-normal.woff2', ESTEDAD), target: 'estedad-black-latin.woff2', text: chars(ASCII) },
]

const out = new URL('../src/assets/fonts/', import.meta.url)
await mkdir(out, { recursive: true })
for (const face of FACES) {
  const input = await readFile(face.source)
  const output = await subsetFont(input, face.text, { targetFormat: 'woff2' })
  await writeFile(new URL(face.target, out), output)
  console.log(`${face.target}: ${input.length} → ${output.length} bytes`)
}
