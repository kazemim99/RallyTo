/** `POST /api/v1/auth/admin/sign-in` and `POST /api/v1/auth/refresh` → data. Refresh tokens are single-use and rotate. */
export interface AuthTokens {
  accessToken: string
  accessTokenExpiresAt: string
  refreshToken: string
  refreshTokenExpiresAt: string
  profileCompleted: boolean
  roles: string[]
}

/** What the panel keeps about the signed-in account (`ty_admin_user`). */
export interface AdminUser {
  email: string
  roles: string[]
  profileCompleted: boolean
  accessTokenExpiresAt: string
  refreshTokenExpiresAt: string
}

/** The role that admits an account to the panel (identity-access › Admin panel sign-in). */
export const ADMIN_ROLE = 'Admin'
