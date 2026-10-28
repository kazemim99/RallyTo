import { defineStore } from 'pinia'
import { ref } from 'vue'
import { isPlayerNotFound, playersApi, type AdminPlayerProfile, type Gender } from '../api/players.api'
import { isConflict } from './pagedList'
import { getApiErrorMessage } from '../utils/axios'

/**
 * The player profile shown in the user detail drawer: one profile at a time, read fresh when the drawer opens, and
 * the admin corrections on it.
 *
 * A 404 is not an error here: the account never finished onboarding, so it has no profile yet (`notFound`).
 * Every command re-reads the profile when it succeeds, and after a 409; a failed command rethrows the client's
 * error untouched, for `getApiErrorMessage` to turn into the server's Persian message.
 */
export const usePlayersStore = defineStore('players', () => {
  const userId = ref<string | null>(null)
  const profile = ref<AdminPlayerProfile | null>(null)
  const notFound = ref(false)
  const loading = ref(false)
  /** The Persian message of the last failed read; null once a read succeeds. */
  const error = ref<string | null>(null)

  // Only the newest read may write the state: the drawer can move to another user before a slow answer arrives.
  let latestRequest = 0

  async function load(id: string): Promise<void> {
    const ticket = ++latestRequest
    if (userId.value !== id) profile.value = null
    userId.value = id
    loading.value = true
    error.value = null
    notFound.value = false
    try {
      const loaded = await playersApi.get(id)
      if (ticket !== latestRequest) return
      profile.value = loaded
    } catch (failure) {
      if (ticket !== latestRequest) return
      profile.value = null
      if (isPlayerNotFound(failure)) notFound.value = true
      else error.value = getApiErrorMessage(failure)
    } finally {
      if (ticket === latestRequest) loading.value = false
    }
  }

  /** Forgets the profile (the drawer closed), so the next user never flashes the previous one. */
  function reset(): void {
    latestRequest++
    userId.value = null
    profile.value = null
    notFound.value = false
    loading.value = false
    error.value = null
  }

  async function runAction(id: string, command: () => Promise<void>): Promise<void> {
    try {
      await command()
    } catch (failure) {
      if (isConflict(failure) && userId.value === id) await load(id)
      throw failure
    }
    if (userId.value === id) await load(id)
  }

  /** The player is notified by the server. */
  const correctGender = (id: string, gender: Gender, reason: string) =>
    runAction(id, () => playersApi.correctGender(id, { gender, reason: reason.trim() }))

  const removePhoto = (id: string, reason: string) => runAction(id, () => playersApi.removePhoto(id, reason.trim()))

  return { userId, profile, notFound, loading, error, load, reset, correctGender, removePhoto }
})
