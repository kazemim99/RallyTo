import { defineStore } from 'pinia'
import axios from 'axios'
import { computed, ref } from 'vue'
import { sportsApi, type Sport, type SportRequest } from '../api/sports.api'
import { getApiErrorMessage } from '../utils/axios'

const isConflict = (error: unknown) => axios.isAxiosError(error) && error.response?.status === 409

/**
 * The sport catalog: every sport, inactive ones included, in the server's order. The Sports screen edits it; the
 * venue screens read it for the sports editor (which sports exist, and each one's surfaces).
 *
 * Every command re-reads the list when it succeeds, and after a 409. A failed command rethrows the client's error.
 */
export const useSportsStore = defineStore('sports', () => {
  const items = ref<Sport[]>([])
  const loading = ref(false)
  const loaded = ref(false)
  const error = ref<string | null>(null)

  // Only the newest request may write the list: a slow read from before a command must not undo its refresh.
  let latestRequest = 0
  let inFlight: Promise<void> | null = null

  const byCode = computed(() => new Map(items.value.map((sport) => [sport.code, sport])))
  const activeSports = computed(() => items.value.filter((sport) => sport.isActive))

  async function load(): Promise<void> {
    const ticket = ++latestRequest
    loading.value = true
    error.value = null
    try {
      const list = await sportsApi.list()
      if (ticket !== latestRequest) return
      items.value = [...list].sort((a, b) => a.sortOrder - b.sortOrder)
      loaded.value = true
    } catch (failure) {
      if (ticket === latestRequest) error.value = getApiErrorMessage(failure)
    } finally {
      if (ticket === latestRequest) loading.value = false
    }
  }

  /** Reads the list again. */
  function fetchSports(): Promise<void> {
    const request = load().finally(() => {
      if (inFlight === request) inFlight = null
    })
    inFlight = request
    return request
  }

  /** Loads the list once (the venue screens share it); a load already under way is awaited, not repeated. */
  async function ensureLoaded(): Promise<void> {
    if (loaded.value) return
    await (inFlight ?? fetchSports())
  }

  async function runAction<T>(command: () => Promise<T>): Promise<T> {
    let result: T
    try {
      result = await command()
    } catch (failure) {
      if (isConflict(failure)) await fetchSports()
      throw failure
    }
    await fetchSports()
    return result
  }

  const create = (request: SportRequest) => runAction(() => sportsApi.create(request))
  const update = (sportId: string, request: SportRequest) => runAction(() => sportsApi.update(sportId, request))
  const activate = (sportId: string) => runAction(() => sportsApi.activate(sportId))
  const deactivate = (sportId: string) => runAction(() => sportsApi.deactivate(sportId))

  return { items, loading, loaded, error, byCode, activeSports, fetchSports, ensureLoaded, create, update, activate, deactivate }
})
