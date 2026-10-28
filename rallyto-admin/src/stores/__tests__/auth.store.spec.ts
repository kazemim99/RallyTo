import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'

vi.mock('../../api/auth.api', () => ({
  authApi: { signIn: vi.fn(), signOut: vi.fn() },
}))

import { authApi } from '../../api/auth.api'
import { ADMIN_ROLE_REQUIRED_MESSAGE, AdminRoleRequiredError, useAuthStore } from '../auth.store'
import { AUTH_ENDPOINTS, setNavigator } from '../../utils/axios'
import { ACCESS_TOKEN_KEY, REFRESH_TOKEN_KEY, USER_KEY, tokenStorage } from '../../utils/token-storage'
import { envelope, installFakeApi, tokens } from '../../utils/__tests__/fakeApi'

const api = vi.mocked(authApi)

beforeEach(() => {
  localStorage.clear()
  setActivePinia(createPinia())
  vi.resetAllMocks()
  api.signOut.mockResolvedValue(undefined)
  setNavigator(vi.fn())
})

afterEach(() => setNavigator(null))

describe('admin-role check at sign-in', () => {
  it('rejects an account whose roles lack Admin, with a Persian message', async () => {
    api.signIn.mockResolvedValue(tokens(['Player']))
    const store = useAuthStore()

    const attempt = store.signIn('admin@rallyto.ir', 'pass-1')

    await expect(attempt).rejects.toBeInstanceOf(AdminRoleRequiredError)
    await expect(attempt).rejects.toThrow(ADMIN_ROLE_REQUIRED_MESSAGE)
    expect(ADMIN_ROLE_REQUIRED_MESSAGE).toMatch(/[؀-ۿ]/)
  })

  it('stores nothing for the rejected account, and revokes the session the server opened', async () => {
    api.signIn.mockResolvedValue(tokens(['Player']))
    const store = useAuthStore()

    await store.signIn('admin@rallyto.ir', 'pass-1').catch(() => undefined)

    expect(localStorage.getItem(ACCESS_TOKEN_KEY)).toBeNull()
    expect(localStorage.getItem(REFRESH_TOKEN_KEY)).toBeNull()
    expect(localStorage.getItem(USER_KEY)).toBeNull()
    expect(store.isAuthenticated).toBe(false)
    expect(store.isAdmin).toBe(false)
    expect(api.signOut).toHaveBeenCalledWith('refresh-1', 'access-1')
  })

  it('rejects an account with no roles at all', async () => {
    api.signIn.mockResolvedValue({ ...tokens([]), roles: undefined as unknown as string[] })

    await expect(useAuthStore().signIn('admin@rallyto.ir', 'pass-1')).rejects.toBeInstanceOf(AdminRoleRequiredError)
  })

  it('treats the role name exactly: "admin" in lower case is not the Admin role', async () => {
    api.signIn.mockResolvedValue(tokens(['Player', 'admin']))

    await expect(useAuthStore().signIn('admin@rallyto.ir', 'pass-1')).rejects.toBeInstanceOf(AdminRoleRequiredError)
  })

  it('admits an Admin and keeps the session under the ty_admin_* keys', async () => {
    api.signIn.mockResolvedValue(tokens(['Player', 'Admin']))
    const store = useAuthStore()

    const user = await store.signIn('admin@rallyto.ir', 'pass-1')

    expect(store.isAuthenticated).toBe(true)
    expect(store.isAdmin).toBe(true)
    expect(user.email).toBe('admin@rallyto.ir')
    expect(localStorage.getItem(ACCESS_TOKEN_KEY)).toBe('access-1')
    expect(localStorage.getItem(REFRESH_TOKEN_KEY)).toBe('refresh-1')
    expect(JSON.parse(localStorage.getItem(USER_KEY)!)).toMatchObject({ email: 'admin@rallyto.ir', roles: ['Player', 'Admin'] })
    expect(api.signOut).not.toHaveBeenCalled()
  })
})

describe('what is sent at sign-in', () => {
  it('trims the email and sends the password exactly as typed', async () => {
    api.signIn.mockResolvedValue(tokens(['Admin']))

    const user = await useAuthStore().signIn('  Admin@Rallyto.ir 	', ' pass with spaces ')

    expect(api.signIn).toHaveBeenCalledWith('Admin@Rallyto.ir', ' pass with spaces ')
    expect(user.email).toBe('Admin@Rallyto.ir')
  })

  it('stores nothing when the server refuses the credentials', async () => {
    api.signIn.mockRejectedValue(new Error('INVALID_CREDENTIALS'))
    const store = useAuthStore()

    await expect(store.signIn('admin@rallyto.ir', 'wrong')).rejects.toThrow('INVALID_CREDENTIALS')

    expect(store.isAuthenticated).toBe(false)
    expect(localStorage.getItem(ACCESS_TOKEN_KEY)).toBeNull()
    expect(api.signOut).not.toHaveBeenCalled()
  })
})

