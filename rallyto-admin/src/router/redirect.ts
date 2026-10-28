export const DEFAULT_LANDING = '/dashboard'

/**
 * Where to go after sign-in: the `redirect` query when it is a path inside the panel, the dashboard otherwise.
 * `//host` and absolute URLs are refused, so the login page cannot be used to bounce an admin to another site.
 */
export function safeRedirect(value: unknown): string {
  const target = Array.isArray(value) ? value[0] : value
  if (typeof target !== 'string' || !target.startsWith('/') || target.startsWith('//') || target.startsWith('/\\')) {
    return DEFAULT_LANDING
  }
  return target.startsWith('/login') ? DEFAULT_LANDING : target
}
