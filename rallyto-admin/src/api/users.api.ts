import apiClient from '../utils/axios'

/**
 * User administration (identity-access › admin users). Every route is admin-only; the client adds the bearer
 * token and unwraps the success envelope, so these functions return the payload itself. Commands answer 204.
 */

export const ACCOUNT_STATUSES = ['Active', 'Suspended', 'Banned', 'Deleted'] as const
export type AccountStatus = (typeof ACCOUNT_STATUSES)[number]

export const ROLE_ADMIN = 'Admin'
export const ROLE_PLAYER = 'Player'

export interface AdminAccount {
  userId: string
  /** E.164 as the API stores it; null once the account is deleted. */
  phoneNumber: string | null
  roles: string[]
  status: AccountStatus
  /** UTC ISO-8601; set while the account is suspended. */
  suspendedUntil: string | null
  statusReason: string | null
  createdAt: string
}

export interface PagedResult<T> {
  items: T[]
  page: number
  pageSize: number
  totalCount: number
}

export interface UserListQuery {
  /** Digits of a phone number (ASCII or Persian; a leading 0 is ignored by the server). Omitted when blank. */
  search?: string
  status?: AccountStatus
  page?: number
  pageSize?: number
}

export interface SuspendRequest {
  /** When the suspension ends, ISO-8601 in UTC. */
  until: string
  reason: string
}

export const USERS_ENDPOINT = '/api/v1/admin/users'

const userPath = (userId: string) => `${USERS_ENDPOINT}/${encodeURIComponent(userId)}`

/** Drops blank members so the query string carries only the filters actually set. */
function listParams(query: UserListQuery): Record<string, string | number> {
  const params: Record<string, string | number> = {}
  const search = query.search?.trim()
  if (search) params.search = search
  if (query.status) params.status = query.status
  if (query.page) params.page = query.page
  if (query.pageSize) params.pageSize = query.pageSize
  return params
}

export const usersApi = {
  async list(query: UserListQuery = {}): Promise<PagedResult<AdminAccount>> {
    const { data } = await apiClient.get<PagedResult<AdminAccount>>(USERS_ENDPOINT, { params: listParams(query) })
    return data
  },

  async get(userId: string): Promise<AdminAccount> {
    const { data } = await apiClient.get<AdminAccount>(userPath(userId))
    return data
  },

  async suspend(userId: string, request: SuspendRequest): Promise<void> {
    await apiClient.post(`${userPath(userId)}/suspend`, request)
  },

  async liftSuspension(userId: string, reason: string): Promise<void> {
    await apiClient.post(`${userPath(userId)}/lift-suspension`, { reason })
  },

  async ban(userId: string, reason: string): Promise<void> {
    await apiClient.post(`${userPath(userId)}/ban`, { reason })
  },

  async grantAdmin(userId: string): Promise<void> {
    await apiClient.post(`${userPath(userId)}/roles/admin`)
  },

  async revokeAdmin(userId: string): Promise<void> {
    await apiClient.delete(`${userPath(userId)}/roles/admin`)
  },
}
