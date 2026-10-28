import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import apiClient, {
  AUTH_ENDPOINTS,
  GENERIC_ERROR_MESSAGE,
  NETWORK_ERROR_MESSAGE,
  UserFacingError,
  getApiErrorMessage,
  setNavigator,
} from '../axios'
import { ACCESS_TOKEN_KEY, REFRESH_TOKEN_KEY, USER_KEY, tokenStorage } from '../token-storage'
import { useAuthStore } from '../../stores/auth.store'
import { deferred, envelope, errorEnvelope, installFakeApi, tokens, type RecordedRequest } from './fakeApi'

const USERS = '/api/v1/admin/users'
const SPORTS = '/api/v1/admin/sports'

let api: ReturnType<typeof installFakeApi> | undefined
let navigate: ReturnType<typeof vi.fn<(path: string) => void>>

/** A protected endpoint that accepts only the given access token. */
const protectedReply = (request: RecordedRequest, validToken: string) =>
  request.authorization === `Bearer ${validToken}`
    ? { status: 200, body: envelope({ url: request.url }) }
    : { status: 401, body: errorEnvelope(401, 'Unauthorized', 'UNAUTHORIZED') }

const signedIn = () => tokenStorage.save(tokens(['Player', 'Admin'], 'old'), 'admin@rallyto.ir')

beforeEach(() => {
  localStorage.clear()
  setActivePinia(createPinia())
  navigate = vi.fn<(path: string) => void>()
  setNavigator(navigate)
})

afterEach(() => {
  api?.restore()
  api = undefined
  setNavigator(null)
})

describe('the response envelope', () => {
  it('hands the caller the payload, not the envelope', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope({ id: 7, name: 'تنیس' }) }))

    const { data } = await apiClient.get(SPORTS)

    expect(data).toEqual({ id: 7, name: 'تنیس' })
  })

  it('turns a blank 2xx envelope, which carries no data member, into null', async () => {
    api = installFakeApi(() => ({ status: 200, body: { success: true, statusCode: 200, message: 'ok' } }))

    expect((await apiClient.post(AUTH_ENDPOINTS.signOut, {})).data).toBeNull()
  })

  it('leaves a body that merely has a data property alone', async () => {
    api = installFakeApi(() => ({ status: 200, body: { id: 'x', data: 'own field' } }))

    expect((await apiClient.get(SPORTS)).data).toEqual({ id: 'x', data: 'own field' })
  })
})

describe('the Authorization header', () => {
  it('sends the stored access token as a Bearer token', async () => {
    signedIn()
    api = installFakeApi(() => ({ status: 200, body: envelope([]) }))

    await apiClient.get(USERS)

    expect(api.requests[0]!.authorization).toBe('Bearer access-old')
  })

  it('sends none when there is no session', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope([]) }))

    await apiClient.get(SPORTS)

    expect(api.requests[0]!.authorization).toBeNull()
  })
})

