import { KNOWN_AUDIT_ACTIONS, type AuditQuery } from '../../api/safety.api'
import { compareJalaliDays, formatJalaliDay, parseJalaliDay, tehranJalaliDay } from '../../utils/date'
import { isGuid, normaliseId } from '../reports/moderation'

/** The audit log's filters as the admin sets them. Dates are Jalali `yyyy/MM/dd`, empty when not set. */
export interface AuditFilters {
  adminId: string
  targetUserId: string
  action: string
  from: string
  to: string
}

export type AuditFilterErrors = Partial<Record<keyof AuditFilters, string>>

export const emptyAuditFilters = (): AuditFilters => ({ adminId: '', targetUserId: '', action: '', from: '', to: '' })

/**
 * What is wrong with the filters, as i18n keys: an id that is not a GUID (the server would refuse it), a day that
 * does not exist, or a range that ends before it starts. Blank filters are fine.
 */
export function validateAuditFilters(filters: AuditFilters): AuditFilterErrors {
  const errors: AuditFilterErrors = {}
  for (const key of ['adminId', 'targetUserId'] as const) {
    if (filters[key].trim() && !isGuid(filters[key])) errors[key] = 'audit.errors.invalidId'
  }
  const from = filters.from.trim() ? parseJalaliDay(filters.from) : null
  const to = filters.to.trim() ? parseJalaliDay(filters.to) : null
  if (filters.from.trim() && !from) errors.from = 'audit.errors.invalidDate'
  if (filters.to.trim() && !to) errors.to = 'audit.errors.invalidDate'
  if (from && to && compareJalaliDays(from, to) > 0) errors.to = 'audit.errors.range'
  return errors
}

/** The query for valid filters: ids normalised, dates as ASCII `yyyy/MM/dd`, blanks left out. */
export function toAuditQuery(filters: AuditFilters): AuditQuery {
  const query: AuditQuery = {}
  const adminId = normaliseId(filters.adminId)
  const targetUserId = normaliseId(filters.targetUserId)
  const action = filters.action.trim()
  const from = parseJalaliDay(filters.from)
  const to = parseJalaliDay(filters.to)
  if (adminId) query.adminId = adminId
  if (targetUserId) query.targetUserId = targetUserId
  if (action) query.action = action
  if (from) query.from = formatJalaliDay(from)
  if (to) query.to = formatJalaliDay(to)
  return query
}

/** The last seven Tehran days, today included. */
export function lastSevenDays(now: Date = new Date()): Pick<AuditFilters, 'from' | 'to'> {
  return { from: formatJalaliDay(tehranJalaliDay(-6, now)), to: formatJalaliDay(tehranJalaliDay(0, now)) }
}

/** The i18n key of an action's Persian name (`moderation.hide-post` → `audit.actionNames.moderation_hide_post`). */
export const auditActionKey = (action: string) => `audit.actionNames.${action.replace(/[.-]/g, '_')}`

export const isKnownAuditAction = (action: string) => (KNOWN_AUDIT_ACTIONS as readonly string[]).includes(action)
