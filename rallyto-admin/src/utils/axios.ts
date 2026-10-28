import axios, { AxiosError, type AxiosInstance, type InternalAxiosRequestConfig } from 'axios'
import { isApiEnvelope } from '../types/api.types'
import type { AuthTokens } from '../types/auth.types'
import { tokenStorage } from './token-storage'

declare module 'axios' {
  interface AxiosRequestConfig {
    /** No refresh-and-retry on 401. The auth endpoints set it: a wrong password or a dead refresh token is final. */
    skipAuthRefresh?: boolean
    /** Send no Authorization header (the anonymous auth endpoints). */
    skipAuthHeader?: boolean
    /** Set on the one retry after a refresh, so a request is never refreshed for twice. */
    _retried?: boolean
  }
}

/** The API origin. Paths carry their own `/api/v1` prefix, as in the backend's routes. */
export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:5000'

export const AUTH_ENDPOINTS = {
  adminSignIn: '/api/v1/auth/admin/sign-in',
  refresh: '/api/v1/auth/refresh',
  signOut: '/api/v1/auth/sign-out',
} as const

export const LOGIN_PATH = '/login'

export const GENERIC_ERROR_MESSAGE = 'خطایی رخ داد. لطفاً دوباره تلاش کنید.'
export const NETWORK_ERROR_MESSAGE = 'ارتباط با سرور برقرار نشد. اتصال اینترنت را بررسی کنید.'

const apiClient: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: { 'Content-Type': 'application/json' },
})

// --- Navigation -------------------------------------------------------------------------------------------------

type Navigate = (path: string) => void

const hardNavigate: Navigate = (path) => {
  if (window.location.pathname !== path) window.location.assign(path)
}

let navigate: Navigate = hardNavigate

/**
 * How an ended session reaches the login page. `main.ts` routes it through vue-router so the app is not reloaded;
 * until then (and after `null`) it is a plain page load. Kept injectable so this module never imports the router,
 * which imports the store, which imports this module.
 */
export function setNavigator(fn: Navigate | null): void {
  navigate = fn ?? hardNavigate
}

/** Forgets the session and goes to the login page. */
export function endSession(): void {
  tokenStorage.clear()
  navigate(LOGIN_PATH)
}

// --- Refresh ----------------------------------------------------------------------------------------------------

let refreshInFlight: Promise<string> | null = null

async function requestNewTokens(): Promise<string> {
  const refreshToken = tokenStorage.getRefreshToken()
  if (!refreshToken) throw new Error('There is no refresh token to refresh with.')

  const { data } = await apiClient.post<AuthTokens>(
    AUTH_ENDPOINTS.refresh,
    { refreshToken },
    { skipAuthRefresh: true, skipAuthHeader: true },
  )
  if (!data?.accessToken || !data.refreshToken) throw new Error('The refresh response carried no token pair.')

  tokenStorage.save(data)
  return data.accessToken
}

/**
 * Exchanges the refresh token for a new pair, once for everyone who asks at the same time: refresh tokens are
 * single-use and rotate, and presenting a rotated one again revokes the whole session (identity-access › Refresh
 * token rotation). So concurrent 401s, and the store's own `refresh()`, all await this one promise.
 *
 * If the refresh fails the session is over: the tokens are cleared and the login page opens, exactly once.
 */
export function refreshAccessToken(): Promise<string> {
  refreshInFlight ??= requestNewTokens()
    .catch((error: unknown) => {
      endSession()
      throw error
    })
    .finally(() => {
      refreshInFlight = null
    })
  return refreshInFlight
}

const bearerOf = (config: InternalAxiosRequestConfig): string | null => {
  const header = config.headers?.get?.('Authorization') ?? config.headers?.Authorization
  return typeof header === 'string' ? header.replace(/^Bearer\s+/i, '') : null
}

// --- Interceptors -----------------------------------------------------------------------------------------------

apiClient.interceptors.request.use((config) => {
  if (!config.skipAuthHeader && !config.headers.Authorization) {
    const token = tokenStorage.getAccessToken()
    if (token) config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

apiClient.interceptors.response.use(
  // The API wraps every 2xx body in { success, statusCode, message, data, metadata }. Unwrap it once here so
  // callers receive the payload itself. A blank body has no `data` member, which becomes null.
  (response) => {
    if (isApiEnvelope(response.data)) response.data = response.data.data ?? null
    return response
  },
  async (error: unknown) => {
    if (!axios.isAxiosError(error)) throw error
    const config = error.config
    if (!config || error.response?.status !== 401 || config.skipAuthRefresh || config._retried) throw error

    if (!tokenStorage.getRefreshToken()) {
      endSession()
      throw error
    }

    // A request sent with a token that has since been replaced was overtaken by another request's refresh:
    // retry it with the current token rather than refresh again with an already-rotated refresh token.
    const sentWith = bearerOf(config)
    const current = tokenStorage.getAccessToken()
    let token: string
    if (current && sentWith && current !== sentWith) {
      token = current
    } else {
      try {
        token = await refreshAccessToken()
      } catch {
        throw error
      }
    }

    config._retried = true
    config.headers.Authorization = `Bearer ${token}`
    return apiClient(config)
  },
)

// --- Errors -----------------------------------------------------------------------------------------------------

/** An error whose message is written for the person at the screen, in Persian. */
export class UserFacingError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'UserFacingError'
  }
}

/**
 * The message to show for a failed call: the envelope's own (the API writes it in Persian), else a Persian
 * fallback. Error envelopes carry it twice, as `message` and `error.message`; validation failures list field
 * messages in `error.errors`.
 */
export function getApiErrorMessage(error: unknown, fallback: string = GENERIC_ERROR_MESSAGE): string {
  if (error instanceof UserFacingError) return error.message
  if (!axios.isAxiosError(error)) return fallback

  const body = (error as AxiosError).response?.data
  if (isApiEnvelope(body)) {
    const message = body.error?.message || body.message
    if (message) return message
    const fieldErrors = body.error?.errors ?? body.errors
    const first = fieldErrors ? Object.values(fieldErrors).flat().find(Boolean) : undefined
    if (first) return first
  }
  if (!error.response) return NETWORK_ERROR_MESSAGE
  return fallback
}

/** The envelope's machine-readable code (`SIMILAR_VENUE_EXISTS`), or null when the failure carries none. */
export function getApiErrorCode(error: unknown): string | null {
  if (!axios.isAxiosError(error)) return null
  const body = (error as AxiosError).response?.data
  return isApiEnvelope(body) ? (body.error?.code ?? null) : null
}

export default apiClient
