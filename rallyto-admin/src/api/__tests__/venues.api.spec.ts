import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { VENUES_ENDPOINT, venueImageSrc, venuesApi, type CreateVenueRequest, type UpdateVenueRequest } from '../venues.api'
import { getApiErrorCode, getApiErrorMessage } from '../../utils/axios'
import { tokenStorage } from '../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens } from '../../utils/__tests__/fakeApi'
import { paged, venue, venueSport } from './catalogFixtures'

let api: ReturnType<typeof installFakeApi> | undefined

const body: CreateVenueRequest = {
  cityId: 51,
  name: 'باشگاه پدل آزادی',
  address: null,
  phone: '02632000000',
  latitude: null,
  longitude: null,
  sports: [venueSport({ sportCode: 'padel', courtCount: null, surface: null })],
  allowSimilar: false,
}

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Admin']), 'admin@rallyto.ir')
})
afterEach(() => api?.restore())

describe('admin venues API contract', () => {
  it('lists at GET /api/v1/admin/venues with the filters and paging as the query', async () => {
    const result = paged([venue()], { totalCount: 31, page: 2 })
    api = installFakeApi(() => ({ status: 200, body: envelope(result) }))

    const answer = await venuesApi.list({ cityId: 51, q: ' انقلاب ', status: 'Hidden', page: 2, pageSize: 20 })

    expect(VENUES_ENDPOINT).toBe('/api/v1/admin/venues')
    expect(api.requests[0]).toEqual({
      method: 'GET',
      url: VENUES_ENDPOINT,
      body: undefined,
      authorization: 'Bearer access-1',
      params: { cityId: 51, q: 'انقلاب', status: 'Hidden', page: 2, pageSize: 20 },
    })
    expect(answer).toEqual(result)
  })

  it('leaves blank filters out of the query', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope(paged([])) }))

    await venuesApi.list({ cityId: undefined, q: '  ', page: 1, pageSize: 20 })

    expect(api.requests[0]!.params).toEqual({ page: 1, pageSize: 20 })
  })

  it('reads one venue at GET /{id}', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope(venue({ id: 'v-9' })) }))

    const result = await venuesApi.get('v-9')

    expect(api.requests[0]).toMatchObject({ method: 'GET', url: `${VENUES_ENDPOINT}/v-9` })
    expect(result.id).toBe('v-9')
  })

  it('looks up similar names at GET /similar?cityId&name', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope([venue()]) }))

    const result = await venuesApi.similar(51, ' انقلاب ')

    expect(api.requests[0]).toMatchObject({
      method: 'GET',
      url: `${VENUES_ENDPOINT}/similar`,
      params: { cityId: 51, name: 'انقلاب' },
    })
    expect(result).toHaveLength(1)
  })

  it('creates at POST with allowSimilar, and updates at PUT /{id}', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope(venue()) }))

    await venuesApi.create(body)
    const update: UpdateVenueRequest = { cityId: body.cityId, name: body.name, address: body.address, phone: body.phone, latitude: null, longitude: null, sports: body.sports }
    await venuesApi.update('v-1', update)

    expect(api.requests[0]).toMatchObject({ method: 'POST', url: VENUES_ENDPOINT, body })
    expect(api.requests[1]).toMatchObject({ method: 'PUT', url: `${VENUES_ENDPOINT}/v-1`, body: update })
  })

  it('hides and unhides at POST /{id}/hide and /{id}/unhide', async () => {
    api = installFakeApi(() => ({ status: 204 }))

    await venuesApi.hide('v-1')
    await venuesApi.unhide('v-1')

    expect(api.requests.map((r) => `${r.method} ${r.url}`)).toEqual([
      `POST ${VENUES_ENDPOINT}/v-1/hide`,
      `POST ${VENUES_ENDPOINT}/v-1/unhide`,
    ])
  })

  it('surfaces SIMILAR_VENUE_EXISTS as the error code with its Persian message', async () => {
    const text = 'باشگاهی با نام مشابه در این شهر وجود دارد.'
    api = installFakeApi(() => ({ status: 409, body: errorEnvelope(409, text, 'SIMILAR_VENUE_EXISTS') }))

    const failure = await venuesApi.create(body).catch((error: unknown) => error)

    expect(getApiErrorCode(failure)).toBe('SIMILAR_VENUE_EXISTS')
    expect(getApiErrorMessage(failure)).toBe(text)
  })
})

describe('admin venue profile and photos contract', () => {
  const profile = {
    tagline: 'شعار',
    description: null,
    website: 'https://club.example.ir',
    instagram: null,
    telegram: null,
    workingHours: '۹ تا ۲۱',
    amenities: ['پارکینگ'],
    courtTypes: ['خاک رس'],
  }

  it('saves the profile at PUT /{id}/profile', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope(venue({ id: 'v-1', tagline: 'شعار' })) }))

    const result = await venuesApi.updateProfile('v-1', profile)

    expect(api.requests[0]).toMatchObject({ method: 'PUT', url: `${VENUES_ENDPOINT}/v-1/profile`, body: profile })
    expect(result.tagline).toBe('شعار')
  })

  it('uploads a photo as multipart at POST /{id}/images', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope(venue({ images: ['/media/venues/a.jpg'] })) }))

    const result = await venuesApi.addImage('v-1', new File(['x'], 'club.jpg', { type: 'image/jpeg' }))

    expect(api.requests[0]).toMatchObject({ method: 'POST', url: `${VENUES_ENDPOINT}/v-1/images` })
    expect(result.images).toEqual(['/media/venues/a.jpg'])
  })

  it('removes a photo at DELETE /{id}/images with the path as the query', async () => {
    api = installFakeApi(() => ({ status: 200, body: envelope(venue()) }))

    await venuesApi.removeImage('v-1', '/media/venues/a.jpg')

    expect(api.requests[0]).toMatchObject({ method: 'DELETE', url: `${VENUES_ENDPOINT}/v-1/images`, params: { path: '/media/venues/a.jpg' } })
  })

  it('turns a stored path into a loadable URL and leaves absolute URLs alone', () => {
    expect(venueImageSrc('/media/venues/a.jpg')).toMatch(/^https?:\/\/[^/]+\/media\/venues\/a\.jpg$/)
    expect(venueImageSrc('https://cdn.example/a.jpg')).toBe('https://cdn.example/a.jpg')
    expect(venueImageSrc(null)).toBeNull()
  })
})

