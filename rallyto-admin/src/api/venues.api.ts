import apiClient, { API_BASE_URL } from '../utils/axios'
import type { CourtSurface } from './sports.api'
import type { PagedResult } from './users.api'

/**
 * The club catalog (catalog › admin venues). Clubs have no accounts: only the Rallyto team enters them, by hand
 * here or by approving a Google Places candidate. Admin-only.
 */

export const COURT_SETTINGS = ['Indoor', 'Outdoor', 'Both'] as const
export type CourtSetting = (typeof COURT_SETTINGS)[number]

/** What a sport newly added to a club starts with: the setting is required, the other court details may wait. */
export const DEFAULT_COURT_SETTING: CourtSetting = 'Outdoor'

export const VENUE_STATUSES =['Active', 'Hidden'] as const
export type VenueStatus = (typeof VENUE_STATUSES)[number]

/** The server's bounds for a court count; null means "not known yet". */
export const COURT_COUNT = { min: 1, max: 100 } as const

/** One sport a club offers. The same shape is read and written. */
export interface VenueSport {
  sportCode: string
  courtCount: number | null
  setting: CourtSetting
  surface: CourtSurface | null
  hasLighting: boolean
}

export interface Venue {
  id: string
  name: string
  cityId: number
  cityName: string
  address: string | null
  phone: string | null
  latitude: number | null
  longitude: number | null
  status: VenueStatus
  /** Set when the club came from the Google Places import. */
  googlePlaceId: string | null
  sports: VenueSport[]
  tagline: string | null
  description: string | null
  website: string | null
  instagram: string | null
  telegram: string | null
  workingHours: string | null
  amenities: string[]
  courtTypes: string[]
  /** A path on the API origin (`/media/venues/x.jpg`); the first photo. Null when there is none. */
  coverImage: string | null
  /** Photo paths in display order; the first is the cover. */
  images: string[]
  /** Where an imported club was listed (for Google places, its Google Maps page). */
  sourceUrl: string | null
  /** Google Maps rating (1–5) and its review count; null when Google has none. */
  googleRating: number | null
  googleReviewCount: number | null
}

/** What the profile drawer edits. Links must start with http:// or https://; the server refuses anything else. */
export interface VenueProfileRequest {
  tagline: string | null
  description: string | null
  website: string | null
  instagram: string | null
  telegram: string | null
  workingHours: string | null
  amenities: string[]
  courtTypes: string[]
}

/** The most photos a club can hold (the server's bound). */
export const MAX_VENUE_IMAGES = 20

/** A venue photo path as a URL the browser can load. */
export function venueImageSrc(path: string | null | undefined): string | null {
  if (!path) return null
  if (/^https?:\/\//i.test(path)) return path
  return `${API_BASE_URL.replace(/\/+$/, '')}/${path.replace(/^\/+/, '')}`
}

/** The editable details shared by create, update and candidate approval. */
export interface VenueDetailsRequest {
  name: string
  address: string | null
  phone: string | null
  /** Both or neither. */
  latitude: number | null
  longitude: number | null
  sports: VenueSport[]
}

export interface CreateVenueRequest extends VenueDetailsRequest {
  cityId: number
  /** False first: the server refuses with SIMILAR_VENUE_EXISTS when a club with a similar name is in the city. */
  allowSimilar: boolean
}

/** The city of a club never changes; the update body carries it for symmetry and the server ignores it. */
export interface UpdateVenueRequest extends VenueDetailsRequest {
  cityId: number
}

export interface VenueListQuery {
  cityId?: number
  /** Part of the name; omitted when blank. */
  q?: string
  status?: VenueStatus
  page?: number
  pageSize?: number
}

export const VENUES_ENDPOINT = '/api/v1/admin/venues'

/** The 409 code of a create whose name is close to a club already in the city. */
export const SIMILAR_VENUE_EXISTS = 'SIMILAR_VENUE_EXISTS'

const venuePath = (venueId: string) => `${VENUES_ENDPOINT}/${encodeURIComponent(venueId)}`

function listParams(query: VenueListQuery): Record<string, string | number> {
  const params: Record<string, string | number> = {}
  if (query.cityId) params.cityId = query.cityId
  const q = query.q?.trim()
  if (q) params.q = q
  if (query.status) params.status = query.status
  if (query.page) params.page = query.page
  if (query.pageSize) params.pageSize = query.pageSize
  return params
}

export const venuesApi = {
  async list(query: VenueListQuery = {}): Promise<PagedResult<Venue>> {
    const { data } = await apiClient.get<PagedResult<Venue>>(VENUES_ENDPOINT, { params: listParams(query) })
    return data
  },

  async get(venueId: string): Promise<Venue> {
    const { data } = await apiClient.get<Venue>(venuePath(venueId))
    return data
  },

  /** Visible clubs in the city whose name is close to `name`. */
  async similar(cityId: number, name: string): Promise<Venue[]> {
    const { data } = await apiClient.get<Venue[]>(`${VENUES_ENDPOINT}/similar`, { params: { cityId, name: name.trim() } })
    return data ?? []
  },

  async create(request: CreateVenueRequest): Promise<Venue> {
    const { data } = await apiClient.post<Venue>(VENUES_ENDPOINT, request)
    return data
  },

  async update(venueId: string, request: UpdateVenueRequest): Promise<Venue> {
    const { data } = await apiClient.put<Venue>(venuePath(venueId), request)
    return data
  },

  async updateProfile(venueId: string, request: VenueProfileRequest): Promise<Venue> {
    const { data } = await apiClient.put<Venue>(`${venuePath(venueId)}/profile`, request)
    return data
  },

  /** Appends a JPEG, PNG or WebP photo (up to 10 MB); the server checks the bytes, not the name. */
  async addImage(venueId: string, file: File): Promise<Venue> {
    const form = new FormData()
    form.append('file', file)
    const { data } = await apiClient.post<Venue>(`${venuePath(venueId)}/images`, form)
    return data
  },

  async removeImage(venueId: string, path: string): Promise<Venue> {
    const { data } = await apiClient.delete<Venue>(`${venuePath(venueId)}/images`, { params: { path } })
    return data
  },

  async hide(venueId: string): Promise<void> {
    await apiClient.post(`${venuePath(venueId)}/hide`)
  },

  async unhide(venueId: string): Promise<void> {
    await apiClient.post(`${venuePath(venueId)}/unhide`)
  },
}
