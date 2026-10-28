import type { VenueDetailsRequest, VenueSport } from '../../api/venues.api'
import { toAsciiDigits } from '../../utils/digits'

/**
 * The editable details of a club, shared by the venue drawer and the candidate approval drawer: the form state,
 * its client-side checks (the server stays the authority), and the request body built from it.
 */
export interface VenueFormState {
  name: string
  address: string
  phone: string
  latitude: number | null
  longitude: number | null
  sports: VenueSport[]
}

/** How long the name must rest before the similar-name lookup runs. */
export const SIMILAR_LOOKUP_DELAY_MS = 400

/** A name shorter than this is not looked up: every club would look similar. */
export const SIMILAR_LOOKUP_MIN_LENGTH = 2

export const emptyVenueForm = (): VenueFormState => ({
  name: '',
  address: '',
  phone: '',
  latitude: null,
  longitude: null,
  sports: [],
})

export type VenueFormErrors = Partial<Record<'name' | 'coordinates' | 'sports', string>>

type Translate = (key: string) => string

export function validateVenueForm(form: VenueFormState, t: Translate): VenueFormErrors {
  const errors: VenueFormErrors = {}
  if (!form.name.trim()) errors.name = t('venues.form.nameRequired')
  if ((form.latitude === null) !== (form.longitude === null)) errors.coordinates = t('venues.form.coordinatesIncomplete')
  if (form.sports.length === 0) errors.sports = t('catalog.sportsEditor.required')
  return errors
}

const blankToNull = (value: string) => (value.trim() ? value.trim() : null)

export function toVenueDetails(form: VenueFormState): VenueDetailsRequest {
  return {
    name: form.name.trim(),
    address: blankToNull(form.address),
    phone: blankToNull(toAsciiDigits(form.phone)),
    latitude: form.latitude ?? null,
    longitude: form.longitude ?? null,
    sports: form.sports.map((sport) => ({ ...sport })),
  }
}
