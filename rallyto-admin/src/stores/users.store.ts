import { defineStore } from 'pinia'
import axios from 'axios'
import { reactive, ref } from 'vue'
import { usersApi, type AccountStatus, type AdminAccount } from '../api/users.api'
import { getApiErrorMessage } from '../utils/axios'
import { digitsOnly } from '../utils/digits'

export const DEFAULT_PAGE_SIZE = 20

export interface UserFilters {
  /** As typed: Persian digits and separators are fine, only the digits are sent. */
  search: string
  status: AccountStatus | undefined
}

/** A 409 means the account changed under the list (someone else acted on it): the rows on screen are stale. */
const isConflict = (error: unknown) => axios.isAxiosError(error) && error.response?.status === 409

/**
 * The Users screen's state: one server-side page of accounts, its filters, and the admin actions on an account.
 *
 * Every action re-reads the current page when it succeeds, and also after a 409, so the table never shows a status
 * the server no longer holds. A failed action rethrows the client's error untouched; `getApiErrorMessage` turns it
 * into the server's Persian message.
 */
export const useUsersStore = defineStore('users', () => {
  const items = ref<AdminAccount[]>([])
  const totalCount = ref(0)
  const page = ref(1)
  const pageSize = ref(DEFAULT_PAGE_SIZE)
  const filters = reactive<UserFilters>({ search: '', status: undefined })
  const loading = ref(false)
  /** The Persian message of the last failed list load; null once a load succeeds. */
  const error = ref<string | null>(null)

  // Only the newest list request may write the state: a slow earlier answer must not overwrite a newer filter.
  let latestRequest = 0

  async function fetchUsers(): Promise<void> {
    const ticket = ++latestRequest
    loading.value = true
    error.value = null
    try {
      const result = await usersApi.list({
        search: digitsOnly(filters.search),
        status: filters.status,
        page: page.value,
        pageSize: pageSize.value,
      })
      if (ticket !== latestRequest) return

      const total = result?.totalCount ?? 0
      const rows = result?.items ?? []
      // The last row of a later page left the filter (suspended under "Active", say): show the new last page.
      const lastPage = Math.max(1, Math.ceil(total / pageSize.value))
      if (rows.length === 0 && page.value > lastPage) {
        page.value = lastPage
        await fetchUsers()
        return
      }
      items.value = rows
      totalCount.value = total
    } catch (failure) {
      if (ticket === latestRequest) error.value = getApiErrorMessage(failure)
    } finally {
      if (ticket === latestRequest) loading.value = false
    }
  }

  /** Changes the filters and starts again from the first page. */
  async function setFilters(next: Partial<UserFilters>): Promise<void> {
    Object.assign(filters, next)
    page.value = 1
    await fetchUsers()
  }

  async function setPage(nextPage: number, nextPageSize: number = pageSize.value): Promise<void> {
    page.value = nextPage
    pageSize.value = nextPageSize
    await fetchUsers()
  }

  async function runAction(command: () => Promise<void>): Promise<void> {
    try {
      await command()
    } catch (failure) {
      if (isConflict(failure)) await fetchUsers()
      throw failure
    }
    await fetchUsers()
  }

  /** `until` is an instant; it is sent as ISO-8601 in UTC. */
  const suspend = (userId: string, until: Date | string, reason: string) =>
    runAction(() =>
      usersApi.suspend(userId, {
        until: typeof until === 'string' ? until : until.toISOString(),
        reason: reason.trim(),
      }),
    )

  const liftSuspension = (userId: string, reason: string) =>
    runAction(() => usersApi.liftSuspension(userId, reason.trim()))

  const ban = (userId: string, reason: string) => runAction(() => usersApi.ban(userId, reason.trim()))

  const grantAdmin = (userId: string) => runAction(() => usersApi.grantAdmin(userId))

  const revokeAdmin = (userId: string) => runAction(() => usersApi.revokeAdmin(userId))

  /** One account, fresh from the server (the detail drawer). */
  const loadUser = (userId: string) => usersApi.get(userId)

  return {
    items,
    totalCount,
    page,
    pageSize,
    filters,
    loading,
    error,
    fetchUsers,
    setFilters,
    setPage,
    suspend,
    liftSuspension,
    ban,
    grantAdmin,
    revokeAdmin,
    loadUser,
  }
})
