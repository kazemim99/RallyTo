import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { PROVINCES_ENDPOINT, locationsApi } from '../locations.api'
import { tokenStorage } from '../../utils/token-storage'
import { envelope, installFakeApi, tokens } from '../../utils/__tests__/fakeApi'
import { CITIES, PROVINCES } from './catalogFixtures'

let api: ReturnType<typeof installFakeApi> | undefined

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Admin']), 'admin@rallyto.ir')
})
afterEach(() => api?.restore())

describe('locations API contract', () => {
  it('lists provinces at GET /api/v1/provinces', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope(PROVINCES) }))

    const result = await locationsApi.provinces()

    expect(PROVINCES_ENDPOINT).toBe('/api/v1/provinces')
    expect(api.requests[0]).toMatchObject({ method: 'GET', url: '/api/v1/provinces', authorization: 'Bearer access-1' })
    expect(result).toEqual(PROVINCES)
  })

  it('lists a province’s cities at GET /api/v1/provinces/{id}/cities', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope(CITIES[5]) }))

    const result = await locationsApi.cities(5)

    expect(api.requests[0]).toMatchObject({ method: 'GET', url: '/api/v1/provinces/5/cities' })
    expect(result.map((c) => c.name)).toEqual(['کرج', 'فردیس'])
  })
})
