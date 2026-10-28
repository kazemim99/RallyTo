import { defineStore } from 'pinia'
import { ref } from 'vue'
import { statsApi, type UsageStats, type UsageStatsQuery } from '../api/stats.api'
import { getApiErrorMessage } from '../utils/axios'

/** The usage dashboard's figures for one period. Only the newest read writes them; a failure keeps the last figures. */
export const useStatsStore = defineStore('stats', () => {
  const stats = ref<UsageStats | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  let latestRequest = 0

  async function load(query: UsageStatsQuery = {}): Promise<void> {
    const ticket = ++latestRequest
    loading.value = true
    error.value = null
    try {
      const result = await statsApi.usage(query)
      if (ticket === latestRequest) stats.value = result
    } catch (failure) {
      if (ticket === latestRequest) error.value = getApiErrorMessage(failure)
    } finally {
      if (ticket === latestRequest) loading.value = false
    }
  }

  return { stats, loading, error, load }
})
