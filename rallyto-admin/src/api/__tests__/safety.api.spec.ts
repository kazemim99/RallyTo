import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import {
  AUDIT_ENDPOINT,
  DISPUTED_MATCHES_ENDPOINT,
  MODERATION_ACTIONS_ENDPOINT,
  REPORTS_ENDPOINT,
  safetyApi,
} from '../safety.api'
import { getApiErrorMessage } from '../../utils/axios'
import { tokenStorage } from '../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens } from '../../utils/__tests__/fakeApi'
import { ADMIN_ID, MATCH_ID, MESSAGE_ID, TARGET_ID, auditEntry, disputedMatch, moderationAction, reportGroup, targetDetail } from './safetyFixtures'

let api: ReturnType<typeof installFakeApi> | undefined

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Admin']), 'admin@rallyto.ir')
})
afterEach(() => api?.restore())

describe('admin safety API contract', () => {
  it('reads the queue at GET /api/v1/admin/reports, as the admin, in the server’s order', async () => {
    const groups = [reportGroup({ targetUserId: 'u-2', highPriority: true }), reportGroup()]
    api = installFakeApi(() => ({ status: 200, body: envelope(groups) }))

    const result = await safetyApi.queue()

    expect(REPORTS_ENDPOINT).toBe('/api/v1/admin/reports')
    expect(api.requests).toEqual([
      { method: 'GET', url: '/api/v1/admin/reports', body: undefined, authorization: 'Bearer access-1' },
    ])
    expect(result).toEqual(groups)
  })

  it('reads a target at GET …/reports/targets/{userId}', async () => {
    const detail = targetDetail()
    api = installFakeApi(() => ({ status: 200, body: envelope(detail) }))

    const result = await safetyApi.target(TARGET_ID)

    expect(api.requests[0]!.url).toBe(`/api/v1/admin/reports/targets/${TARGET_ID}`)
    expect(result).toEqual(detail)
  })

  it('dismisses at POST …/reports/{id}/dismiss with { reason }', async () => {
    api = installFakeApi(() => ({ status: 204 }))

    await safetyApi.dismiss('r-1', 'گزارش بی‌پایه')

    expect(api.requests[0]).toMatchObject({
      method: 'POST',
      url: '/api/v1/admin/reports/r-1/dismiss',
      body: { reason: 'گزارش بی‌پایه' },
      authorization: 'Bearer access-1',
    })
  })

  it('acts at POST /api/v1/admin/moderation/actions, sending only the members the action needs', async () => {
    const recorded = moderationAction({ action: 'Suspend', subject: '1405/08/08' })
    api = installFakeApi(() => ({ status: 200, body: envelope(recorded) }))

    const result = await safetyApi.act({
      targetUserId: TARGET_ID,
      action: 'Suspend',
      reason: 'harassment in chat',
      reportId: 'r-1',
      until: '1405/08/08',
      matchId: undefined,
      warningText: '',
    })

    expect(MODERATION_ACTIONS_ENDPOINT).toBe('/api/v1/admin/moderation/actions')
    expect(api.requests[0]).toMatchObject({ method: 'POST', url: MODERATION_ACTIONS_ENDPOINT })
    expect(api.requests[0]!.body).toEqual({
      targetUserId: TARGET_ID,
      action: 'Suspend',
      reason: 'harassment in chat',
      reportId: 'r-1',
      until: '1405/08/08',
    })
    expect(result).toEqual(recorded)
  })

  it.each([
    [{ action: 'Warn', warningText: 'اخطار' }, { warningText: 'اخطار' }],
    [{ action: 'HidePost', matchId: MATCH_ID }, { matchId: MATCH_ID }],
    [{ action: 'DeleteMessage', messageId: MESSAGE_ID }, { messageId: MESSAGE_ID }],
    [{ action: 'CorrectGender', gender: 'Female' }, { gender: 'Female' }],
  ] as const)('sends %j with its own member', async (extra, expected) => {
    api = installFakeApi(() => ({ status: 200, body: envelope(moderationAction()) }))

    await safetyApi.act({ targetUserId: TARGET_ID, reason: 'دلیل', ...extra })

    expect(api.requests[0]!.body).toEqual({ targetUserId: TARGET_ID, reason: 'دلیل', ...extra, ...expected })
  })

  it('reads the audit log with only the filters set, dates as Jalali ASCII', async () => {
    const page = { items: [auditEntry()], page: 2, pageSize: 50, totalCount: 51 }
    api = installFakeApi(() => ({ status: 200, body: envelope(page) }))

    const result = await safetyApi.audit({
      adminId: ` ${ADMIN_ID} `,
      targetUserId: '',
      action: 'player.correct-gender',
      from: '1405/07/25',
      to: '1405/08/01',
      page: 2,
      pageSize: 50,
    })

    expect(AUDIT_ENDPOINT).toBe('/api/v1/admin/audit')
    expect(api.requests[0]).toMatchObject({ method: 'GET', url: AUDIT_ENDPOINT })
    expect(api.requests[0]!.params).toEqual({
      adminId: ADMIN_ID,
      action: 'player.correct-gender',
      from: '1405/07/25',
      to: '1405/08/01',
      page: 2,
      pageSize: 50,
    })
    expect(result).toEqual(page)
  })

  it('reads disputed matches at GET /api/v1/admin/matches/disputed', async () => {
    const list = [disputedMatch()]
    api = installFakeApi(() => ({ status: 200, body: envelope(list) }))

    const result = await safetyApi.disputedMatches()

    expect(DISPUTED_MATCHES_ENDPOINT).toBe('/api/v1/admin/matches/disputed')
    expect(api.requests[0]).toMatchObject({ method: 'GET', url: DISPUTED_MATCHES_ENDPOINT })
    expect(result).toEqual(list)
  })

  it('escapes ids in the path', async () => {
    api = installFakeApi(() => ({ status: 204 }))

    await safetyApi.dismiss('a/b', 'x')

    expect(api.requests[0]!.url).toBe('/api/v1/admin/reports/a%2Fb/dismiss')
  })

  it('fails with the server’s Persian message on a refused action', async () => {
    api = installFakeApi(() => ({ status: 400, body: errorEnvelope(400, 'تاریخ پایان تعلیق معتبر نیست.', 'INVALID_DATE') }))

    const failure = await safetyApi
      .act({ targetUserId: TARGET_ID, action: 'Suspend', reason: 'x', until: '1405/13/01' })
      .catch((error: unknown) => error)

    expect(getApiErrorMessage(failure)).toBe('تاریخ پایان تعلیق معتبر نیست.')
  })
})
