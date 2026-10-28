import axios from 'axios'
import { reactive, ref, type UnwrapNestedRefs } from 'vue'
import type { PagedResult } from '../api/users.api'
import { getApiErrorMessage } from '../utils/axios'

export const DEFAULT_PAGE_SIZE = 20

/** A 409 means the row changed under the list (someone else acted on it): the rows on screen are stale. */
export const isConflict = (error: unknown) => axios.isAxiosError(error) && error.response?.status === 409

/**
 * One server-side page of rows with its filters, for a setup store. The same behaviour as the Users screen's store:
 * - only the newest request writes the rows, so a slow answer never overwrites a newer filter;
 * - a page emptied by an action moves back to the new last page;
 * - `runAction` re-reads the page after a command succeeds, and after a 409, then rethrows a failure untouched.
 */
export function usePagedList<T, F extends object>(
  initialFilters: F,
  fetchPage: (filters: UnwrapNestedRefs<F>, page: number, pageSize: number) => Promise<PagedResult<T>>,
) {
  const items = ref<T[]>([])
  const totalCount = ref(0)
  const page = ref(1)
  const pageSize = ref(DEFAULT_PAGE_SIZE)
  const filters = reactive({ ...initialFilters })
  const loading = ref(false)
  const error = ref<string | null>(null)

  let latestRequest = 0

  async function fetch(): Promise<void> {
    const ticket = ++latestRequest
    loading.value = true
    error.value = null
    try {
      const result = await fetchPage(filters, page.value, pageSize.value)
      if (ticket !== latestRequest) return

      const total = result?.totalCount ?? 0
      const rows = result?.items ?? []
      const lastPage = Math.max(1, Math.ceil(total / pageSize.value))
      if (rows.length === 0 && page.value > lastPage) {
        page.value = lastPage
        await fetch()
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
  async function setFilters(next: Partial<F>): Promise<void> {
    Object.assign(filters, next)
    page.value = 1
    await fetch()
  }

  async function setPage(nextPage: number, nextPageSize: number = pageSize.value): Promise<void> {
    page.value = nextPage
    pageSize.value = nextPageSize
    await fetch()
  }

  async function runAction<R>(command: () => Promise<R>): Promise<R> {
    let result: R
    try {
      result = await command()
    } catch (failure) {
      if (isConflict(failure)) await fetch()
      throw failure
    }
    await fetch()
    return result
  }

  return { items, totalCount, page, pageSize, filters, loading, error, fetch, setFilters, setPage, runAction }
}
