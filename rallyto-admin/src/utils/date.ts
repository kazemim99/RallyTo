/**
 * Jalali dates. The calendar comes from the platform's own support rather than a conversion library:
 * `fa-IR-u-ca-persian` selects the Persian calendar, and fa-IR supplies Persian digits and month names (the same
 * approach as AsanRezerve's admin, `src/utils/date.ts`).
 *
 * Rallyto is an Iran-only product, so an instant is always shown on Tehran's clock whatever the browser's zone,
 * and the panel is always Jalali.
 */

import { toAsciiDigits } from './digits'

export const JALALI_LOCALE = 'fa-IR-u-ca-persian'
export const TEHRAN_TIME_ZONE = 'Asia/Tehran'

// First-strong isolate ... pop: the date keeps its own direction wherever it sits. Unisolated, the bidi algorithm
// reorders date parts against surrounding right-to-left text in tables (AsanRezerve, 2026-09-19).
const FSI = '⁨'
const PDI = '⁩'

type DateInput = string | Date | null | undefined

/** A `YYYY-MM-DD` string is a calendar day (an API `DateOnly`), not an instant: it must not shift with a zone. */
const DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/

interface Parsed {
  date: Date
  timeZone: string
}

function parse(value: DateInput): Parsed | null {
  if (!value) return null
  if (typeof value === 'string' && DATE_ONLY.test(value)) {
    const day = new Date(`${value}T00:00:00Z`)
    return Number.isNaN(day.getTime()) ? null : { date: day, timeZone: 'UTC' }
  }
  const date = value instanceof Date ? value : new Date(value)
  return Number.isNaN(date.getTime()) ? null : { date, timeZone: TEHRAN_TIME_ZONE }
}

function parts(parsed: Parsed, options: Intl.DateTimeFormatOptions): Record<string, string> {
  const result: Record<string, string> = {}
  for (const part of new Intl.DateTimeFormat(JALALI_LOCALE, { ...options, timeZone: parsed.timeZone }).formatToParts(
    parsed.date,
  )) {
    result[part.type] = part.value
  }
  return result
}

const isolate = (text: string) => `${FSI}${text}${PDI}`

/** `۱۴۰۵/۰۸/۰۱`: the Jalali calendar day, Persian digits, year first. Empty for a missing or invalid value. */
export function formatDate(value: DateInput): string {
  const parsed = parse(value)
  if (!parsed) return ''
  const p = parts(parsed, { year: 'numeric', month: '2-digit', day: '2-digit' })
  return isolate(`${p.year}/${p.month}/${p.day}`)
}

/** `۱۴۰۵/۰۸/۰۱ ۱۴:۳۰`: the Jalali day and the time on Tehran's clock. */
export function formatDateTime(value: DateInput): string {
  const parsed = parse(value)
  if (!parsed) return ''
  const p = parts(parsed, {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  })
  return isolate(`${p.year}/${p.month}/${p.day} ${p.hour}:${p.minute}`)
}

/** `۱ آبان ۱۴۰۵`: the Jalali day with the month's name. */
export function formatLongDate(value: DateInput): string {
  const parsed = parse(value)
  if (!parsed) return ''
  return isolate(
    new Intl.DateTimeFormat(JALALI_LOCALE, {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      timeZone: parsed.timeZone,
    }).format(parsed.date),
  )
}

// --- Entering a Jalali date and time --------------------------------------------------------------------------

/** A wall-clock moment on the Jalali calendar, as a person in Tehran reads it. Months are 1-based. */
export interface JalaliDateTime {
  year: number
  month: number
  day: number
  hour: number
  minute: number
}

export const JALALI_MONTH_NAMES = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
] as const

const DAY_MS = 86_400_000

// ASCII digits (`nu-latn`) so the parts parse as numbers; the year part carries no era.
const JALALI_DAY_PARTS = new Intl.DateTimeFormat('en-US-u-ca-persian-nu-latn', {
  year: 'numeric',
  month: 'numeric',
  day: 'numeric',
  timeZone: 'UTC',
})

const TEHRAN_JALALI_PARTS = new Intl.DateTimeFormat('en-US-u-ca-persian-nu-latn', {
  year: 'numeric',
  month: 'numeric',
  day: 'numeric',
  hour: 'numeric',
  minute: 'numeric',
  hourCycle: 'h23',
  timeZone: TEHRAN_TIME_ZONE,
})

const TEHRAN_GREGORIAN_PARTS = new Intl.DateTimeFormat('en-US', {
  year: 'numeric',
  month: 'numeric',
  day: 'numeric',
  hour: 'numeric',
  minute: 'numeric',
  second: 'numeric',
  hourCycle: 'h23',
  timeZone: TEHRAN_TIME_ZONE,
})

function numericParts(format: Intl.DateTimeFormat, date: Date): Record<string, number> {
  const result: Record<string, number> = {}
  for (const part of format.formatToParts(date)) {
    if (part.type !== 'literal' && part.type !== 'era') result[part.type] = Number(part.value)
  }
  return result
}

