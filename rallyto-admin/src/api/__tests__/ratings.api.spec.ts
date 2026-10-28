import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { ratingsApi } from '../ratings.api'
import { getApiErrorMessage } from '../../utils/axios'
import { tokenStorage } from '../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens } from '../../utils/__tests__/fakeApi'
import { TARGET_ID, adminRating } from './safetyFixtures'

let api: ReturnType<typeof installFakeApi> | undefined

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Admin']), 'admin@rallyto.ir')
})
afterEach(() => api?.restore())

describe('admin ratings API contract', () => {
  it('lists a player’s ratings at GET /api/v1/admin/players/{userId}/ratings, as the admin', async () => {
    const list = [adminRating(), adminRating({ id: 'rt-2', removedAt: '2026-10-22T10:00:00Z', removalReason: 'انتقام' })]
    api = installFakeApi(() => ({ status: 200, body: envelope(list) }))

    const result = await ratingsApi.listForPlayer(TARGET_ID)

    expect(api.requests).toEqual([
      {
        method: 'GET',
        url: `/api/v1/admin/players/${TARGET_ID}/ratings`,
        body: undefined,
        authorization: 'Bearer access-1',
      },
    ])
    expect(result).toEqual(list)
  })

  it('removes a rating with a DELETE that carries { reason } as its JSON body', async () => {
    api = installFakeApi(() => ({ status: 204 }))

    await ratingsApi.remove('rt-1', 'انتقام بعد از اختلاف')

    expect(api.requests[0]).toMatchObject({
      method: 'DELETE',
      url: '/api/v1/admin/ratings/rt-1',
      body: { reason: 'انتقام بعد از اختلاف' },
      authorization: 'Bearer access-1',
    })
  })

  it('fails with the server’s Persian message', async () => {
    api = installFakeApi(() => ({ status: 404, body: errorEnvelope(404, 'امتیاز پیدا نشد.', 'RATING_NOT_FOUND') }))

    const failure = await ratingsApi.remove('none', 'x').catch((error: unknown) => error)

    expect(getApiErrorMessage(failure)).toBe('امتیاز پیدا نشد.')
  })
})
