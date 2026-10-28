import apiClient from '../utils/axios'
import type { PagedResult } from './users.api'
import type { Venue, VenueDetailsRequest, VenueSport } from './venues.api'

/**
 * The Google Places import queue (catalog › venue candidates). Each candidate is approved into a new club, merged
 * into an existing one, or rejected. Every review answers 409 CANDIDATE_ALREADY_REVIEWED when someone else got
 * there first. Admin-only.
 */

export const CANDIDATE_STATUSES = ['Pending', 'Approved', 'Merged', 'Rejected'] as const
export type CandidateStatus = (typeof CANDIDATE_STATUSES)[number]

export interface VenueCandidate {
  id: string
  cityId: number
  name: string
  address: string | null
  latitude: number | null
  longitude: number | null
  placeId: string
  /** The search keyword that found it ("padel", "باشگاه تنیس"). */
  keyword: string | null
  status: CandidateStatus
  resolvedVenueId: string | null
  /** UTC ISO-8601. */
  importedAt: string
}

export interface CandidateListQuery {
  provinceId?: number
  cityId?: number
  status?: CandidateStatus
  keyword?: string
  page?: number
  pageSize?: number
}

export type ApproveCandidateRequest = VenueDetailsRequest

export const CANDIDATES_ENDPOINT = '/api/v1/admin/venue-candidates'

export const CANDIDATE_ALREADY_REVIEWED = 'CANDIDATE_ALREADY_REVIEWED'

const candidatePath = (candidateId: string) => `${CANDIDATES_ENDPOINT}/${encodeURIComponent(candidateId)}`

function listParams(query: CandidateListQuery): Record<string, string | number> {
  const params: Record<string, string | number> = {}
  if (query.provinceId) params.provinceId = query.provinceId
  if (query.cityId) params.cityId = query.cityId
  if (query.status) params.status = query.status
  const keyword = query.keyword?.trim()
  if (keyword) params.keyword = keyword
  if (query.page) params.page = query.page
  if (query.pageSize) params.pageSize = query.pageSize
  return params
}

export const venueCandidatesApi = {
  async list(query: CandidateListQuery = {}): Promise<PagedResult<VenueCandidate>> {
    const { data } = await apiClient.get<PagedResult<VenueCandidate>>(CANDIDATES_ENDPOINT, { params: listParams(query) })
    return data
  },

  async approve(candidateId: string, request: ApproveCandidateRequest): Promise<Venue> {
    const { data } = await apiClient.post<Venue>(`${candidatePath(candidateId)}/approve`, request)
    return data
  },

  async merge(candidateId: string, venueId: string): Promise<void> {
    await apiClient.post(`${candidatePath(candidateId)}/merge`, { venueId })
  },

  async reject(candidateId: string, reason: string): Promise<void> {
    await apiClient.post(`${candidatePath(candidateId)}/reject`, { reason })
  },

  /** Approves every listed candidate with the same sports, each under its own Google name and address. */
  async bulkApprove(candidateIds: string[], sports: VenueSport[]): Promise<void> {
    await apiClient.post(`${CANDIDATES_ENDPOINT}/bulk-approve`, { candidateIds, sports })
  },
}