describe('session lifecycle', () => {
  it('restores a stored session when the panel opens', () => {
    tokenStorage.save(tokens(['Player', 'Admin']), 'admin@rallyto.ir')

    const store = useAuthStore()

    expect(store.isAuthenticated).toBe(true)
    expect(store.isAdmin).toBe(true)
    expect(store.user?.email).toBe('admin@rallyto.ir')
  })

  it('still loads a session stored before email sign-in, which carries a phone number and no email', () => {
    localStorage.setItem(ACCESS_TOKEN_KEY, 'access-legacy')
    localStorage.setItem(REFRESH_TOKEN_KEY, 'refresh-legacy')
    localStorage.setItem(
      USER_KEY,
      JSON.stringify({
        phoneNumber: '09121234567',
        roles: ['Player', 'Admin'],
        profileCompleted: true,
        accessTokenExpiresAt: '2026-10-24T10:00:00Z',
        refreshTokenExpiresAt: '2026-11-24T10:00:00Z',
      }),
    )

    const store = useAuthStore()

    expect(store.isAuthenticated).toBe(true)
    expect(store.isAdmin).toBe(true)
    expect(store.user?.email).toBe('')
  })

  it('keeps the email empty when a legacy session is refreshed', async () => {
    localStorage.setItem(ACCESS_TOKEN_KEY, 'access-old')
    localStorage.setItem(REFRESH_TOKEN_KEY, 'refresh-old')
    localStorage.setItem(USER_KEY, JSON.stringify({ phoneNumber: '09121234567', roles: ['Admin'] }))
    const fake = installFakeApi(() => ({ status: 200, body: envelope(tokens(['Admin'], 'new')) }))
    const store = useAuthStore()

    try {
      await store.refresh()
    } finally {
      fake.restore()
    }

    expect(store.user?.email).toBe('')
    expect(JSON.parse(localStorage.getItem(USER_KEY)!)).not.toHaveProperty('phoneNumber')
  })

  it('signs out: revokes the refresh token on the server and forgets the session', async () => {
    tokenStorage.save(tokens(['Admin']), 'admin@rallyto.ir')
    const store = useAuthStore()

    await store.signOut()

    expect(api.signOut).toHaveBeenCalledWith('refresh-1')
    expect(store.isAuthenticated).toBe(false)
    expect(localStorage.getItem(REFRESH_TOKEN_KEY)).toBeNull()
  })

  it('forgets the session even when the server cannot be reached to revoke it', async () => {
    tokenStorage.save(tokens(['Admin']), 'admin@rallyto.ir')
    api.signOut.mockRejectedValue(new Error('offline'))
    const store = useAuthStore()

    await expect(store.signOut()).resolves.toBeUndefined()

    expect(store.isAuthenticated).toBe(false)
    expect(localStorage.getItem(ACCESS_TOKEN_KEY)).toBeNull()
  })

  it('refresh() rotates the pair through the client and keeps the email', async () => {
    tokenStorage.save(tokens(['Player', 'Admin'], 'old'), 'admin@rallyto.ir')
    const fake = installFakeApi(() => ({ status: 200, body: envelope(tokens(['Player', 'Admin'], 'new')) }))
    const store = useAuthStore()

    try {
      await expect(store.refresh()).resolves.toBe('access-new')
    } finally {
      fake.restore()
    }

    expect(fake.to(AUTH_ENDPOINTS.refresh)[0]!.body).toEqual({ refreshToken: 'refresh-old' })
    expect(store.accessToken).toBe('access-new')
    expect(store.refreshToken).toBe('refresh-new')
    expect(store.user?.email).toBe('admin@rallyto.ir')
  })

  it('loses the Admin role when a refresh brings roles without it', async () => {
    tokenStorage.save(tokens(['Player', 'Admin'], 'old'), 'admin@rallyto.ir')
    const fake = installFakeApi(() => ({ status: 200, body: envelope(tokens(['Player'], 'new')) }))
    const store = useAuthStore()

    try {
      await store.refresh()
    } finally {
      fake.restore()
    }

    expect(store.isAuthenticated).toBe(true)
    expect(store.isAdmin).toBe(false)
  })
})
