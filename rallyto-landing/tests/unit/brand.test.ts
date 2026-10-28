import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { MARK, ball, trailPath } from '../../src/lib/brand'

// The site draws the logo inline from branding/mark.json; every app icon is rendered from the SVGs that
// branding/build_brand.py writes from the same file. Both must be the same drawing.
const svg = (name: string) => readFileSync(new URL(`../../../branding/${name}`, import.meta.url), 'utf8')

describe('the rally loop', () => {
  it('draws the same two trails as the brand SVG', () => {
    const paths = [...svg('symbol-reversed.svg').matchAll(/<path d="([^"]+)"/g)].map((m) => m[1])
    expect(paths).toEqual([trailPath(0), trailPath(180)])
  })

  it('puts the two balls where the brand SVG has them', () => {
    const circles = [...svg('symbol-reversed.svg').matchAll(/<circle cx="([^"]+)" cy="([^"]+)" r="([^"]+)"/g)].map((m) => ({
      cx: m[1],
      cy: m[2],
      r: m[3],
    }))
    expect(circles).toEqual([ball(0), ball(180)])
  })

  it('turns the second ball and trail half a turn from the first', () => {
    const a = ball(0)
    const b = ball(180)
    const [cx, cy] = MARK.center
    expect(Number(a.cx) + Number(b.cx)).toBeCloseTo(2 * cx, 1)
    expect(Number(a.cy) + Number(b.cy)).toBeCloseTo(2 * cy, 1)
  })
})
