import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { usePlayersStore } from '../players.store'
import { getApiErrorMessage } from '../../utils/axios'
import { tokenStorage } from '../../utils/token-storage'
import {
  deferred,
  envelope,
  errorEnvelope,
  installFakeApi,
  tokens,
  type FakeReply,
  type RecordedRequest,
} from '../../utils/__tests__/fakeApi'
import { playerProfile } from '../../api/__tests__/playerFixtures'

let api: ReturnType<typeof installFakeApi> | undefined

/** Plays the server: reads answer `read`, commands answer `command` (204 by default). */
function serve(options: { read?: (r: RecordedRequest) => FakeReply; command?: (r: RecordedRequest) => FakeReply } = {}) {
  const read = options.read ?? (() => ({ status: 200, body: envelope(playerProfile()) }))
  const command = options.command ?? (() => ({ status: 204 }))
  api = installFakeApi((request) => (request.method === 'GET' ? read(request) : command(request)))
  return api
}

const reads = () => api!.requests.filter((r) => r.method === 'GET')

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Admin']), 'admin@rallyto.ir')
  setActivePinia(createPinia())
})
afterEach(() => api?.restore())

describe('players store: reading a profile', () => {
  it('loads the profile of a user', async () => {
    serve()
    const store = usePlayersStore()

    await store.load('u-1')

    expect(reads()[0]!.url).toBe('/api/v1/admin/players/u-1')
    expect(store.profile?.displayName).toBe('سارا محمدی')
    expect(store.notFound).toBe(false)
    expect(store.error).toBeNull()
    expect(store.loading).toBe(false)
  })

  it('treats 404 PLAYER_NOT_FOUND as “no profile yet”, not as an error', async () => {
    serve({ read: () => ({ status: 404, body: errorEnvelope(404, 'بازیکن پیدا نشد.', 'PLAYER_NOT_FOUND') }) })
    const store = usePlayersStore()

    await store.load('u-new')

    expect(store.notFound).toBe(true)
    expect(store.profile).toBeNull()
    expect(store.error).toBeNull()
  })

  it('keeps the Persian message of any other failure', async () => {
    serve({ read: () => ({ status: 500, body: errorEnvelope(500, 'خطای سرور.') }) })
    const store = usePlayersStore()

    await store.load('u-1')

    expect(store.error).toBe('خطای سرور.')
    expect(store.notFound).toBe(false)
  })

  it('lets only the newest read write the profile', async () => {
    const slow = deferred()
    api = installFakeApi(async (request) => {
      if (request.url.endsWith('/u-old')) {
        await slow.promise
        return { status: 200, body: envelope(playerProfile({ userId: 'u-old', displayName: 'قدیمی' })) }
      }
      return { status: 200, body: envelope(playerProfile({ userId: 'u-new', displayName: 'جدید' })) }
    })
    const store = usePlayersStore()

    const first = store.load('u-old')
    await store.load('u-new')
    slow.resolve()
    await first

    expect(store.profile?.displayName).toBe('جدید')
    expect(store.userId).toBe('u-new')
  })

  it('forgets everything on reset', async () => {
    serve()
    const store = usePlayersStore()
    await store.load('u-1')

    store.reset()

    expect(store.profile).toBeNull()
    expect(store.userId).toBeNull()
  })
})

describe('players store: admin corrections', () => {
  it('corrects the gender with a trimmed reason, then reads the profile again', async () => {
    serve()
    const store = usePlayersStore()
    await store.load('u-1')
    api!.requests.length = 0

    await store.correctGender('u-1', 'Male', '  اشتباه در ثبت‌نام  ')

    expect(api!.requests.map((r) => `${r.method} ${r.url}`)).toEqual([
      'POST /api/v1/admin/players/u-1/gender',
      'GET /api/v1/admin/players/u-1',
    ])
    expect(api!.requests[0]!.body).toEqual({ gender: 'Male', reason: 'اشتباه در ثبت‌نام' })
  })

  it('removes the photo with { reason } in the DELETE body, then reads the profile again', async () => {
    serve()
    const store = usePlayersStore()
    await store.load('u-1')
    api!.requests.length = 0

    await store.removePhoto('u-1', ' عکس نامناسب ')

    expect(api!.requests.map((r) => `${r.method} ${r.url}`)).toEqual([
      'DELETE /api/v1/admin/players/u-1/photo',
      'GET /api/v1/admin/players/u-1',
    ])
    expect(api!.requests[0]!.body).toEqual({ reason: 'عکس نامناسب' })
  })

  it('rethrows a refused command with the server’s Persian message and does not reload on a validation error', async () => {
    serve({ command: () => ({ status: 400, body: errorEnvelope(400, 'دلیل را بنویسید.', 'REASON_REQUIRED') }) })
    const store = usePlayersStore()
    await store.load('u-1')
    api!.requests.length = 0

    const failure = await store.correctGender('u-1', 'Male', 'x').catch((error: unknown) => error)

    expect(getApiErrorMessage(failure)).toBe('دلیل را بنویسید.')
    expect(reads()).toHaveLength(0)
  })

  it('rethrows a 409 and reloads, because the profile on screen is stale', async () => {
    serve({ command: () => ({ status: 409, body: errorEnvelope(409, 'این بازیکن عکسی ندارد.', 'NO_PHOTO') }) })
    const store = usePlayersStore()
    await store.load('u-1')
    api!.requests.length = 0

    await expect(store.removePhoto('u-1', 'x')).rejects.toBeDefined()

    expect(reads()).toHaveLength(1)
  })
})