/** UTC midnight of the Gregorian day on which Jalali `year` begins (1 Farvardin falls on 19–22 March). */
function farvardinFirst(year: number): number | null {
  for (let day = 19; day <= 22; day++) {
    const candidate = Date.UTC(year + 621, 2, day)
    const p = numericParts(JALALI_DAY_PARTS, new Date(candidate))
    if (p.year === year && p.month === 1 && p.day === 1) return candidate
  }
  return null
}

/**
 * UTC midnight of the Gregorian day matching a Jalali calendar day, or null when that day does not exist
 * (30 Esfand of a common year, month 13). The platform's Persian calendar is the authority, as for display.
 */
function jalaliDayToUtcMidnight(year: number, month: number, day: number): number | null {
  if (![year, month, day].every(Number.isInteger) || month < 1 || month > 12 || day < 1 || day > 31) return null
  const start = farvardinFirst(year)
  if (start === null) return null
  const dayOfYear = (month <= 6 ? (month - 1) * 31 : 186 + (month - 7) * 30) + day - 1
  const candidate = start + dayOfYear * DAY_MS
  const p = numericParts(JALALI_DAY_PARTS, new Date(candidate))
  return p.year === year && p.month === month && p.day === day ? candidate : null
}

/** The number of days in a Jalali month: 31 for the first six, 30 for the next five, 29 or 30 for Esfand. */
export function jalaliMonthLength(year: number, month: number): number {
  if (month <= 6) return 31
  if (month <= 11) return 30
  return jalaliDayToUtcMidnight(year, 12, 30) === null ? 29 : 30
}

/** An instant as Tehran's Jalali wall clock reads it. */
export function toTehranJalali(instant: Date): JalaliDateTime {
  const p = numericParts(TEHRAN_JALALI_PARTS, instant)
  return { year: p.year!, month: p.month!, day: p.day!, hour: p.hour!, minute: p.minute! }
}

/** How far Tehran's wall clock is ahead of UTC at an instant, in milliseconds. */
function tehranOffset(instant: number): number {
  const p = numericParts(TEHRAN_GREGORIAN_PARTS, new Date(instant))
  const wall = Date.UTC(p.year!, p.month! - 1, p.day!, p.hour!, p.minute!, p.second!)
  return wall - Math.floor(instant / 1000) * 1000
}

/**
 * The instant at which Tehran's wall clock shows the given Jalali date and time, or null for a day that does not
 * exist or an hour or minute out of range. `toISOString()` of the result is what the API takes as UTC.
 */
export function tehranJalaliToUtc(value: JalaliDateTime): Date | null {
  const { hour, minute } = value
  if (!Number.isInteger(hour) || !Number.isInteger(minute) || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null
  }
  const midnight = jalaliDayToUtcMidnight(value.year, value.month, value.day)
  if (midnight === null) return null

  // The wall time read as if it were UTC, moved back by Tehran's offset; a second pass settles an offset change.
  const wall = midnight + hour * 3_600_000 + minute * 60_000
  let instant = wall - tehranOffset(wall)
  instant = wall - tehranOffset(instant)
  return new Date(instant)
}

// --- Jalali calendar days, as the API takes them --------------------------------------------------------------

/** A Jalali calendar day (no time). Months are 1-based. */
export interface JalaliDay {
  year: number
  month: number
  day: number
}

/** True when the day exists on the Jalali calendar (30 Esfand only in a leap year). */
export function isValidJalaliDay(value: JalaliDay): boolean {
  return jalaliDayToUtcMidnight(value.year, value.month, value.day) !== null
}

/**
 * `1405/08/08`: the wire format of a Jalali day (`yyyy/MM/dd`, ASCII digits), or an empty string for a day that
 * does not exist. For display, pass it through `toPersianDigits`.
 */
export function formatJalaliDay(value: JalaliDay): string {
  if (!isValidJalaliDay(value)) return ''
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${value.year}/${pad(value.month)}/${pad(value.day)}`
}

/** Reads `1405/08/08` (Persian or ASCII digits, `/` or `-`); null for anything else or a day that does not exist. */
export function parseJalaliDay(text: string | null | undefined): JalaliDay | null {
  if (!text) return null
  const ascii = toAsciiDigits(text.trim())
  const match = /^(\d{4})[/-](\d{1,2})[/-](\d{1,2})$/.exec(ascii)
  if (!match) return null
  const day = { year: Number(match[1]), month: Number(match[2]), day: Number(match[3]) }
  return isValidJalaliDay(day) ? day : null
}

/** The Jalali day on Tehran's clock at an instant (today by default), `days` later. */
export function tehranJalaliDay(days = 0, from: Date = new Date()): JalaliDay {
  const { year, month, day } = toTehranJalali(new Date(from.getTime() + days * DAY_MS))
  return { year, month, day }
}

/** Negative when `a` is before `b`, zero on the same day, positive after. */
export function compareJalaliDays(a: JalaliDay, b: JalaliDay): number {
  return a.year - b.year || a.month - b.month || a.day - b.day
}
