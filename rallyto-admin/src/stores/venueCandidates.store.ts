import { defineStore } from 'pinia'
import {
  venueCandidatesApi,
  type ApproveCandidateRequest,
  type CandidateStatus,
  type VenueCandidate,
} from '../api/venueCandidates.api'
import type { VenueSport } from '../api/venues.api'
import { usePagedList } from './pagedList'

export interface CandidateFilters {
  provinceId: number | undefined
  cityId: number | undefined
  status: CandidateStatus | undefined
  keyword: string
}

/**
 * The import review queue: one server-side page of candidates (Pending by default) and the four reviews. Each
 * review re-reads the page on success and after a 409 (CANDIDATE_ALREADY_REVIEWED: someone else reviewed it), then
 * rethrows a failure untouched.
 */
export const useVenueCandidatesStore = defineStore('venueCandidates', () => {
  const list = usePagedList<VenueCandidate, CandidateFilters>(
    { provinceId: undefined, cityId: undefined, status: 'Pending', keyword: '' },
    (filters, page, pageSize) =>
      venueCandidatesApi.list({
        provinceId: filters.provinceId,
        cityId: filters.cityId,
        status: filters.status,
        keyword: filters.keyword,
        page,
        pageSize,
      }),
  )

  const approve = (candidateId: string, request: ApproveCandidateRequest) =>
    list.runAction(() => venueCandidatesApi.approve(candidateId, request))
  const merge = (candidateId: string, venueId: string) => list.runAction(() => venueCandidatesApi.merge(candidateId, venueId))
  const reject = (candidateId: string, reason: string) =>
    list.runAction(() => venueCandidatesApi.reject(candidateId, reason.trim()))
  const bulkApprove = (candidateIds: string[], sports: VenueSport[]) =>
    list.runAction(() => venueCandidatesApi.bulkApprove(candidateIds, sports))

  return {
    items: list.items,
    totalCount: list.totalCount,
    page: list.page,
    pageSize: list.pageSize,
    filters: list.filters,
    loading: list.loading,
    error: list.error,
    fetchCandidates: list.fetch,
    setFilters: list.setFilters,
    setPage: list.setPage,
    approve,
    merge,
    reject,
    bulkApprove,
  }
})
