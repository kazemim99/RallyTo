/**
 * The site's colours, mirrored in src/styles/global.css as `--c-<name>` (tests/unit/contrast.test.ts holds the two
 * together and checks every pair below against WCAG 2.2 AA). The palette is the player app's (rallyto-app
 * AppColors) plus the four court surfaces of the hero.
 */
export const COLORS = {
  deep: '#0B4C3A',
  court: '#146B52',
  ball: '#D9EF70',
  clay: '#E9783C',
  ink: '#172522',
  muted: '#5C6B68',
  line: '#DCE5E2',
  canvas: '#F5F8F7',
  surface: '#FFFFFF',
  mint: '#CCE6DD',
  soft: '#E7F3EF',
  claySoft: '#FFF0E7',
  warning: '#8F4E12',
  tennis: '#1D7A5C',
  padel: '#2F6AAA',
  badminton: '#B85A2A',
  squash: '#D6A566',
  squashLine: '#982A27',
} as const

export type ColorName = keyof typeof COLORS

/** Text (≥ 4.5:1). [foreground, background]. */
export const TEXT_PAIRS: [ColorName, ColorName][] = [
  ['ink', 'canvas'],
  ['ink', 'surface'],
  ['muted', 'canvas'],
  ['muted', 'surface'],
  ['court', 'surface'],
  ['court', 'canvas'],
  ['court', 'soft'],
  ['surface', 'court'],
  ['surface', 'deep'],
  ['mint', 'deep'],
  ['ball', 'deep'],
  ['deep', 'ball'],
  ['warning', 'claySoft'],
  ['ink', 'clay'],
  ['surface', 'padel'],
  ['surface', 'badminton'],
  ['ink', 'squash'],
]

/** Controls and meaningful graphics (≥ 3:1): court lines on their surface, focus rings, button edges. */
export const UI_PAIRS: [ColorName, ColorName][] = [
  ['surface', 'tennis'],
  ['surface', 'padel'],
  ['surface', 'badminton'],
  ['squashLine', 'squash'],
  ['ball', 'tennis'],
  ['ball', 'padel'],
  ['ball', 'badminton'],
  ['ball', 'deep'],
  ['court', 'canvas'],
]

function channel(hex: string, i: number): number {
  const c = Number.parseInt(hex.slice(1 + i * 2, 3 + i * 2), 16) / 255
  return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
}

export function luminance(hex: string): number {
  return 0.2126 * channel(hex, 0) + 0.7152 * channel(hex, 1) + 0.0722 * channel(hex, 2)
}

export function contrastRatio(a: string, b: string): number {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x)
  return (hi + 0.05) / (lo + 0.05)
}
