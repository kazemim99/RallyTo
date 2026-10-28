import { defineStore } from 'pinia'
import { ref } from 'vue'
import { safetyApi, type DisputedMatch } from '../api/safety.api'
import { getApiErrorMessage } from '../utils/axios'

/** Disputed matches and matches with a contested no-show, newest first, as the server lists them. Read-only. */
export const useDisputedMatchesStore = defineStore('disputedMatches', () => {
  const items = ref<DisputedMatch[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  let latestRequest = 0

  async function fetch(): Promise<void> {
    const ticket = ++latestRequest
    loading.value = true
    error.value = null
    try {
      const list = await safetyApi.disputedMatches()
      if (ticket === latestRequest) items.value = list
    } catch (failure) {
      if (ticket === latestRequest) error.value = getApiErrorMessage(failure)
    } finally {
      if (ticket === latestRequest) loading.value = false
    }
  }

  return { items, loading, error, fetch }
})
