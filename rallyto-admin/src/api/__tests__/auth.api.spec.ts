import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { authApi } from '../auth.api'
import { AUTH_ENDPOINTS } from '../../utils/axios'
import { tokenStorage } from '../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens } from '../../utils/__tests__/fakeApi'

let api: ReturnType<typeof installFakeApi> | undefined

beforeEach(() => localStorage.clear())
afterEach(() => api?.restore())

describe('auth API contract', () => {
  it('signs in at POST /api/v1/auth/admin/sign-in with { email, password }, anonymously, and returns the token pair', async () => {
    // A stale session in storage must not leak into the anonymous call.
    tokenStorage.save(tokens(['Admin'], 'stale'), 'admin@rallyto.ir')
    api = installFakeApi(() => ({ status: 200, body: envelope(tokens(['Player', 'Admin'])) }))

    const result = await authApi.signIn('admin@rallyto.ir', 'S3cret pass!')

    expect(api.requests).toEqual([
      {
        method: 'POST',
        url: '/api/v1/auth/admin/sign-in',
        body: { email: 'admin@rallyto.ir', password: 'S3cret pass!' },
        authorization: null,
      },
    ])
    expect(result).toEqual(tokens(['Player', 'Admin']))
  })

  it('treats a 401 INVALID_CREDENTIALS as final: no refresh, and the stored session is untouched', async () => {
    tokenStorage.save(tokens(['Admin'], 'stale'), 'admin@rallyto.ir')
    api = installFakeApi(() => ({
      status: 401,
      body: errorEnvelope(401, 'ایمیل یا رمز عبور درست نیست.', 'INVALID_CREDENTIALS'),
    }))

    await expect(authApi.signIn('admin@rallyto.ir', 'wrong')).rejects.toMatchObject({ response: { status: 401 } })

    expect(api.requests).toHaveLength(1)
    expect(api.to(AUTH_ENDPOINTS.refresh)).toHaveLength(0)
    expect(tokenStorage.getAccessToken()).toBe('access-stale')
  })

  it('signs out at POST /api/v1/auth/sign-out with { refreshToken }, sending the stored access token', async () => {
    tokenStorage.save(tokens(['Admin']), 'admin@rallyto.ir')
    api = installFakeApi(() => ({ status: 200, body: envelope(null) }))

    await authApi.signOut('refresh-1')

    expect(api.requests[0]).toEqual({
      method: 'POST',
      url: '/api/v1/auth/sign-out',
      body: { refreshToken: 'refresh-1' },
      authorization: 'Bearer access-1',
    })
  })

  it('signs out a session that was never stored with its own access token', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope(null) }))

    await authApi.signOut('refresh-player', 'access-player')

    expect(api.requests[0]!.authorization).toBe('Bearer access-player')
  })
})
