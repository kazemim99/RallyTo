import { compareJalaliDays, formatJalaliDay, parseJalaliDay, tehranJalaliDay } from '../../utils/date'
import { toPersianDigits } from '../../utils/digits'
import type { UsageStatsQuery } from '../../api/stats.api'

/** The dashboard's period as the admin picks it: Jalali `yyyy/MM/dd` days, empty for the server's default. */
export interface StatsRange {
  from: string
  to: string
}

/** What is wrong with the period, as i18n keys. Both ends are optional; together, the end may not precede the start. */
export function validateStatsRange(range: StatsRange): Partial<Record<keyof StatsRange, string>> {
  const errors: Partial<Record<keyof StatsRange, string>> = {}
  const from = range.from ? parseJalaliDay(range.from) : null
  const to = range.to ? parseJalaliDay(range.to) : null
  if (range.from && !from) errors.from = 'dashboard.errors.invalidDate'
  if (range.to && !to) errors.to = 'dashboard.errors.invalidDate'
  if (from && to && compareJalaliDays(from, to) > 0) errors.to = 'dashboard.errors.range'
  return errors
}

export function toStatsQuery(range: StatsRange): UsageStatsQuery {
  const query: UsageStatsQuery = {}
  const from = parseJalaliDay(range.from)
  const to = parseJalaliDay(range.to)
  if (from) query.from = formatJalaliDay(from)
  if (to) query.to = formatJalaliDay(to)
  return query
}

/** The last `days` Tehran days, today included (the server's default is 30). */
export function lastDays(days: number, now: Date = new Date()): StatsRange {
  return { from: formatJalaliDay(tehranJalaliDay(1 - days, now)), to: formatJalaliDay(tehranJalaliDay(0, now)) }
}

/** `1234` → `۱٬۲۳۴`: Persian digits with the Persian thousands separator. */
export function formatCount(value: number | null | undefined): string {
  if (value === null || value === undefined || !Number.isFinite(value)) return '—'
  return toPersianDigits(String(Math.round(value)).replace(/\B(?=(\d{3})+(?!\d))/g, '٬'))
}

/** `0.667` → `۶۶٫۷٪`, to one decimal; `—` when there is no rate (nothing was resolved). */
export function formatRate(rate: number | null | undefined): string {
  if (rate === null || rate === undefined || !Number.isFinite(rate)) return '—'
  const percent = Math.round(rate * 1000) / 10
  return `${toPersianDigits(String(percent)).replace('.', '٫')}٪`
}
