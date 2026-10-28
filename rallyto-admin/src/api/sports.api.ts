import apiClient from '../utils/axios'

/**
 * The sport catalog (catalog › admin sports). Admin-only; the client adds the bearer token and unwraps the
 * envelope. Enum members travel as their names (`"Singles"`, `"Clay"`), as the API's string enum converter writes
 * them.
 */

export const PLAY_FORMATS = ['Singles', 'Doubles'] as const
export type PlayFormat = (typeof PLAY_FORMATS)[number]

/** The five level tiers, lowest first; every sport describes all five. */
export const LEVEL_TIERS = ['Beginner', 'LowerIntermediate', 'Intermediate', 'Advanced', 'Professional'] as const
export type LevelTier = (typeof LEVEL_TIERS)[number]

export const COURT_SURFACES = ['Hard', 'Clay', 'Grass', 'ArtificialGrass', 'Carpet', 'Wood', 'Synthetic', 'Glass'] as const
export type CourtSurface = (typeof COURT_SURFACES)[number]

/** The server's bounds for the default session length, in minutes (a multiple of 15). */
export const SESSION_MINUTES = { min: 30, max: 240, step: 15 } as const

/** Lowercase ASCII letters, digits and `-`, as the server requires. */
export const SPORT_CODE_PATTERN = /^[a-z0-9-]+$/

export interface SportFormat {
  format: PlayFormat
  playersPerSide: number
  /** Players on court in this format (both sides), computed by the server. */
  capacity: number
}

export interface SportLevel {
  tier: LevelTier
  order: number
  /** The tier's Persian name, set by the server. */
  name: string
  description: string
}

export interface Sport {
  id: string
  code: string
  nameFa: string
  nameEn: string
  sortOrder: number
  isActive: boolean
  defaultSessionMinutes: number
  formats: SportFormat[]
  levels: SportLevel[]
  surfaces: CourtSurface[]
}

/** The body of create and update. On update the code is ignored: a sport's code never changes. */
export interface SportRequest {
  code: string
  nameFa: string
  nameEn: string
  sortOrder: number
  defaultSessionMinutes: number
  formats: { format: PlayFormat; playersPerSide: number }[]
  /** All five tiers, each with a description. */
  levels: { tier: LevelTier; description: string }[]
  surfaces: CourtSurface[]
}

export const SPORTS_ENDPOINT = '/api/v1/admin/sports'

const sportPath = (sportId: string) => `${SPORTS_ENDPOINT}/${encodeURIComponent(sportId)}`

export const sportsApi = {
  /** Every sport, inactive ones included. */
  async list(): Promise<Sport[]> {
    const { data } = await apiClient.get<Sport[]>(SPORTS_ENDPOINT)
    return data ?? []
  },

  async create(request: SportRequest): Promise<Sport> {
    const { data } = await apiClient.post<Sport>(SPORTS_ENDPOINT, request)
    return data
  },

  async update(sportId: string, request: SportRequest): Promise<Sport> {
    const { data } = await apiClient.put<Sport>(sportPath(sportId), request)
    return data
  },

  async activate(sportId: string): Promise<void> {
    await apiClient.post(`${sportPath(sportId)}/activate`)
  },

  async deactivate(sportId: string): Promise<void> {
    await apiClient.post(`${sportPath(sportId)}/deactivate`)
  },
}
