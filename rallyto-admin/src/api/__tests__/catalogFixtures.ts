import type { City, Province } from '../locations.api'
import type { Sport } from '../sports.api'
import type { PagedResult } from '../users.api'
import type { VenueCandidate } from '../venueCandidates.api'
import type { Venue, VenueSport } from '../venues.api'

/** Catalog records as the API returns them; override what the test is about. */

const levels = (): Sport['levels'] => [
  { tier: 'Beginner', order: 1, name: 'مبتدی', description: 'تازه شروع کرده' },
  { tier: 'LowerIntermediate', order: 2, name: 'متوسط رو به پایین', description: 'رالی کوتاه' },
  { tier: 'Intermediate', order: 3, name: 'متوسط', description: 'رالی پایدار' },
  { tier: 'Advanced', order: 4, name: 'پیشرفته', description: 'بازی تاکتیکی' },
  { tier: 'Professional', order: 5, name: 'حرفه‌ای', description: 'مسابقات رسمی' },
]

export const sport = (overrides: Partial<Sport> = {}): Sport => ({
  id: 's-tennis',
  code: 'tennis',
  nameFa: 'تنیس',
  nameEn: 'Tennis',
  sortOrder: 1,
  isActive: true,
  defaultSessionMinutes: 90,
  formats: [
    { format: 'Singles', playersPerSide: 1, capacity: 2 },
    { format: 'Doubles', playersPerSide: 2, capacity: 4 },
  ],
  levels: levels(),
  surfaces: ['Hard', 'Clay', 'Grass'],
  ...overrides,
})

export const SPORTS: Sport[] = [
  sport(),
  sport({
    id: 's-padel',
    code: 'padel',
    nameFa: 'پدل',
    nameEn: 'Padel',
    sortOrder: 2,
    formats: [{ format: 'Doubles', playersPerSide: 2, capacity: 4 }],
    surfaces: ['ArtificialGrass', 'Glass'],
  }),
  sport({
    id: 's-squash',
    code: 'squash',
    nameFa: 'اسکواش',
    nameEn: 'Squash',
    sortOrder: 3,
    isActive: false,
    defaultSessionMinutes: 45,
    formats: [{ format: 'Singles', playersPerSide: 1, capacity: 2 }],
    surfaces: ['Wood'],
  }),
]

export const PROVINCES: Province[] = [
  { id: 5, name: 'البرز' },
  { id: 8, name: 'اصفهان' },
]

export const CITIES: Record<number, City[]> = {
  5: [
    { id: 51, provinceId: 5, name: 'کرج', activeVenueCount: 3 },
    { id: 52, provinceId: 5, name: 'فردیس', activeVenueCount: 0 },
  ],
  8: [{ id: 81, provinceId: 8, name: 'کاشان', activeVenueCount: 1 }],
}

export const venueSport = (overrides: Partial<VenueSport> = {}): VenueSport => ({
  sportCode: 'tennis',
  courtCount: 4,
  setting: 'Outdoor',
  surface: 'Clay',
  hasLighting: true,
  ...overrides,
})

export const venue = (overrides: Partial<Venue> = {}): Venue => ({
  id: 'v-1',
  name: 'باشگاه تنیس انقلاب کرج',
  cityId: 51,
  cityName: 'کرج',
  address: 'کرج، بلوار جمهوری',
  phone: '02632000000',
  latitude: 35.83,
  longitude: 50.99,
  status: 'Active',
  googlePlaceId: null,
  sports: [venueSport()],
  tagline: null,
  description: null,
  website: null,
  instagram: null,
  telegram: null,
  workingHours: null,
  amenities: [],
  courtTypes: [],
  coverImage: null,
  images: [],
  sourceUrl: null,
  googleRating: null,
  googleReviewCount: null,
  ...overrides,
})

export const candidate = (overrides: Partial<VenueCandidate> = {}): VenueCandidate => ({
  id: 'c-1',
  cityId: 51,
  name: 'پدل کرج',
  address: 'کرج، گوهردشت',
  latitude: 35.8,
  longitude: 50.95,
  placeId: 'ChIJ-1',
  keyword: 'padel',
  status: 'Pending',
  resolvedVenueId: null,
  importedAt: '2026-10-23T08:00:00Z',
  ...overrides,
})

export const paged = <T>(items: T[], overrides: Partial<PagedResult<T>> = {}): PagedResult<T> => ({
  items,
  page: 1,
  pageSize: 20,
  totalCount: items.length,
  ...overrides,
})
