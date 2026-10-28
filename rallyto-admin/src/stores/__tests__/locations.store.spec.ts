import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { useLocationsStore } from '../locations.store'
import { tokenStorage } from '../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens } from '../../utils/__tests__/fakeApi'
import { CITIES, PROVINCES } from '../../api/__tests__/catalogFixtures'

let api: ReturnType<typeof installFakeApi> | undefined

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Admin']), 'admin@rallyto.ir')
  setActivePinia(createPinia())
})
afterEach(() => api?.restore())

describe('locations store', () => {
  it('requests provinces once and serves them from the cache after that', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope(PROVINCES) }))
    const store = useLocationsStore()

    await Promise.all([store.loadProvinces(), store.loadProvinces()])
    await store.loadProvinces()

    expect(api.requests).toHaveLength(1)
    expect(store.provinces).toEqual(PROVINCES)
  })

  it('caches the cities of each province separately', async () => {
    api = installFakeApi((r) => {
      const id = Number(r.url.split('/')[4])
      return { status: 200, body: envelope(CITIES[id]) }
    })
    const store = useLocationsStore()

    await store.loadCities(5)
    await store.loadCities(8)
    await store.loadCities(5)

    expect(api.requests.map((r) => r.url)).toEqual(['/api/v1/provinces/5/cities', '/api/v1/provinces/8/cities'])
    expect(store.citiesOf(5).map((c) => c.name)).toEqual(['کرج', 'فردیس'])
    expect(store.cityName(81)).toBe('کاشان')
    expect(store.citiesOf(undefined)).toEqual([])
  })

  it('forgets a failed request so the next call tries again', async () => {
    let fail = true
    api = installFakeApi(() => (fail ? { status: 500, body: errorEnvelope(500, 'خطا') } : { status: 200, body: envelope(PROVINCES) }))
    const store = useLocationsStore()

    await expect(store.loadProvinces()).rejects.toBeDefined()
    fail = false
    await store.loadProvinces()

    expect(api.requests).toHaveLength(2)
    expect(store.provinces).toHaveLength(2)
  })
})
