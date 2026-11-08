import { describe, expect, it } from 'vitest'
import { SITE } from '../../src/config/site'
import { HOME_FAQ } from '../../src/data/faq'
import { GUIDES } from '../../src/data/guides'
import { clubPages, indexablePages } from '../../src/data/pages'
import { PRIVACY, TERMS } from '../../src/data/policies'
import { SPORTS } from '../../src/data/sports'

// Metadata rules for every indexable page, and the Persian text rules for every piece of copy.
const pages = indexablePages()
const allCopy = JSON.stringify({ SPORTS, HOME_FAQ, PRIVACY, TERMS, GUIDES, pages })

describe('page metadata', () => {
  it('lists the home page, the guides, the policies and the contact page, and the sports only once published', () => {
    const sports = SITE.sportPagesPublished ? ['/tennis', '/padel', '/badminton', '/squash'] : []
    const guides = ['/guides', ...GUIDES.map((g) => `/guides/${g.slug}`)]
    const clubs = clubPages().filter((p) => p.indexable).map((p) => p.path)
    expect(pages.map((p) => p.path)).toEqual(['/', ...sports, ...guides, ...clubs, '/privacy', '/terms', '/contact'])
  })

  it('has a guide on each sport’s rules, and one comparing padel with tennis', () => {
    for (const sport of SPORTS) expect(GUIDES.some((g) => g.sports.length === 1 && g.sports[0] === sport.slug), sport.slug).toBe(true)
    expect(GUIDES.find((g) => g.slug === 'padel-vs-tennis')!.sports).toEqual(['padel', 'tennis'])
  })

  // Google Trends, Iran, 2026-11-07: the most searched phrases with «زمین تنیس» are its dimensions and its kinds, and
  // «پدل چیست» rises with «زمین پدل چیست» and «تنیس پدل چیست».
  it('has a guide on the tennis court, its dimensions and its kinds, with a drawing of the court', () => {
    const court = GUIDES.find((g) => g.slug === 'tennis-court')!
    expect(court.sports).toEqual(['tennis'])
    expect(court.title).toContain('ابعاد')
    expect(court.title).toContain('زمین تنیس')
    expect(court.figure?.src).toBe('/guides/tennis-court/dimensions.png')
    const text = JSON.stringify(court)
    for (const fact of ['۲۳٫۷۷', '۸٫۲۳', '۱۰٫۹۷', '۶٫۴۰', 'خاکی', 'چمن', 'هارد']) expect(text, fact).toContain(fact)
  })

  it('answers «پدل چیست» with the padel court, and the name «پدل تنیس» people also search', () => {
    const padel = GUIDES.find((g) => g.slug === 'padel')!
    expect(padel.title.startsWith('پدل چیست')).toBe(true)
    expect(padel.title).toContain('زمین')
    expect(padel.lead).toContain('پدل تنیس')
    expect(padel.sections.some((s) => s.heading.includes('زمین پدل') && s.figure?.src === '/guides/padel/court.png')).toBe(true)
  })

  it('publishes the sport pages now that the venue catalog has clubs (main change task 11.1)', () => {
    expect(SITE.sportPagesPublished).toBe(true)
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

  it('states no price amount', () => {
    expect(allCopy).not.toMatch(/تومان|ریال|قیمت/)
  })

  it('says the app is free, in the questions and in the terms', () => {
    expect(HOME_FAQ.some((f) => f.q.includes('رایگان') && f.a.startsWith('بله'))).toBe(true)
    expect(JSON.stringify(TERMS)).toContain('اپ رالیتو رایگان است')
  })
})

describe('sports', () => {
  // Google Trends, Iran, 2026-11-07: «پارتنر تنیس» and «هم‌بازی …» are barely searched; «زمین تنیس» is, and a sport page
  // lists its sport's clubs city by city. No city in the title: «زمین تنیس تهران» is the Tehran tennis list's phrase.
  it('names the sport’s courts first in each sport page title, and the partner after them', () => {
    for (const s of SPORTS) {
      expect(s.title.startsWith(`زمین ${s.name} و `), s.title).toBe(true)
      expect(s.title).not.toContain('تهران')
      expect(s.description, s.slug).toContain(`${s.name} شهرت را`)
    }
    expect(SPORTS[0].title).toContain('پارتنر تنیس')
  })

  it('has the four sports, each with levels, formats and questions', () => {
    expect(SPORTS.map((s) => s.slug)).toEqual(['tennis', 'padel', 'badminton', 'squash'])
    for (const s of SPORTS) {
      expect(s.levels.length, s.slug).toBeGreaterThan(1)
      expect(s.formats.length, s.slug).toBeGreaterThan(0)
      expect(s.faq.length, s.slug).toBeGreaterThanOrEqual(3)
    }
  })
})

describe('retention (owner decision: chats and reports, one month at most)', () => {
  const privacy = JSON.stringify(PRIVACY)

  it('says so for chats and for reports, and in the summary', () => {
    expect(SITE.retention).toBe('یک ماه')
    expect(privacy).toContain('پیام‌های گفتگوها، از جمله درخواست‌های پیام، حداکثر یک ماه نگه داشته می‌شوند')
    expect(privacy).toContain('حداکثر یک ماه برای بررسی نگه داشته می‌شوند')
    const summary = PRIVACY.sections.find((s) => s.heading === 'مدت نگهداری')!
    expect(summary.bullets).toEqual(expect.arrayContaining(['پیام‌های گفتگو و درخواست‌های پیام: حداکثر یک ماه']))
  })

  it('never says chats or reports are kept indefinitely', () => {
    expect(allCopy).not.toContain('به‌طور خودکار پاک نمی‌کند')
    expect(allCopy).not.toMatch(/گزارش‌ها[^.]*پاک نمی‌شوند/)
  })
})

describe('responsible person', () => {
  it('names them with their location and phone in both policies', () => {
    for (const policy of [PRIVACY, TERMS]) {
      const text = JSON.stringify(policy)
      expect(text).toContain(SITE.responsible.name)
      expect(text).toContain(SITE.responsible.location)
      expect(text).toContain(SITE.responsible.phone)
    }
  })

  it('states no company name, registration number or trust seal', () => {
    expect(allCopy).not.toMatch(/شرکت|شماره‌ی ثبت|شناسه‌ی ملی|اینماد/)
  })
})
