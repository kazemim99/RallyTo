import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { USERS_ENDPOINT, usersApi } from '../users.api'
import { getApiErrorMessage } from '../../utils/axios'
import { tokenStorage } from '../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens } from '../../utils/__tests__/fakeApi'
import { account, page } from './userFixtures'

let api: ReturnType<typeof installFakeApi> | undefined

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Admin']), 'admin@rallyto.ir')
})
afterEach(() => api?.restore())

describe('admin users API contract', () => {
  it('lists at GET /api/v1/admin/users with the filters and paging as the query, as the admin', async () => {
    const body = page([account()], { totalCount: 41, page: 2 })
    api = installFakeApi(() => ({ status: 200, body: envelope(body) }))

    const result = await usersApi.list({ search: '912', status: 'Suspended', page: 2, pageSize: 20 })

    expect(api.requests).toEqual([
      {
        method: 'GET',
        url: USERS_ENDPOINT,
        body: undefined,
        authorization: 'Bearer access-1',
        params: { search: '912', status: 'Suspended', page: 2, pageSize: 20 },
      },
    ])
    expect(USERS_ENDPOINT).toBe('/api/v1/admin/users')
    expect(result).toEqual(body)
  })

  it('leaves blank filters out of the query', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope(page([])) }))

    await usersApi.list({ search: '   ', status: undefined, page: 1, pageSize: 20 })

    expect(api.requests[0]!.params).toEqual({ page: 1, pageSize: 20 })
  })

  it('reads one account at GET /api/v1/admin/users/{userId}', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope(account({ userId: 'u-7' })) }))

    const result = await usersApi.get('u-7')

    expect(api.requests[0]).toMatchObject({ method: 'GET', url: '/api/v1/admin/users/u-7' })
    expect(result.userId).toBe('u-7')
  })

  it('suspends at POST …/suspend with { until, reason }', async () => {
    api = installFakeApi(() => ({ status: 204 }))

    await usersApi.suspend('u-1', { until: '2026-10-30T10:00:00.000Z', reason: 'توهین در چت' })

    expect(api.requests[0]).toMatchObject({
      method: 'POST',
      url: '/api/v1/admin/users/u-1/suspend',
      body: { until: '2026-10-30T10:00:00.000Z', reason: 'توهین در چت' },
      authorization: 'Bearer access-1',
    })
  })

  it('lifts a suspension at POST …/lift-suspension with { reason }', async () => {
    api = installFakeApi(() => ({ status: 204 }))

    await usersApi.liftSuspension('u-1', 'اشتباه بود')

    expect(api.requests[0]).toMatchObject({
      method: 'POST',
      url: '/api/v1/admin/users/u-1/lift-suspension',
      body: { reason: 'اشتباه بود' },
    })
  })

  it('bans at POST …/ban with { reason }', async () => {
    api = installFakeApi(() => ({ status: 204 }))

    await usersApi.ban('u-1', 'کلاهبرداری')

    expect(api.requests[0]).toMatchObject({ method: 'POST', url: '/api/v1/admin/users/u-1/ban', body: { reason: 'کلاهبرداری' } })
  })

  it('grants the admin role at POST …/roles/admin and revokes it at DELETE …/roles/admin', async () => {
    api = installFakeApi(() => ({ status: 204 }))

    await usersApi.grantAdmin('u-1')
    await usersApi.revokeAdmin('u-1')

    expect(api.requests.map((r) => [r.method, r.url])).toEqual([
      ['POST', '/api/v1/admin/users/u-1/roles/admin'],
      ['DELETE', '/api/v1/admin/users/u-1/roles/admin'],
    ])
  })

  it('escapes the user id in the path', async () => {
    api = installFakeApi(() => ({ status: 204 }))

    await usersApi.ban('a/b', 'x')

    expect(api.requests[0]!.url).toBe('/api/v1/admin/users/a%2Fb/ban')
  })

  it('fails with the server’s Persian message on an error envelope', async () => {
    api = installFakeApi(() => ({
      status: 409,
      body: errorEnvelope(409, 'نمی‌توانید نقش آخرین مدیر را بگیرید.', 'LAST_ADMIN'),
    }))

    const failure = await usersApi.revokeAdmin('u-1').catch((error: unknown) => error)

    expect(getApiErrorMessage(failure)).toBe('نمی‌توانید نقش آخرین مدیر را بگیرید.')
  })
})
