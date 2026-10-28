import type { AdminUser, AuthTokens } from '../types/auth.types'

export const ACCESS_TOKEN_KEY = 'ty_admin_token'
export const REFRESH_TOKEN_KEY = 'ty_admin_refresh_token'
export const USER_KEY = 'ty_admin_user'

export interface StoredSession {
  accessToken: string | null
  refreshToken: string | null
  user: AdminUser | null
}

type Listener = (session: StoredSession) => void
const listeners = new Set<Listener>()

/**
 * The stored user, read defensively. A session saved before admins signed in by email carries `phoneNumber` and no
 * `email`; it still loads, with an empty email, and the next sign-in writes the new shape.
 */
function readUser(): AdminUser | null {
  const raw = localStorage.getItem(USER_KEY)
  if (!raw) return null
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch {
    return null
  }
  if (!parsed || typeof parsed !== 'object') return null
  const stored = parsed as Partial<AdminUser>
  return {
    email: typeof stored.email === 'string' ? stored.email : '',
    roles: Array.isArray(stored.roles) ? stored.roles : [],
    profileCompleted: stored.profileCompleted === true,
    accessTokenExpiresAt: stored.accessTokenExpiresAt ?? '',
    refreshTokenExpiresAt: stored.refreshTokenExpiresAt ?? '',
  }
}

function emit() {
  const session = tokenStorage.read()
  for (const listener of listeners) listener(session)
}

/**
 * The session in localStorage. The axios client writes here when it refreshes behind the scenes; the auth store
 * subscribes so its reactive state follows. One module owns the keys, so nothing else spells them.
 */
export const tokenStorage = {
  getAccessToken: (): string | null => localStorage.getItem(ACCESS_TOKEN_KEY),
  getRefreshToken: (): string | null => localStorage.getItem(REFRESH_TOKEN_KEY),
  getUser: readUser,

  read(): StoredSession {
    return {
      accessToken: localStorage.getItem(ACCESS_TOKEN_KEY),
      refreshToken: localStorage.getItem(REFRESH_TOKEN_KEY),
      user: readUser(),
    }
  },

  /** Stores a token pair. `email` is given at sign-in; a refresh keeps the one already stored. */
  save(tokens: AuthTokens, email?: string) {
    const user: AdminUser = {
      email: email ?? readUser()?.email ?? '',
      roles: tokens.roles ?? [],
      profileCompleted: tokens.profileCompleted,
      accessTokenExpiresAt: tokens.accessTokenExpiresAt,
      refreshTokenExpiresAt: tokens.refreshTokenExpiresAt,
    }
    localStorage.setItem(ACCESS_TOKEN_KEY, tokens.accessToken)
    localStorage.setItem(REFRESH_TOKEN_KEY, tokens.refreshToken)
    localStorage.setItem(USER_KEY, JSON.stringify(user))
    emit()
  },

  clear() {
    localStorage.removeItem(ACCESS_TOKEN_KEY)
    localStorage.removeItem(REFRESH_TOKEN_KEY)
    localStorage.removeItem(USER_KEY)
    emit()
  },

  /** Called after every save or clear. Returns the unsubscribe function. */
  subscribe(listener: Listener): () => void {
    listeners.add(listener)
    return () => listeners.delete(listener)
  },
}
