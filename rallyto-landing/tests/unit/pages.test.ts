import { describe, expect, it } from 'vitest'
import { HOME_FAQ } from '../../src/data/faq'
import { indexablePages } from '../../src/data/pages'
import { PRIVACY, TERMS } from '../../src/data/policies'
import { SPORTS } from '../../src/data/sports'

// Metadata rules for every indexable page, and the Persian text rules for every piece of copy.
const pages = indexablePages()
const allCopy = JSON.stringify({ SPORTS, HOME_FAQ, PRIVACY, TERMS, pages })

describe('page metadata', () => {
  it('lists the home page, the four sports and the two policies', () => {
    expect(pages.map((p) => p.path)).toEqual(['/', '/tennis', '/padel', '/badminton', '/squash', '/privacy', '/terms'])
  })

  it.each(pages.map((p) => [p.path, p] as const))('%s has a title ≤ 60 and a description of 70–160 characters', (_, p) => {
    expect([...p.title].length).toBeLessThanOrEqual(60)
    expect([...p.description].length).toBeGreaterThanOrEqual(70)
    expect([...p.description].length).toBeLessThanOrEqual(160)
  })

  it('never repeats a title or a description', () => {
    expect(new Set(pages.map((p) => p.title)).size).toBe(pages.length)
    expect(new Set(pages.map((p) => p.description)).size).toBe(pages.length)
  })

  it('names the brand in every title', () => {
    for (const p of pages) expect(p.title, p.path).toContain('رالیتو')
  })
})

describe('Persian copy', () => {
  it('uses Persian ی and ک, never Arabic ي and ك', () => {
    expect(allCopy.match(/[يك]/g) ?? []).toEqual([])
  })

  it('never says «پارتنر یابی» on its own (it reads as dating)', () => {
    expect(allCopy).not.toMatch(/پارتنر ?یابی(?! (تنیس|پدل|بدمینتون|اسکواش))/)
  })

  it('states no price and does not call the app free', () => {
    expect(allCopy).not.toMatch(/رایگان|تومان|ریال|قیمت/)
  })
})

describe('sports', () => {
  it('has the four sports, each with levels, formats and questions', () => {
    expect(SPORTS.map((s) => s.slug)).toEqual(['tennis', 'padel', 'badminton', 'squash'])
    for (const s of SPORTS) {
      expect(s.levels.length, s.slug).toBeGreaterThan(1)
      expect(s.formats.length, s.slug).toBeGreaterThan(0)
      expect(s.faq.length, s.slug).toBeGreaterThanOrEqual(3)
    }
  })
})
