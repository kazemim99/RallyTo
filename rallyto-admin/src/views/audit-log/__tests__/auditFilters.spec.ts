import { describe, expect, it } from 'vitest'
import { auditActionKey, emptyAuditFilters, isKnownAuditAction, lastSevenDays, toAuditQuery, validateAuditFilters } from '../auditFilters'
import { ADMIN_ID, TARGET_ID } from '../../../api/__tests__/safetyFixtures'
import { KNOWN_AUDIT_ACTIONS } from '../../../api/safety.api'
import fa from '../../../locales/fa.json'

const filters = (overrides = {}) => ({ ...emptyAuditFilters(), ...overrides })

describe('audit log filters', () => {
  it('accepts blank filters', () => {
    expect(validateAuditFilters(emptyAuditFilters())).toEqual({})
    expect(toAuditQuery(emptyAuditFilters())).toEqual({})
  })

  it('refuses an id that is not a GUID, which the server would reject', () => {
    expect(validateAuditFilters(filters({ adminId: '0912', targetUserId: 'x' }))).toEqual({
      adminId: 'audit.errors.invalidId',
      targetUserId: 'audit.errors.invalidId',
    })
  })

  it('refuses a day that does not exist and a range that ends before it starts', () => {
    expect(validateAuditFilters(filters({ from: '1405/07/31' }))).toEqual({ from: 'audit.errors.invalidDate' })
    expect(validateAuditFilters(filters({ from: '1405/08/02', to: '1405/08/01' }))).toEqual({ to: 'audit.errors.range' })
    expect(validateAuditFilters(filters({ from: '1405/08/01', to: '1405/08/01' }))).toEqual({})
  })

  it('builds the query with ASCII Jalali days and only the filters set', () => {
    expect(
      toAuditQuery(filters({ adminId: ` ${ADMIN_ID} `, targetUserId: TARGET_ID, action: ' player.correct-gender ', from: '۱۴۰۵/۰۷/۲۵', to: '1405/8/1' })),
    ).toEqual({ adminId: ADMIN_ID, targetUserId: TARGET_ID, action: 'player.correct-gender', from: '1405/07/25', to: '1405/08/01' })
  })

  it('takes the last seven Tehran days, today included', () => {
    expect(lastSevenDays(new Date('2026-10-23T08:00:00Z'))).toEqual({ from: '1405/07/25', to: '1405/08/01' })
  })

  it('names a known action’s i18n key, and knows which actions are known', () => {
    expect(auditActionKey('moderation.hide-post')).toBe('audit.actionNames.moderation_hide_post')
    expect(auditActionKey('venue-candidates.bulk-approve')).toBe('audit.actionNames.venue_candidates_bulk_approve')
    expect(isKnownAuditAction('account.ban')).toBe(true)
    expect(isKnownAuditAction('something.new')).toBe(false)
  })

  it('has a Persian name for every known action', () => {
    const names = fa.audit.actionNames as Record<string, string>
    for (const action of KNOWN_AUDIT_ACTIONS) expect(names[auditActionKey(action).split('.').pop()!]).toBeTruthy()
  })
})
