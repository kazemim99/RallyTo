import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { useVenueCandidatesStore } from '../venueCandidates.store'
import { getApiErrorCode, getApiErrorMessage } from '../../utils/axios'
import { tokenStorage } from '../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens, type FakeReply, type RecordedRequest } from '../../utils/__tests__/fakeApi'
import { candidate, paged, venue, venueSport } from '../../api/__tests__/catalogFixtures'

const LIST = '/api/v1/admin/venue-candidates'

let api: ReturnType<typeof installFakeApi> | undefined

function serve(options: { list?: (r: RecordedRequest) => FakeReply; command?: (r: RecordedRequest) => FakeReply } = {}) {
  const list = options.list ?? (() => ({ status: 200, body: envelope(paged([candidate()])) }))
  const command = options.command ?? ((r) => (r.url.endsWith('/approve') ? { status: 200, body: envelope(venue()) } : { status: 204 }))
  api = installFakeApi((request) => (request.method === 'GET' && request.url === LIST ? list(request) : command(request)))
}

const lists = () => api!.requests.filter((r) => r.method === 'GET' && r.url === LIST)

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Admin']), 'admin@rallyto.ir')
  setActivePinia(createPinia())
})
afterEach(() => api?.restore())

describe('venue candidates store', () => {
  it('starts on the Pending queue', async () => {
    serve()
    const store = useVenueCandidatesStore()

    await store.fetchCandidates()

    expect(lists()[0]!.params).toEqual({ status: 'Pending', page: 1, pageSize: 20 })
    expect(store.items).toHaveLength(1)
  })

  it('filters by province, city, status and keyword from page 1', async () => {
    serve()
    const store = useVenueCandidatesStore()
    await store.setPage(2)

    await store.setFilters({ provinceId: 5, cityId: 51, status: undefined, keyword: 'padel' })

    expect(lists().slice(-1)[0]!.params).toEqual({ provinceId: 5, cityId: 51, keyword: 'padel', page: 1, pageSize: 20 })
  })

  it.each([
    ['approve', (s: ReturnType<typeof useVenueCandidatesStore>) => s.approve('c-1', { name: 'x', address: null, phone: null, latitude: null, longitude: null, sports: [] }), `${LIST}/c-1/approve`],
    ['merge', (s: ReturnType<typeof useVenueCandidatesStore>) => s.merge('c-1', 'v-1'), `${LIST}/c-1/merge`],
    ['reject', (s: ReturnType<typeof useVenueCandidatesStore>) => s.reject('c-1', 'x'), `${LIST}/c-1/reject`],
    ['bulkApprove', (s: ReturnType<typeof useVenueCandidatesStore>) => s.bulkApprove(['c-1'], [venueSport()]), `${LIST}/bulk-approve`],
  ])('%s posts to its endpoint, then reloads the queue with its filters', async (_name, act, url) => {
    serve()
    const store = useVenueCandidatesStore()
    await store.setFilters({ cityId: 51 })
    api!.requests.length = 0

    await act(store)

    expect(api!.requests[0]).toMatchObject({ method: 'POST', url })
    expect(api!.requests[1]).toMatchObject({ method: 'GET', url: LIST, params: { cityId: 51, status: 'Pending' } })
  })

  it('trims the rejection reason', async () => {
    serve()
    const store = useVenueCandidatesStore()

    await store.reject('c-1', '  باشگاه بدنسازی  ')

    expect(api!.requests[0]!.body).toEqual({ reason: 'باشگاه بدنسازی' })
  })

  it('rethrows CANDIDATE_ALREADY_REVIEWED and reloads, because the row is stale', async () => {
    serve({ command: () => ({ status: 409, body: errorEnvelope(409, 'این مورد قبلاً بررسی شده است.', 'CANDIDATE_ALREADY_REVIEWED') }) })
    const store = useVenueCandidatesStore()

    const failure = await store.merge('c-1', 'v-1').catch((error: unknown) => error)

    expect(getApiErrorCode(failure)).toBe('CANDIDATE_ALREADY_REVIEWED')
    expect(getApiErrorMessage(failure)).toBe('این مورد قبلاً بررسی شده است.')
    expect(lists()).toHaveLength(1)
  })

  it('rethrows a validation failure without reloading', async () => {
    serve({ command: () => ({ status: 400, body: errorEnvelope(400, 'دست‌کم یک ورزش لازم است.', 'VENUE_SPORTS_REQUIRED') }) })
    const store = useVenueCandidatesStore()

    await expect(store.bulkApprove(['c-1'], [])).rejects.toBeDefined()

    expect(lists()).toHaveLength(0)
  })
})
