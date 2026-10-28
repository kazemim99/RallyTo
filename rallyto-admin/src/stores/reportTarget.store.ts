import { defineStore } from 'pinia'
import axios from 'axios'
import { ref } from 'vue'
import { safetyApi, type ModerationAction, type ModerationActionRequest, type TargetDetail } from '../api/safety.api'
import { usersApi, type AdminAccount } from '../api/users.api'
import { isConflict } from './pagedList'
import { getApiErrorMessage } from '../utils/axios'

/**
 * One reported player's file (`GET /admin/reports/targets/{id}`) with their account (`GET /admin/users/{id}`), and
 * the actions taken from it.
 *
 * The account is read alongside but is not required: if it cannot be read the file still shows, with the status
 * unknown. A 404 on the file means the player has no profile (`notFound`). Every command re-reads both when it
 * succeeds, and after a 409; a failed command rethrows the client's error untouched.
 */
export const useReportTargetStore = defineStore('reportTarget', () => {
  const userId = ref<string | null>(null)
  const detail = ref<TargetDetail | null>(null)
  const account = ref<AdminAccount | null>(null)
  const notFound = ref(false)
  const loading = ref(false)
  const error = ref<string | null>(null)

  let latestRequest = 0

  async function load(id: string): Promise<void> {
    const ticket = ++latestRequest
    if (userId.value !== id) {
      detail.value = null
      account.value = null
    }
    userId.value = id
    loading.value = true
    error.value = null
    notFound.value = false
    const [file, owner] = await Promise.allSettled([safetyApi.target(id), usersApi.get(id)])
    if (ticket !== latestRequest) return
    account.value = owner.status === 'fulfilled' ? owner.value : null
    if (file.status === 'fulfilled') {
      detail.value = file.value
    } else {
      detail.value = null
      if (axios.isAxiosError(file.reason) && file.reason.response?.status === 404) notFound.value = true
      else error.value = getApiErrorMessage(file.reason)
    }
    loading.value = false
  }

  function reset(): void {
    latestRequest++
    userId.value = null
    detail.value = null
    account.value = null
    notFound.value = false
    loading.value = false
    error.value = null
  }

  async function runAction<T>(id: string, command: () => Promise<T>): Promise<T> {
    let result: T
    try {
      result = await command()
    } catch (failure) {
      if (isConflict(failure) && userId.value === id) await load(id)
      throw failure
    }
    if (userId.value === id) await load(id)
    return result
  }

  const act = (request: ModerationActionRequest): Promise<ModerationAction> =>
    runAction(request.targetUserId, () => safetyApi.act(request))

  const dismiss = (id: string, reportId: string, reason: string): Promise<void> =>
    runAction(id, () => safetyApi.dismiss(reportId, reason.trim()))

  return { userId, detail, account, notFound, loading, error, load, reset, act, dismiss }
})
