import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { PLAYERS_ENDPOINT, isPlayerNotFound, playerPhotoSrc, playersApi } from '../players.api'
import { API_BASE_URL, getApiErrorMessage } from '../../utils/axios'
import { tokenStorage } from '../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens } from '../../utils/__tests__/fakeApi'
import { playerProfile } from './playerFixtures'

let api: ReturnType<typeof installFakeApi> | undefined

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Admin']), 'admin@rallyto.ir')
})
afterEach(() => api?.restore())

describe('admin players API contract', () => {
  it('reads a profile at GET /api/v1/admin/players/{userId}, as the admin', async () => {
    const body = playerProfile({ userId: 'u-7' })
    api = installFakeApi(() => ({ status: 200, body: envelope(body) }))

    const result = await playersApi.get('u-7')

    expect(PLAYERS_ENDPOINT).toBe('/api/v1/admin/players')
    expect(api.requests).toEqual([
      { method: 'GET', url: '/api/v1/admin/players/u-7', body: undefined, authorization: 'Bearer access-1' },
    ])
    expect(result).toEqual(body)
  })

  it('corrects the gender at POST …/gender with { gender, reason }', async () => {
    api = installFakeApi(() => ({ status: 204 }))

    await playersApi.correctGender('u-1', { gender: 'Male', reason: 'اشتباه در ثبت‌نام' })

    expect(api.requests[0]).toMatchObject({
      method: 'POST',
      url: '/api/v1/admin/players/u-1/gender',
      body: { gender: 'Male', reason: 'اشتباه در ثبت‌نام' },
      authorization: 'Bearer access-1',
    })
  })

  it('removes the photo with a DELETE that carries { reason } as its JSON body', async () => {
    api = installFakeApi(() => ({ status: 204 }))

    await playersApi.removePhoto('u-1', 'عکس نامناسب')

    expect(api.requests[0]).toMatchObject({
      method: 'DELETE',
      url: '/api/v1/admin/players/u-1/photo',
      body: { reason: 'عکس نامناسب' },
      authorization: 'Bearer access-1',
    })
  })

  it('escapes the user id in the path', async () => {
    api = installFakeApi(() => ({ status: 204 }))

    await playersApi.removePhoto('a/b', 'x')

    expect(api.requests[0]!.url).toBe('/api/v1/admin/players/a%2Fb/photo')
  })

  it('recognises PLAYER_NOT_FOUND, and only a 404, as “no profile yet”', async () => {
    api = installFakeApi((request) =>
      request.url.endsWith('/none')
        ? { status: 404, body: errorEnvelope(404, 'بازیکن پیدا نشد.', 'PLAYER_NOT_FOUND') }
        : { status: 500, body: errorEnvelope(500, 'خطای سرور.') },
    )

    const missing = await playersApi.get('none').catch((error: unknown) => error)
    const broken = await playersApi.get('other').catch((error: unknown) => error)

    expect(isPlayerNotFound(missing)).toBe(true)
    expect(isPlayerNotFound(broken)).toBe(false)
    expect(isPlayerNotFound(new Error('x'))).toBe(false)
  })

  it('fails with the server’s Persian message on a refused command', async () => {
    api = installFakeApi(() => ({ status: 400, body: errorEnvelope(400, 'دلیل را بنویسید.', 'REASON_REQUIRED') }))

    const failure = await playersApi.correctGender('u-1', { gender: 'Male', reason: '' }).catch((error: unknown) => error)

    expect(getApiErrorMessage(failure)).toBe('دلیل را بنویسید.')
  })
})

describe('playerPhotoSrc', () => {
  it('puts a server path on the API origin and keeps an absolute URL', () => {
    expect(playerPhotoSrc('/media/avatars/x.jpg')).toBe(`${API_BASE_URL.replace(/\/+$/, '')}/media/avatars/x.jpg`)
    expect(playerPhotoSrc('https://cdn.example.com/x.jpg')).toBe('https://cdn.example.com/x.jpg')
    expect(playerPhotoSrc(null)).toBeNull()
  })
})
