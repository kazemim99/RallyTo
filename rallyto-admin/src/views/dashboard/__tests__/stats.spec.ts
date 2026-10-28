import { describe, expect, it } from 'vitest'
import { formatCount, formatRate, lastDays, toStatsQuery, validateStatsRange } from '../stats'

describe('dashboard figures', () => {
  it('shows the completion rate as a Persian percentage, and "—" when nothing was resolved', () => {
    expect(formatRate(0.667)).toBe('۶۶٫۷٪')
    expect(formatRate(1)).toBe('۱۰۰٪')
    expect(formatRate(0)).toBe('۰٪')
    expect(formatRate(0.5)).toBe('۵۰٪')
    expect(formatRate(null)).toBe('—')
  })

  it('shows counts in Persian digits with the Persian thousands separator', () => {
    expect(formatCount(1234567)).toBe('۱٬۲۳۴٬۵۶۷')
    expect(formatCount(0)).toBe('۰')
    expect(formatCount(999)).toBe('۹۹۹')
  })
})

describe('dashboard period', () => {
  it('allows either end to be blank (the server defaults), but not an end before the start', () => {
    expect(validateStatsRange({ from: '', to: '' })).toEqual({})
    expect(validateStatsRange({ from: '1405/08/01', to: '' })).toEqual({})
    expect(validateStatsRange({ from: '1405/08/02', to: '1405/08/01' })).toEqual({ to: 'dashboard.errors.range' })
    expect(validateStatsRange({ from: '1405/12/30', to: '' })).toEqual({ from: 'dashboard.errors.invalidDate' })
  })

  it('builds the query from the days set', () => {
    expect(toStatsQuery({ from: '', to: '' })).toEqual({})
    expect(toStatsQuery({ from: '1405/8/1', to: '۱۴۰۵/۰۸/۰۲' })).toEqual({ from: '1405/08/01', to: '1405/08/02' })
  })

  it('takes the last N Tehran days, today included, as the server’s 30-day default does', () => {
    const now = new Date('2026-10-23T08:00:00Z') // 1405/08/01
    expect(lastDays(30, now)).toEqual({ from: '1405/07/02', to: '1405/08/01' })
    expect(lastDays(7, now)).toEqual({ from: '1405/07/25', to: '1405/08/01' })
  })
})