describe('refresh on 401', () => {
  it('two concurrent 401s produce exactly one refresh call, and both requests are retried', async () => {
    signedIn()
    const refreshReply = deferred<void>()
    api = installFakeApi(async (request) => {
      if (request.url === AUTH_ENDPOINTS.refresh) {
        await refreshReply.promise
        return { status: 200, body: envelope(tokens(['Player', 'Admin'], 'new')) }
      }
      return protectedReply(request, 'access-new')
    })

    const users = apiClient.get(USERS)
    const sports = apiClient.get(SPORTS)

    // Both 401s have arrived and are waiting on the refresh, which has not answered yet.
    await vi.waitFor(() => expect(api!.to(AUTH_ENDPOINTS.refresh)).toHaveLength(1))
    await flushPromises()
    expect(api.to(AUTH_ENDPOINTS.refresh)).toHaveLength(1)

    refreshReply.resolve()
    const [usersResponse, sportsResponse] = await Promise.all([users, sports])

    expect(usersResponse.data).toEqual({ url: USERS })
    expect(sportsResponse.data).toEqual({ url: SPORTS })
    expect(api.to(AUTH_ENDPOINTS.refresh)).toHaveLength(1)
    expect(api.to(AUTH_ENDPOINTS.refresh)[0]!.body).toEqual({ refreshToken: 'refresh-old' })
    expect(api.to(AUTH_ENDPOINTS.refresh)[0]!.authorization).toBeNull()
    expect(api.to(USERS).map((r) => r.authorization)).toEqual(['Bearer access-old', 'Bearer access-new'])
    expect(api.to(SPORTS).map((r) => r.authorization)).toEqual(['Bearer access-old', 'Bearer access-new'])
    // The rotated pair is stored; the old refresh token is never presented again.
    expect(localStorage.getItem(ACCESS_TOKEN_KEY)).toBe('access-new')
    expect(localStorage.getItem(REFRESH_TOKEN_KEY)).toBe('refresh-new')
    expect(navigate).not.toHaveBeenCalled()
  })

  it('retries a 401 that was overtaken by another request’s refresh with the new token, without refreshing again', async () => {
    signedIn()
    const holdUsers = deferred<void>()
    api = installFakeApi(async (request) => {
      if (request.url === AUTH_ENDPOINTS.refresh) {
        return { status: 200, body: envelope(tokens(['Player', 'Admin'], 'new')) }
      }
      // The first users request, sent with the old token, answers only after the sports refresh is done.
      if (request.url === USERS && request.authorization === 'Bearer access-old') await holdUsers.promise
      return protectedReply(request, 'access-new')
    })

    const users = apiClient.get(USERS)
    await expect(apiClient.get(SPORTS)).resolves.toMatchObject({ data: { url: SPORTS } })
    holdUsers.resolve()

    await expect(users).resolves.toMatchObject({ data: { url: USERS } })
    expect(api.to(AUTH_ENDPOINTS.refresh)).toHaveLength(1)
  })

  it('when the refresh fails, clears the tokens and goes to /login once, and both requests fail', async () => {
    signedIn()
    const store = useAuthStore()
    expect(store.isAuthenticated).toBe(true)
    api = installFakeApi((request) =>
      request.url === AUTH_ENDPOINTS.refresh
        ? { status: 401, body: errorEnvelope(401, 'نشست شما منقضی شده است.', 'INVALID_REFRESH_TOKEN') }
        : protectedReply(request, 'access-new'),
    )

    const results = await Promise.allSettled([apiClient.get(USERS), apiClient.get(SPORTS)])

    expect(results.map((r) => r.status)).toEqual(['rejected', 'rejected'])
    expect(api.to(AUTH_ENDPOINTS.refresh)).toHaveLength(1)
    expect(localStorage.getItem(ACCESS_TOKEN_KEY)).toBeNull()
    expect(localStorage.getItem(REFRESH_TOKEN_KEY)).toBeNull()
    expect(localStorage.getItem(USER_KEY)).toBeNull()
    expect(navigate).toHaveBeenCalledTimes(1)
    expect(navigate).toHaveBeenCalledWith('/login')
    // The store follows the storage, so the guard sees the session is over.
    expect(store.isAuthenticated).toBe(false)
  })

  it('ends the session on a 401 when there is no refresh token to try', async () => {
    localStorage.setItem(ACCESS_TOKEN_KEY, 'access-orphan')
    api = installFakeApi((request) => protectedReply(request, 'never'))

    await expect(apiClient.get(USERS)).rejects.toMatchObject({ response: { status: 401 } })

    expect(api.to(AUTH_ENDPOINTS.refresh)).toHaveLength(0)
    expect(localStorage.getItem(ACCESS_TOKEN_KEY)).toBeNull()
    expect(navigate).toHaveBeenCalledWith('/login')
  })

  it('retries a request at most once', async () => {
    signedIn()
    api = installFakeApi((request) =>
      request.url === AUTH_ENDPOINTS.refresh
        ? { status: 200, body: envelope(tokens(['Player', 'Admin'], 'new')) }
        : protectedReply(request, 'never-valid'),
    )

    await expect(apiClient.get(USERS)).rejects.toMatchObject({ response: { status: 401 } })

    expect(api.to(USERS)).toHaveLength(2)
    expect(api.to(AUTH_ENDPOINTS.refresh)).toHaveLength(1)
  })

  it('never refreshes for the auth endpoints themselves: a wrong password is final', async () => {
    signedIn()
    api = installFakeApi(() => ({
      status: 401,
      body: errorEnvelope(401, 'ایمیل یا رمز عبور درست نیست.', 'INVALID_CREDENTIALS'),
    }))

    const attempt = apiClient.post(
      AUTH_ENDPOINTS.adminSignIn,
      { email: 'admin@rallyto.ir', password: 'wrong' },
      { skipAuthRefresh: true },
    )
    await expect(attempt).rejects.toMatchObject({ response: { status: 401 } })
    expect(getApiErrorMessage(await attempt.catch((error: unknown) => error))).toBe('ایمیل یا رمز عبور درست نیست.')

    expect(api.to(AUTH_ENDPOINTS.refresh)).toHaveLength(0)
    expect(navigate).not.toHaveBeenCalled()
    expect(localStorage.getItem(ACCESS_TOKEN_KEY)).toBe('access-old')
  })
})

describe('getApiErrorMessage', () => {
  const failWith = async (reply: Parameters<typeof installFakeApi>[0]) => {
    api = installFakeApi(reply)
    try {
      await apiClient.get(SPORTS)
    } catch (error) {
      return error
    }
    throw new Error('expected the call to fail')
  }

  it('shows the envelope’s own Persian message', async () => {
    const error = await failWith(() => ({
      status: 429,
      body: errorEnvelope(429, 'درخواست‌های زیادی فرستاده‌اید. چند دقیقه دیگر دوباره تلاش کنید.', 'TOO_MANY_REQUESTS'),
    }))

    expect(getApiErrorMessage(error)).toBe('درخواست‌های زیادی فرستاده‌اید. چند دقیقه دیگر دوباره تلاش کنید.')
  })

  it('falls back to the first field message of a validation failure', async () => {
    const error = await failWith(() => ({
      status: 400,
      body: { ...errorEnvelope(400, '', 'VALIDATION_ERROR', { phoneNumber: ['شماره موبایل معتبر نیست.'] }), message: '' },
    }))

    expect(getApiErrorMessage(error)).toBe('شماره موبایل معتبر نیست.')
  })

  it('explains a network failure in Persian', async () => {
    const error = await failWith(() => ({ network: true }))

    expect(getApiErrorMessage(error)).toBe(NETWORK_ERROR_MESSAGE)
  })

  it('uses the Persian fallback for a body that is not an envelope', async () => {
    const error = await failWith(() => ({ status: 502, body: '<html>Bad Gateway</html>' }))

    expect(getApiErrorMessage(error)).toBe(GENERIC_ERROR_MESSAGE)
    expect(getApiErrorMessage(new Error('internal detail'))).toBe(GENERIC_ERROR_MESSAGE)
  })

  it('passes a user-facing error’s message through', () => {
    expect(getApiErrorMessage(new UserFacingError('پیام فارسی'))).toBe('پیام فارسی')
  })
})
