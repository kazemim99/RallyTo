import { defineStore } from 'pinia'
import { computed, onScopeDispose, ref } from 'vue'
import { authApi } from '../api/auth.api'
import { ADMIN_ROLE, type AdminUser } from '../types/auth.types'
import { refreshAccessToken, UserFacingError } from '../utils/axios'
import { tokenStorage } from '../utils/token-storage'

export const ADMIN_ROLE_REQUIRED_MESSAGE =
  'این حساب دسترسی به پنل مدیریت ندارد. فقط مدیران رالیتو می‌توانند وارد این پنل شوند.'

/** Correct credentials for an account without the Admin role (identity-access › Admin panel sign-in). */
export class AdminRoleRequiredError extends UserFacingError {
  constructor() {
    super(ADMIN_ROLE_REQUIRED_MESSAGE)
    this.name = 'AdminRoleRequiredError'
  }
}

export const hasAdminRole = (roles: readonly string[] | null | undefined): boolean =>
  Array.isArray(roles) && roles.includes(ADMIN_ROLE)

export const useAuthStore = defineStore('auth', () => {
  const initial = tokenStorage.read()
  const accessToken = ref<string | null>(initial.accessToken)
  const refreshToken = ref<string | null>(initial.refreshToken)
  const user = ref<AdminUser | null>(initial.user)

  // The axios client refreshes and ends sessions without going through the store; follow the storage.
  const unsubscribe = tokenStorage.subscribe((session) => {
    accessToken.value = session.accessToken
    refreshToken.value = session.refreshToken
    user.value = session.user
  })
  onScopeDispose(unsubscribe)

  const isAuthenticated = computed(() => !!accessToken.value)
  const isAdmin = computed(() => hasAdminRole(user.value?.roles))

  /**
   * Signs in with email and password and stores the session, but only for an account with the Admin role. Anyone
   * else gets an {@link AdminRoleRequiredError} with a Persian message, nothing is stored, and the session the
   * server just opened is revoked rather than left alive. The email is trimmed; the server lower-cases it.
   */
  async function signIn(email: string, password: string): Promise<AdminUser> {
    const trimmedEmail = email.trim()
    const tokens = await authApi.signIn(trimmedEmail, password)

    if (!hasAdminRole(tokens.roles)) {
      authApi.signOut(tokens.refreshToken, tokens.accessToken).catch(() => undefined)
      throw new AdminRoleRequiredError()
    }

    tokenStorage.save(tokens, trimmedEmail)
    return user.value!
  }

  /** Rotates the token pair through the client's single shared refresh. A failure ends the session. */
  async function refresh(): Promise<string> {
    return refreshAccessToken()
  }

  /** Revokes the refresh token on the server, best effort, and always forgets the session locally. */
  async function signOut(): Promise<void> {
    const token = refreshToken.value
    try {
      if (token) await authApi.signOut(token)
    } catch {
      // The local session ends whatever the server answered.
    } finally {
      tokenStorage.clear()
    }
  }

  return {
    accessToken,
    refreshToken,
    user,
    isAuthenticated,
    isAdmin,
    signIn,
    refresh,
    signOut,
  }
})
