import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { STATS_ENDPOINT, statsApi } from '../stats.api'
import { getApiErrorMessage } from '../../utils/axios'
import { tokenStorage } from '../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens } from '../../utils/__tests__/fakeApi'
import { usageStats } from './statsFixtures'

let api: ReturnType<typeof installFakeApi> | undefined

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Admin']), 'admin@rallyto.ir')
})
afterEach(() => api?.restore())

describe('admin usage stats API contract', () => {
  it('reads GET /api/v1/admin/stats with no dates for the server’s default period, as the admin', async () => {
    const body = usageStats()
    api = installFakeApi(() => ({ status: 200, body: envelope(body) }))

    const result = await statsApi.usage()

    expect(STATS_ENDPOINT).toBe('/api/v1/admin/stats')
    expect(api.requests[0]).toMatchObject({ method: 'GET', url: STATS_ENDPOINT, authorization: 'Bearer access-1', params: {} })
    expect(result).toEqual(body)
  })

  it('sends the Jalali days it is given, and leaves blank ones out', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope(usageStats({ completionRate: null })) }))

    await statsApi.usage({ from: '1405/08/01', to: '1405/08/02' })
    await statsApi.usage({ from: ' ', to: '1405/08/02' })

    expect(api.requests[0]!.params).toEqual({ from: '1405/08/01', to: '1405/08/02' })
    expect(api.requests[1]!.params).toEqual({ to: '1405/08/02' })
  })

  it('fails with the server’s Persian message', async () => {
    api = installFakeApi(() => ({ status: 400, body: errorEnvelope(400, 'تاریخ شروع بعد از تاریخ پایان است.', 'INVALID_DATE') }))

    const failure = await statsApi.usage({ from: '1405/08/02', to: '1405/08/01' }).catch((error: unknown) => error)

    expect(getApiErrorMessage(failure)).toBe('تاریخ شروع بعد از تاریخ پایان است.')
  })
})
