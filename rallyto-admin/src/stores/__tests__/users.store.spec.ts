import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { useUsersStore } from '../users.store'
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
import { account, page } from '../../api/__tests__/userFixtures'

const LIST = '/api/v1/admin/users'

let api: ReturnType<typeof installFakeApi> | undefined

/** Plays the server: the list answers `listReply`, commands answer `commandReply` (204 by default). */
function serve(options: { list?: (r: RecordedRequest) => FakeReply; command?: (r: RecordedRequest) => FakeReply } = {}) {
  const list = options.list ?? (() => ({ status: 200, body: envelope(page([account()])) }))
  const command = options.command ?? (() => ({ status: 204 }))
  api = installFakeApi((request) => (request.method === 'GET' && request.url === LIST ? list(request) : command(request)))
  return api
}

const lists = () => api!.to(LIST).filter((r) => r.method === 'GET')
const lastList = () => lists()[lists().length - 1]!

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Admin']), 'admin@rallyto.ir')
  setActivePinia(createPinia())
})
afterEach(() => api?.restore())

describe('users store: the list', () => {
  it('loads the first page of 20 with no filters', async () => {
    serve({ list: () => ({ status: 200, body: envelope(page([account(), account({ userId: 'u-2' })], { totalCount: 42 })) }) })
    const store = useUsersStore()

    await store.fetchUsers()

    expect(lists()[0]!.params).toEqual({ page: 1, pageSize: 20 })
    expect(store.items.map((a) => a.userId)).toEqual(['u-1', 'u-2'])
    expect(store.totalCount).toBe(42)
    expect(store.loading).toBe(false)
    expect(store.error).toBeNull()
  })

  it('sends the search as ASCII digits and the status, and goes back to page 1', async () => {
    serve()
    const store = useUsersStore()
    await store.setPage(3)

    await store.setFilters({ search: '۰۹۱۲ ۱۲۳', status: 'Suspended' })

    expect(lastList().params).toEqual({ search: '0912123', status: 'Suspended', page: 1, pageSize: 20 })
    expect(store.page).toBe(1)
  })

  it('pages on the server', async () => {
    serve()
    const store = useUsersStore()

    await store.setPage(2, 50)

    expect(lastList().params).toEqual({ page: 2, pageSize: 50 })
  })

  it('keeps the Persian message when the list cannot be loaded', async () => {
    serve({ list: () => ({ status: 500, body: errorEnvelope(500, 'خطای سرور.') }) })
    const store = useUsersStore()

    await store.fetchUsers()

    expect(store.error).toBe('خطای سرور.')
    expect(store.loading).toBe(false)
  })

  it('lets only the newest request write the rows', async () => {
    const slow = deferred()
    api = installFakeApi(async (request) => {
      if (request.params?.status === 'Banned') {
        await slow.promise
        return { status: 200, body: envelope(page([account({ userId: 'stale' })])) }
      }
      return { status: 200, body: envelope(page([account({ userId: 'fresh' })])) }
    })
    const store = useUsersStore()

    const first = store.setFilters({ status: 'Banned' })
    await store.setFilters({ status: 'Active' })
    slow.resolve()
    await first

    expect(store.items.map((a) => a.userId)).toEqual(['fresh'])
  })

  it('moves to the new last page when the current one emptied', async () => {
    serve({
      list: (request) =>
        request.params?.page === 3
          ? { status: 200, body: envelope(page([], { page: 3, totalCount: 40 })) }
          : { status: 200, body: envelope(page([account()], { page: 2, totalCount: 40 })) },
    })
    const store = useUsersStore()

    await store.setPage(3)

    expect(store.page).toBe(2)
    expect(store.items).toHaveLength(1)
  })
})

describe('users store: actions', () => {
  it('suspends with the instant as UTC ISO and a trimmed reason, then reloads the list', async () => {
    serve()
    const store = useUsersStore()

    await store.suspend('u-1', new Date('2026-10-30T10:00:00Z'), '  توهین  ')

    expect(api!.requests.map((r) => `${r.method} ${r.url}`)).toEqual([
      'POST /api/v1/admin/users/u-1/suspend',
      `GET ${LIST}`,
    ])
    expect(api!.requests[0]!.body).toEqual({ until: '2026-10-30T10:00:00.000Z', reason: 'توهین' })
  })

  it.each([
    ['liftSuspension', (s: ReturnType<typeof useUsersStore>) => s.liftSuspension('u-1', 'رفع'), 'POST', '/lift-suspension'],
    ['ban', (s: ReturnType<typeof useUsersStore>) => s.ban('u-1', 'تقلب'), 'POST', '/ban'],
    ['grantAdmin', (s: ReturnType<typeof useUsersStore>) => s.grantAdmin('u-1'), 'POST', '/roles/admin'],
    ['revokeAdmin', (s: ReturnType<typeof useUsersStore>) => s.revokeAdmin('u-1'), 'DELETE', '/roles/admin'],
  ])('%s calls its endpoint and reloads the current page with its filters', async (_name, act, method, suffix) => {
    serve()
    const store = useUsersStore()
    await store.setFilters({ search: '912', status: 'Active' })
    api!.requests.length = 0

    await act(store)

    expect(api!.requests[0]).toMatchObject({ method, url: `/api/v1/admin/users/u-1${suffix}` })
    expect(api!.requests[1]).toMatchObject({ method: 'GET', url: LIST, params: { search: '912', status: 'Active' } })
  })

  it('rethrows a refused action with the server’s Persian message and does not reload on a validation error', async () => {
    serve({
      command: () => ({ status: 400, body: errorEnvelope(400, 'زمان پایان تعلیق باید در آینده باشد.', 'SUSPENSION_END_IN_PAST') }),
    })
    const store = useUsersStore()

    const failure = await store.suspend('u-1', '2020-01-01T00:00:00Z', 'x').catch((error: unknown) => error)

    expect(getApiErrorMessage(failure)).toBe('زمان پایان تعلیق باید در آینده باشد.')
    expect(lists()).toHaveLength(0)
  })

  it('rethrows a 409 and reloads, because the row on screen is stale', async () => {
    serve({ command: () => ({ status: 409, body: errorEnvelope(409, 'این حساب معلق نیست.', 'ACCOUNT_NOT_SUSPENDED') }) })
    const store = useUsersStore()

    await expect(store.liftSuspension('u-1', 'x')).rejects.toBeDefined()

    expect(lists()).toHaveLength(1)
  })

  it('propagates LAST_ADMIN with its message', async () => {
    serve({ command: () => ({ status: 409, body: errorEnvelope(409, 'حداقل یک مدیر باید باقی بماند.', 'LAST_ADMIN') }) })
    const store = useUsersStore()

    const failure = await store.revokeAdmin('u-1').catch((error: unknown) => error)

    expect(getApiErrorMessage(failure)).toBe('حداقل یک مدیر باید باقی بماند.')
  })
})
