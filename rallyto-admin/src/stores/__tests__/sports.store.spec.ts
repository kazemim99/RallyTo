import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { useSportsStore } from '../sports.store'
import type { SportRequest } from '../../api/sports.api'
import { getApiErrorMessage } from '../../utils/axios'
import { tokenStorage } from '../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens, type FakeReply, type RecordedRequest } from '../../utils/__tests__/fakeApi'
import { SPORTS, sport } from '../../api/__tests__/catalogFixtures'

const LIST = '/api/v1/admin/sports'

let api: ReturnType<typeof installFakeApi> | undefined

function serve(options: { list?: () => FakeReply; command?: (r: RecordedRequest) => FakeReply } = {}) {
  const list = options.list ?? (() => ({ status: 200, body: envelope(SPORTS) }))
  const command = options.command ?? (() => ({ status: 204 }))
  api = installFakeApi((request) => (request.method === 'GET' && request.url === LIST ? list() : command(request)))
}

const lists = () => api!.requests.filter((r) => r.method === 'GET' && r.url === LIST)

const request: SportRequest = {
  code: 'badminton',
  nameFa: 'بدمینتون',
  nameEn: 'Badminton',
  sortOrder: 4,
  defaultSessionMinutes: 60,
  formats: [{ format: 'Singles', playersPerSide: 1 }],
  levels: [],
  surfaces: [],
}

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Admin']), 'admin@rallyto.ir')
  setActivePinia(createPinia())
})
afterEach(() => api?.restore())

describe('sports store', () => {
  it('loads every sport in sort order and indexes them by code', async () => {
    serve({ list: () => ({ status: 200, body: envelope([...SPORTS].reverse()) }) })
    const store = useSportsStore()

    await store.fetchSports()

    expect(store.items.map((s) => s.code)).toEqual(['tennis', 'padel', 'squash'])
    expect(store.activeSports.map((s) => s.code)).toEqual(['tennis', 'padel'])
    expect(store.byCode.get('padel')?.nameFa).toBe('پدل')
    expect(store.loaded).toBe(true)
  })

  it('loads once for the venue screens, however many ask at the same time', async () => {
    serve()
    const store = useSportsStore()

    await Promise.all([store.ensureLoaded(), store.ensureLoaded()])
    await store.ensureLoaded()

    expect(lists()).toHaveLength(1)
  })

  it('keeps the Persian message when the list cannot be loaded', async () => {
    serve({ list: () => ({ status: 500, body: errorEnvelope(500, 'خطای سرور.') }) })
    const store = useSportsStore()

    await store.fetchSports()

    expect(store.error).toBe('خطای سرور.')
    expect(store.loading).toBe(false)
  })

  it.each([
    ['create', (s: ReturnType<typeof useSportsStore>) => s.create(request), 'POST', LIST],
    ['update', (s: ReturnType<typeof useSportsStore>) => s.update('s-1', request), 'PUT', `${LIST}/s-1`],
    ['activate', (s: ReturnType<typeof useSportsStore>) => s.activate('s-1'), 'POST', `${LIST}/s-1/activate`],
    ['deactivate', (s: ReturnType<typeof useSportsStore>) => s.deactivate('s-1'), 'POST', `${LIST}/s-1/deactivate`],
  ])('%s calls its endpoint, then reloads the list', async (_name, act, method, url) => {
    serve({ command: (r) => (r.method === 'POST' && r.url === LIST ? { status: 201, body: envelope(sport()) } : { status: 200, body: envelope(sport()) }) })
    const store = useSportsStore()

    await act(store)

    expect(api!.requests.map((r) => `${r.method} ${r.url}`)).toEqual([`${method} ${url}`, `GET ${LIST}`])
  })

  it('rethrows a validation failure with its message and does not reload', async () => {
    serve({ command: () => ({ status: 400, body: errorEnvelope(400, 'توضیح هر پنج سطح لازم است.', 'LEVELS_INCOMPLETE') }) })
    const store = useSportsStore()

    const failure = await store.create(request).catch((error: unknown) => error)

    expect(getApiErrorMessage(failure)).toBe('توضیح هر پنج سطح لازم است.')
    expect(lists()).toHaveLength(0)
  })

  it('rethrows a 409 and reloads', async () => {
    serve({ command: () => ({ status: 409, body: errorEnvelope(409, 'این کد قبلاً ثبت شده است.', 'SPORT_CODE_TAKEN') }) })
    const store = useSportsStore()

    await expect(store.create(request)).rejects.toBeDefined()

    expect(lists()).toHaveLength(1)
  })
})
