import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { CANDIDATES_ENDPOINT, venueCandidatesApi } from '../venueCandidates.api'
import { getApiErrorCode } from '../../utils/axios'
import { tokenStorage } from '../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens } from '../../utils/__tests__/fakeApi'
import { candidate, paged, venue, venueSport } from './catalogFixtures'

let api: ReturnType<typeof installFakeApi> | undefined

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Admin']), 'admin@rallyto.ir')
})
afterEach(() => api?.restore())

describe('admin venue candidates API contract', () => {
  it('lists at GET /api/v1/admin/venue-candidates with the filters and paging as the query', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope(paged([candidate()])) }))

    await venueCandidatesApi.list({ provinceId: 5, cityId: 51, status: 'Pending', keyword: ' padel ', page: 3, pageSize: 50 })

    expect(CANDIDATES_ENDPOINT).toBe('/api/v1/admin/venue-candidates')
    expect(api.requests[0]).toMatchObject({
      method: 'GET',
      url: CANDIDATES_ENDPOINT,
      authorization: 'Bearer access-1',
      params: { provinceId: 5, cityId: 51, status: 'Pending', keyword: 'padel', page: 3, pageSize: 50 },
    })
  })

  it('leaves blank filters out of the query', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope(paged([])) }))

    await venueCandidatesApi.list({ keyword: ' ', page: 1, pageSize: 20 })

    expect(api.requests[0]!.params).toEqual({ page: 1, pageSize: 20 })
  })

  it('approves at POST /{id}/approve with the details and returns the new venue', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope(venue({ id: 'v-new' })) }))
    const details = {
      name: 'پدل کرج',
      address: 'گوهردشت',
      phone: null,
      latitude: 35.8,
      longitude: 50.95,
      sports: [venueSport({ sportCode: 'padel' })],
    }

    const created = await venueCandidatesApi.approve('c-1', details)

    expect(api.requests[0]).toMatchObject({ method: 'POST', url: `${CANDIDATES_ENDPOINT}/c-1/approve`, body: details })
    expect(created.id).toBe('v-new')
  })

  it('merges with { venueId }, rejects with { reason }, bulk-approves with { candidateIds, sports }', async () => {
    api = installFakeApi(() => ({ status: 204 }))
    const sports = [venueSport({ sportCode: 'padel', courtCount: null })]

    await venueCandidatesApi.merge('c-1', 'v-1')
    await venueCandidatesApi.reject('c-2', 'باشگاه بدنسازی است')
    await venueCandidatesApi.bulkApprove(['c-3', 'c-4'], sports)

    expect(api.requests.map((r) => [r.method, r.url, r.body])).toEqual([
      ['POST', `${CANDIDATES_ENDPOINT}/c-1/merge`, { venueId: 'v-1' }],
      ['POST', `${CANDIDATES_ENDPOINT}/c-2/reject`, { reason: 'باشگاه بدنسازی است' }],
      ['POST', `${CANDIDATES_ENDPOINT}/bulk-approve`, { candidateIds: ['c-3', 'c-4'], sports }],
    ])
  })

  it('surfaces CANDIDATE_ALREADY_REVIEWED', async () => {
    api = installFakeApi(() => ({ status: 409, body: errorEnvelope(409, 'قبلاً بررسی شده است.', 'CANDIDATE_ALREADY_REVIEWED') }))

    const failure = await venueCandidatesApi.reject('c-1', 'x').catch((error: unknown) => error)

    expect(getApiErrorCode(failure)).toBe('CANDIDATE_ALREADY_REVIEWED')
  })
})
