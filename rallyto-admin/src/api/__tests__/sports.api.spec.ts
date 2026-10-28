import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { SPORTS_ENDPOINT, sportsApi, type SportRequest } from '../sports.api'
import { getApiErrorMessage } from '../../utils/axios'
import { tokenStorage } from '../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens } from '../../utils/__tests__/fakeApi'
import { SPORTS, sport } from './catalogFixtures'

let api: ReturnType<typeof installFakeApi> | undefined

const request: SportRequest = {
  code: 'badminton',
  nameFa: 'بدمینتون',
  nameEn: 'Badminton',
  sortOrder: 4,
  defaultSessionMinutes: 60,
  formats: [
    { format: 'Singles', playersPerSide: 1 },
    { format: 'Doubles', playersPerSide: 2 },
  ],
  levels: [
    { tier: 'Beginner', description: 'a' },
    { tier: 'LowerIntermediate', description: 'b' },
    { tier: 'Intermediate', description: 'c' },
    { tier: 'Advanced', description: 'd' },
    { tier: 'Professional', description: 'e' },
  ],
  surfaces: ['Wood', 'Synthetic'],
}

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Admin']), 'admin@rallyto.ir')
})
afterEach(() => api?.restore())

describe('admin sports API contract', () => {
  it('lists every sport at GET /api/v1/admin/sports, as the admin', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope(SPORTS) }))

    const result = await sportsApi.list()

    expect(SPORTS_ENDPOINT).toBe('/api/v1/admin/sports')
    expect(api.requests[0]).toMatchObject({ method: 'GET', url: SPORTS_ENDPOINT, authorization: 'Bearer access-1' })
    expect(result.map((s) => s.code)).toEqual(['tennis', 'padel', 'squash'])
  })

  it('creates at POST with the full body and returns the created sport', async () => {
    api = installFakeApi(() => ({ status: 201, body: envelope(sport({ code: 'badminton' }), 201) }))

    const created = await sportsApi.create(request)

    expect(api.requests[0]).toMatchObject({ method: 'POST', url: SPORTS_ENDPOINT, body: request })
    expect(created.code).toBe('badminton')
  })

  it('updates at PUT /{id}', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope(sport()) }))

    await sportsApi.update('s-1', request)

    expect(api.requests[0]).toMatchObject({ method: 'PUT', url: `${SPORTS_ENDPOINT}/s-1`, body: request })
  })

  it('activates and deactivates at POST /{id}/activate and /{id}/deactivate', async () => {
    api = installFakeApi(() => ({ status: 204 }))

    await sportsApi.activate('s-1')
    await sportsApi.deactivate('s-1')

    expect(api.requests.map((r) => `${r.method} ${r.url}`)).toEqual([
      `POST ${SPORTS_ENDPOINT}/s-1/activate`,
      `POST ${SPORTS_ENDPOINT}/s-1/deactivate`,
    ])
  })

  it('fails with the server’s Persian message', async () => {
    api = installFakeApi(() => ({ status: 409, body: errorEnvelope(409, 'این کد قبلاً ثبت شده است.', 'SPORT_CODE_TAKEN') }))

    const failure = await sportsApi.create(request).catch((error: unknown) => error)

    expect(getApiErrorMessage(failure)).toBe('این کد قبلاً ثبت شده است.')
  })
})
