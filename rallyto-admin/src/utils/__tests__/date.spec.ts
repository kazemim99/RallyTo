import { describe, expect, it } from 'vitest'
import {
  compareJalaliDays,
  formatDate,
  formatJalaliDay,
  isValidJalaliDay,
  parseJalaliDay,
  tehranJalaliDay,
  formatDateTime,
  formatLongDate,
  jalaliMonthLength,
  tehranJalaliToUtc,
  toTehranJalali,
} from '../date'
import { toAsciiDigits } from '../digits'

const FSI = '⁨'
const PDI = '⁩'
const plain = (text: string) => toAsciiDigits(text.replace(/[⁨⁩]/g, ''))

describe('Jalali date formatting', () => {
  it('renders 2026-10-23 as 1405/08/01', () => {
    expect(plain(formatDate('2026-10-23'))).toBe('1405/08/01')
  })

  it('renders it in Persian digits, isolated so it keeps its direction inside right-to-left text', () => {
    expect(formatDate('2026-10-23')).toBe(`${FSI}۱۴۰۵/۰۸/۰۱${PDI}`)
  })

  it('treats a YYYY-MM-DD value as a calendar day, which no time zone shifts', () => {
    expect(plain(formatDate('2026-10-22'))).toBe('1405/07/30')
    expect(plain(formatDate('2026-03-21'))).toBe('1405/01/01')
  })

  it('shows an instant on Tehran’s calendar, whatever the browser’s zone', () => {
    // 21:00 UTC on 22 October is 00:30 on 23 October in Tehran (UTC+03:30): already 1 Aban.
    expect(plain(formatDate('2026-10-22T21:00:00Z'))).toBe('1405/08/01')
    expect(plain(formatDate(new Date('2026-10-23T08:00:00Z')))).toBe('1405/08/01')
  })

  it('includes the time on Tehran’s clock, on a 24-hour clock', () => {
    expect(plain(formatDateTime('2026-10-23T10:30:00Z'))).toBe('1405/08/01 14:00')
    expect(plain(formatDateTime('2026-10-22T21:00:00Z'))).toBe('1405/08/01 00:30')
  })

  it('names the month in the long form', () => {
    expect(formatLongDate('2026-10-23')).toBe(`${FSI}۱ آبان ۱۴۰۵${PDI}`)
  })

  it('renders nothing for a missing or unparseable value instead of "Invalid Date"', () => {
    for (const format of [formatDate, formatDateTime, formatLongDate]) {
      expect(format(undefined)).toBe('')
      expect(format(null)).toBe('')
      expect(format('')).toBe('')
      expect(format('not-a-date')).toBe('')
      expect(format('2026-13-45')).toBe('')
    }
  })
})

describe('entering a Jalali date and time on Tehran’s clock', () => {
  it('turns 1405/08/10 14:30 in Tehran into 11:00 UTC on 1 November 2026', () => {
    expect(tehranJalaliToUtc({ year: 1405, month: 8, day: 10, hour: 14, minute: 30 })!.toISOString()).toBe(
      '2026-11-01T11:00:00.000Z',
    )
  })

  it('crosses the UTC day boundary: 00:30 on 1 Aban is 21:00 UTC the day before', () => {
    expect(tehranJalaliToUtc({ year: 1405, month: 8, day: 1, hour: 0, minute: 30 })!.toISOString()).toBe(
      '2026-10-22T21:00:00.000Z',
    )
  })

  it('places 1 Farvardin on the Gregorian day the calendar does', () => {
    expect(tehranJalaliToUtc({ year: 1405, month: 1, day: 1, hour: 12, minute: 0 })!.toISOString()).toBe(
      '2026-03-21T08:30:00.000Z',
    )
  })

  it('round-trips with toTehranJalali', () => {
    const instant = new Date('2027-02-14T17:45:00Z')
    expect(tehranJalaliToUtc(toTehranJalali(instant))!.getTime()).toBe(instant.getTime())
    expect(toTehranJalali(new Date('2026-10-23T10:30:00Z'))).toEqual({ year: 1405, month: 8, day: 1, hour: 14, minute: 0 })
  })

  it('knows the month lengths, Esfand included', () => {
    expect(jalaliMonthLength(1405, 1)).toBe(31)
    expect(jalaliMonthLength(1405, 7)).toBe(30)
    expect(jalaliMonthLength(1403, 12)).toBe(30) // 1403 is a leap year: 30 Esfand was 20 March 2025
    expect(jalaliMonthLength(1404, 12)).toBe(29)
  })

  it('refuses a day or time that does not exist', () => {
    expect(tehranJalaliToUtc({ year: 1404, month: 12, day: 30, hour: 10, minute: 0 })).toBeNull()
    expect(tehranJalaliToUtc({ year: 1405, month: 7, day: 31, hour: 10, minute: 0 })).toBeNull()
    expect(tehranJalaliToUtc({ year: 1405, month: 13, day: 1, hour: 10, minute: 0 })).toBeNull()
    expect(tehranJalaliToUtc({ year: 1405, month: 1, day: 1, hour: 24, minute: 0 })).toBeNull()
  })
})

describe('Jalali days on the wire', () => {
  it('writes a day as yyyy/MM/dd with ASCII digits, as the API reads it', () => {
    expect(formatJalaliDay({ year: 1405, month: 8, day: 8 })).toBe('1405/08/08')
    expect(formatJalaliDay({ year: 1405, month: 12, day: 30 })).toBe('') // 1405 is a common year
  })

  it('reads Persian or ASCII digits, and refuses a day that does not exist', () => {
    expect(parseJalaliDay('۱۴۰۵/۰۸/۰۸')).toEqual({ year: 1405, month: 8, day: 8 })
    expect(parseJalaliDay('1405-8-1')).toEqual({ year: 1405, month: 8, day: 1 })
    expect(parseJalaliDay('1405/07/31')).toBeNull()
    expect(parseJalaliDay('1405/13/01')).toBeNull()
    expect(parseJalaliDay('8/8/1405')).toBeNull()
    expect(parseJalaliDay('')).toBeNull()
  })

  it('knows the leap Esfand', () => {
    expect(isValidJalaliDay({ year: 1403, month: 12, day: 30 })).toBe(true)
    expect(isValidJalaliDay({ year: 1405, month: 12, day: 30 })).toBe(false)
  })

  it('takes today from Tehran’s clock, not UTC’s', () => {
    // 21:00 UTC on 22 October is 00:30 on 1 Aban in Tehran.
    expect(tehranJalaliDay(0, new Date('2026-10-22T21:00:00Z'))).toEqual({ year: 1405, month: 8, day: 1 })
    expect(tehranJalaliDay(7, new Date('2026-10-22T21:00:00Z'))).toEqual({ year: 1405, month: 8, day: 8 })
  })

  it('orders days', () => {
    expect(compareJalaliDays({ year: 1405, month: 8, day: 1 }, { year: 1405, month: 7, day: 30 })).toBeGreaterThan(0)
    expect(compareJalaliDays({ year: 1405, month: 8, day: 1 }, { year: 1405, month: 8, day: 1 })).toBe(0)
    expect(compareJalaliDays({ year: 1404, month: 12, day: 29 }, { year: 1405, month: 1, day: 1 })).toBeLessThan(0)
  })
})
