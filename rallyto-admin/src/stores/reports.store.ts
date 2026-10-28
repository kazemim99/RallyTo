import { defineStore } from 'pinia'
import { ref } from 'vue'
import { safetyApi, type ReportGroup } from '../api/safety.api'
import { isConflict } from './pagedList'
import { getApiErrorMessage } from '../utils/axios'

/**
 * The report queue: open reports grouped by target, in the server's order (high priority, then the oldest).
 * Dismissing a report re-reads the queue when it succeeds, and after a 409 (someone else closed it first); a failed
 * command rethrows the client's error untouched.
 */
export const useReportsStore = defineStore('reports', () => {
  const groups = ref<ReportGroup[]>([])
  const loading = ref(false)
  /** The Persian message of the last failed read; null once a read succeeds. */
  const error = ref<string | null>(null)

  let latestRequest = 0

  async function fetchQueue(): Promise<void> {
    const ticket = ++latestRequest
    loading.value = true
    error.value = null
    try {
      const list = await safetyApi.queue()
      if (ticket === latestRequest) groups.value = list
    } catch (failure) {
      if (ticket === latestRequest) error.value = getApiErrorMessage(failure)
    } finally {
      if (ticket === latestRequest) loading.value = false
    }
  }

  async function dismiss(reportId: string, reason: string): Promise<void> {
    try {
      await safetyApi.dismiss(reportId, reason.trim())
    } catch (failure) {
      if (isConflict(failure)) await fetchQueue()
      throw failure
    }
    await fetchQueue()
  }

  return { groups, loading, error, fetchQueue, dismiss }
})
