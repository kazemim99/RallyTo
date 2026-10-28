import apiClient, { AUTH_ENDPOINTS } from '../utils/axios'
import type { AuthTokens } from '../types/auth.types'

/**
 * Admin sign-in (identity-access). Admins sign in with their email and password; players use SMS codes in the app,
 * never here. The panel still admits the account only when its roles contain `Admin`.
 *
 * The refresh call lives in `utils/axios.ts` (`refreshAccessToken`), because it must bypass the 401 handling it
 * serves and be shared by every request that needs it.
 */
export const authApi = {
  /**
   * Exchanges an email and password for a token pair, anonymously. A wrong password is an error envelope
   * (401 `INVALID_CREDENTIALS`, 429 `ADMIN_SIGN_IN_LOCKED` after repeated failures), never a refresh-and-retry.
   */
  async signIn(email: string, password: string): Promise<AuthTokens> {
    const { data } = await apiClient.post<AuthTokens>(
      AUTH_ENDPOINTS.adminSignIn,
      { email, password },
      { skipAuthRefresh: true, skipAuthHeader: true },
    )
    return data
  },

  /**
   * Revokes the session's refresh token. `accessToken` is given when the session was never stored (a non-admin
   * account turned away at sign-in); otherwise the stored token is sent as usual.
   */
  async signOut(refreshToken: string, accessToken?: string): Promise<void> {
    await apiClient.post(
      AUTH_ENDPOINTS.signOut,
      { refreshToken },
      {
        skipAuthRefresh: true,
        headers: accessToken ? { Authorization: `Bearer ${accessToken}` } : undefined,
      },
    )
  },
}
