import { defineStore } from 'pinia'
import {
  venuesApi,
  type CreateVenueRequest,
  type UpdateVenueRequest,
  type Venue,
  type VenueProfileRequest,
  type VenueStatus,
} from '../api/venues.api'
import { usePagedList } from './pagedList'

export interface VenueFilters {
  /** Narrows the city list only: the venue list itself filters by city. */
  provinceId: number | undefined
  cityId: number | undefined
  q: string
  status: VenueStatus | undefined
}

/**
 * The Venues screen: one server-side page of clubs, its filters, and the commands on a club. Commands re-read the
 * page on success and after a 409; a failure is rethrown untouched (`getApiErrorMessage` gives its Persian message,
 * `getApiErrorCode` its code, such as SIMILAR_VENUE_EXISTS).
 */
export const useVenuesStore = defineStore('venues', () => {
  const list = usePagedList<Venue, VenueFilters>(
    { provinceId: undefined, cityId: undefined, q: '', status: undefined },
    (filters, page, pageSize) => venuesApi.list({ cityId: filters.cityId, q: filters.q, status: filters.status, page, pageSize }),
  )

  const create = (request: CreateVenueRequest) => list.runAction(() => venuesApi.create(request))
  const update = (venueId: string, request: UpdateVenueRequest) => list.runAction(() => venuesApi.update(venueId, request))
  const updateProfile = (venueId: string, request: VenueProfileRequest) => list.runAction(() => venuesApi.updateProfile(venueId, request))
  const addImage = (venueId: string, file: File) => list.runAction(() => venuesApi.addImage(venueId, file))
  const removeImage = (venueId: string, path: string) => list.runAction(() => venuesApi.removeImage(venueId, path))
  const hide = (venueId: string) => list.runAction(() => venuesApi.hide(venueId))
  const unhide = (venueId: string) => list.runAction(() => venuesApi.unhide(venueId))

  /** Visible clubs in the city with a name close to `name` (the drawer's duplicate warning). */
  const findSimilar = (cityId: number, name: string) => venuesApi.similar(cityId, name)

  /** Clubs of one city, for picking a merge target; does not touch the screen's list. */
  const listInCity = (cityId: number, q?: string) => venuesApi.list({ cityId, q, page: 1, pageSize: 100 })

  return {
    items: list.items,
    totalCount: list.totalCount,
    page: list.page,
    pageSize: list.pageSize,
    filters: list.filters,
    loading: list.loading,
    error: list.error,
    fetchVenues: list.fetch,
    setFilters: list.setFilters,
    setPage: list.setPage,
    create,
    update,
    updateProfile,
    addImage,
    removeImage,
    hide,
    unhide,
    findSimilar,
    listInCity,
  }
})
