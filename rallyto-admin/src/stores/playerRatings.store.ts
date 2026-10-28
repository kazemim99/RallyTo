import { defineStore } from 'pinia'
import { ref } from 'vue'
import { ratingsApi, type AdminRating } from '../api/ratings.api'
import { isConflict } from './pagedList'
import { getApiErrorMessage } from '../utils/axios'

/**
 * The ratings one player received, shown on the player's detail: one player at a time, read fresh when opened.
 * Removing a rating re-reads the list when it succeeds, and after a 409; a failure rethrows the client's error.
 */
export const usePlayerRatingsStore = defineStore('playerRatings', () => {
  const userId = ref<string | null>(null)
  const items = ref<AdminRating[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  let latestRequest = 0

  async function load(id: string): Promise<void> {
    const ticket = ++latestRequest
    if (userId.value !== id) items.value = []
    userId.value = id
    loading.value = true
    error.value = null
    try {
      const list = await ratingsApi.listForPlayer(id)
      if (ticket === latestRequest) items.value = list
    } catch (failure) {
      if (ticket === latestRequest) {
        items.value = []
        error.value = getApiErrorMessage(failure)
      }
    } finally {
      if (ticket === latestRequest) loading.value = false
    }
  }

  function reset(): void {
    latestRequest++
    userId.value = null
    items.value = []
    loading.value = false
    error.value = null
  }

  async function remove(ratingId: string, reason: string): Promise<void> {
    const id = userId.value
    try {
      await ratingsApi.remove(ratingId, reason.trim())
    } catch (failure) {
      if (isConflict(failure) && id && userId.value === id) await load(id)
      throw failure
    }
    if (id && userId.value === id) await load(id)
  }

  return { userId, items, loading, error, load, reset, remove }
})
