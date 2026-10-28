import mark from '../../../branding/mark.json' with { type: 'json' }

/**
 * The rally loop, computed from branding/mark.json exactly as branding/build_brand.py draws it, so the inline marks on
 * the site and every generated icon are the same drawing (tests/unit/brand.test.ts compares against the SVG files).
 * Two tapered arcs close a loop, each the path of a ball from one player to the other, ending in the partner's ball.
 */
export const MARK = mark

const f = (n: number) => n.toFixed(2).replace(/\.?0+$/, '')

function point(radius: number, degrees: number): [number, number] {
  const [cx, cy] = mark.center
  const a = (degrees * Math.PI) / 180
  return [cx + radius * Math.cos(a), cy + radius * Math.sin(a)]
}

/** The tapered arc turned by `rotation` degrees: a point at its tail, full width at a round head under the ball. */
export function trailPath(rotation: number): string {
  const { fromDeg, toDeg, width, taper, samples } = mark.trail
  const r = mark.ringRadius
  const outer: [number, number][] = []
  const inner: [number, number][] = []
  for (let k = 0; k <= samples; k++) {
    const t = k / samples
    const angle = fromDeg + rotation + (toDeg - fromDeg) * t
    const half = (width / 2) * t ** taper
    outer.push(point(r + half, angle))
    inner.push(point(r - half, angle))
  }
  const head = width / 2
  const end = inner[inner.length - 1]
  return (
    'M' +
    outer.map(([x, y]) => `${f(x)} ${f(y)}`).join(' L') +
    ` A${f(head)} ${f(head)} 0 0 1 ${f(end[0])} ${f(end[1])}` +
    ' L' +
    [...inner]
      .reverse()
      .map(([x, y]) => `${f(x)} ${f(y)}`)
      .join(' L') +
    'Z'
  )
}

/** The ball at the head of the arc turned by `rotation` degrees. */
export function ball(rotation: number): { cx: string; cy: string; r: string } {
  const [x, y] = point(mark.ringRadius, mark.ball.angleDeg + rotation)
  return { cx: f(x), cy: f(y), r: f(mark.ball.radius) }
}

export type MarkTone = 'reversed' | 'color'

/** Trail A, ball A, trail B, ball B colours for a tone (reversed: on green; color: on light backgrounds). */
export function toneColors(tone: MarkTone): [string, string, string, string] {
  const c = mark.colors
  return tone === 'reversed' ? [c.white, c.ball, c.ball, c.white] : [c.green, c.clay, c.clay, c.green]
}
