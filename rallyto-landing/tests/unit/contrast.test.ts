import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { COLORS, TEXT_PAIRS, UI_PAIRS, contrastRatio } from '../../src/styles/tokens'

// WCAG 2.2 AA: text ≥ 4.5:1, controls and meaningful graphics (court lines, focus rings) ≥ 3:1.

describe('colour tokens', () => {
  it('computes contrast the WCAG way', () => {
    expect(contrastRatio('#000000', '#FFFFFF')).toBeCloseTo(21, 0)
    expect(contrastRatio('#146B52', '#FFFFFF')).toBeCloseTo(6.45, 1)
  })

  it.each(TEXT_PAIRS)('text %s on %s reaches 4.5:1', (fg, bg) => {
    expect(contrastRatio(COLORS[fg], COLORS[bg])).toBeGreaterThanOrEqual(4.5)
  })

  it.each(UI_PAIRS)('graphic %s on %s reaches 3:1', (fg, bg) => {
    expect(contrastRatio(COLORS[fg], COLORS[bg])).toBeGreaterThanOrEqual(3)
  })

  it('the stylesheet declares exactly these values', () => {
    const css = readFileSync(new URL('../../src/styles/global.css', import.meta.url), 'utf8').toLowerCase()
    for (const [name, value] of Object.entries(COLORS)) {
      const variable = `--c-${name.replace(/[A-Z]/g, (m) => `-${m.toLowerCase()}`)}`
      expect(css, variable).toContain(`${variable}: ${value.toLowerCase()};`)
    }
  })

  it('never sets white text on clay (2.9:1)', () => {
    expect(TEXT_PAIRS).not.toContainEqual(['surface', 'clay'])
  })
})
