import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { useVenuesStore } from '../venues.store'
import type { CreateVenueRequest } from '../../api/venues.api'
import { getApiErrorCode, getApiErrorMessage } from '../../utils/axios'
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
import { paged, venue, venueSport } from '../../api/__tests__/catalogFixtures'

const LIST = '/api/v1/admin/venues'

let api: ReturnType<typeof installFakeApi> | undefined

function serve(options: { list?: (r: RecordedRequest) => FakeReply; command?: (r: RecordedRequest) => FakeReply } = {}) {
  const list = options.list ?? (() => ({ status: 200, body: envelope(paged([venue()])) }))
  const command = options.command ?? (() => ({ status: 200, body: envelope(venue()) }))
  api = installFakeApi((request) => (request.method === 'GET' && request.url === LIST ? list(request) : command(request)))
}

const lists = () => api!.requests.filter((r) => r.method === 'GET' && r.url === LIST)
const lastList = () => lists()[lists().length - 1]!

const create: CreateVenueRequest = {
  cityId: 51,
  name: 'باشگاه پدل آزادی',
  address: null,
  phone: null,
  latitude: null,
  longitude: null,
  sports: [venueSport()],
  allowSimilar: false,
}

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Admin']), 'admin@rallyto.ir')
  setActivePinia(createPinia())
})
afterEach(() => api?.restore())

describe('venues store: the list', () => {
  it('loads the first page of 20 with no filters', async () => {
    serve({ list: () => ({ status: 200, body: envelope(paged([venue()], { totalCount: 42 })) }) })
    const store = useVenuesStore()

    await store.fetchVenues()

    expect(lists()[0]!.params).toEqual({ page: 1, pageSize: 20 })
    expect(store.totalCount).toBe(42)
    expect(store.error).toBeNull()
  })

  it('filters by city, name and status from page 1; the province alone narrows nothing on the server', async () => {
    serve()
    const store = useVenuesStore()
    await store.setPage(3)

    await store.setFilters({ provinceId: 5, cityId: 51, q: 'انقلاب', status: 'Hidden' })

    expect(lastList().params).toEqual({ cityId: 51, q: 'انقلاب', status: 'Hidden', page: 1, pageSize: 20 })
  })

  it('lets only the newest request write the rows', async () => {
    const slow = deferred()
    api = installFakeApi(async (request) => {
      if (request.params?.status === 'Hidden') {
        await slow.promise
        return { status: 200, body: envelope(paged([venue({ id: 'stale' })])) }
      }
      return { status: 200, body: envelope(paged([venue({ id: 'fresh' })])) }
    })
    const store = useVenuesStore()

    const first = store.setFilters({ status: 'Hidden' })
    await store.setFilters({ status: 'Active' })
    slow.resolve()
    await first

    expect(store.items.map((v) => v.id)).toEqual(['fresh'])
  })

  it('keeps the Persian message when the list cannot be loaded', async () => {
    serve({ list: () => ({ status: 500, body: errorEnvelope(500, 'خطای سرور.') }) })
    const store = useVenuesStore()

    await store.fetchVenues()

    expect(store.error).toBe('خطای سرور.')
  })
})

describe('venues store: commands', () => {
  it.each([
    ['create', (s: ReturnType<typeof useVenuesStore>) => s.create(create), 'POST', LIST],
    ['update', (s: ReturnType<typeof useVenuesStore>) => s.update('v-1', create), 'PUT', `${LIST}/v-1`],
    ['hide', (s: ReturnType<typeof useVenuesStore>) => s.hide('v-1'), 'POST', `${LIST}/v-1/hide`],
    ['unhide', (s: ReturnType<typeof useVenuesStore>) => s.unhide('v-1'), 'POST', `${LIST}/v-1/unhide`],
  ])('%s calls its endpoint, then reloads the page with its filters', async (_name, act, method, url) => {
    serve()
    const store = useVenuesStore()
    await store.setFilters({ cityId: 51 })
    api!.requests.length = 0

    await act(store)

    expect(api!.requests[0]).toMatchObject({ method, url })
    expect(api!.requests[1]).toMatchObject({ method: 'GET', url: LIST, params: { cityId: 51, page: 1, pageSize: 20 } })
  })

  it('rethrows SIMILAR_VENUE_EXISTS untouched (code and message) and reloads, as for any 409', async () => {
    serve({ command: () => ({ status: 409, body: errorEnvelope(409, 'نام مشابه وجود دارد.', 'SIMILAR_VENUE_EXISTS') }) })
    const store = useVenuesStore()

    const failure = await store.create(create).catch((error: unknown) => error)

    expect(getApiErrorCode(failure)).toBe('SIMILAR_VENUE_EXISTS')
    expect(getApiErrorMessage(failure)).toBe('نام مشابه وجود دارد.')
    expect(lists()).toHaveLength(1)
  })

  it('rethrows a validation failure without reloading', async () => {
    serve({ command: () => ({ status: 400, body: errorEnvelope(400, 'مختصات باشگاه معتبر نیست.', 'INVALID_COORDINATES') }) })
    const store = useVenuesStore()

    const failure = await store.create(create).catch((error: unknown) => error)

    expect(getApiErrorMessage(failure)).toBe('مختصات باشگاه معتبر نیست.')
    expect(lists()).toHaveLength(0)
  })

  it('finds similar names and lists a city’s clubs without touching the screen’s list', async () => {
    serve({
      command: (r) =>
        r.url === `${LIST}/similar` ? { status: 200, body: envelope([venue()]) } : { status: 404, body: errorEnvelope(404, 'x') },
    })
    const store = useVenuesStore()

    const similar = await store.findSimilar(51, 'انقلاب')
    await store.listInCity(51)

    expect(similar).toHaveLength(1)
    expect(api!.requests[0]).toMatchObject({ url: `${LIST}/similar`, params: { cityId: 51, name: 'انقلاب' } })
    expect(api!.requests[1]).toMatchObject({ url: LIST, params: { cityId: 51, page: 1, pageSize: 100 } })
    expect(store.items).toEqual([])
  })
})
