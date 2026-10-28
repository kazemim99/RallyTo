import axios from 'axios'
import apiClient, { API_BASE_URL, getApiErrorCode } from '../utils/axios'
import type { LevelTier, PlayFormat } from './sports.api'

/**
 * Player profiles as an admin sees them (community › admin players). Admin-only; the client adds the bearer token
 * and unwraps the envelope. Enum members travel as their names (`"Female"`, `"SameGender"`). Commands answer 204.
 */

export const GENDERS = ['Male', 'Female'] as const
export type Gender = (typeof GENDERS)[number]

export const PROFILE_VISIBILITIES = ['Everyone', 'SameGender'] as const
export type ProfileVisibility = (typeof PROFILE_VISIBILITIES)[number]

/** Mirrors the account: a suspended or banned account's profile is Hidden; a deleted one is anonymised. */
export const PROFILE_STATUSES = ['Active', 'Hidden', 'Deleted'] as const
export type ProfileStatus = (typeof PROFILE_STATUSES)[number]

export const EXPERIENCE_BANDS = [
  'UnderSixMonths',
  'SixToTwelveMonths',
  'OneToThreeYears',
  'ThreeToFiveYears',
  'OverFiveYears',
] as const
export type ExperienceBand = (typeof EXPERIENCE_BANDS)[number]

export const PLAY_GOALS = ['RallyPractice', 'FriendlyMatch', 'Competitive', 'Fitness'] as const
export type PlayGoal = (typeof PLAY_GOALS)[number]

export interface PlayerSport {
  sportId: string
  sportCode: string
  level: LevelTier
  /** The tier's Persian name, set by the server. */
  levelName: string
  levelDescription: string | null
  experience: ExperienceBand
  formats: PlayFormat[]
  goals: PlayGoal[]
}

export interface NamedRef {
  id: string
  name: string
}

/** The owner's view of a profile (`MyProfileView`), which is also what an admin reads. */
export interface AdminPlayerProfile {
  userId: string
  displayName: string
  /** A path on the API origin (`/media/avatars/x.jpg`); null when the player has no photo. */
  photoUrl: string | null
  gender: Gender
  /** Jalali with ASCII digits, `1375/05/10`; null when the player did not give it. */
  birthDate: string | null
  /** `18-24`, `25-34`, …, `55+`. */
  ageRange: string
  city: { id: number; name: string }
  bio: string | null
  visibility: ProfileVisibility
  status: ProfileStatus
  sports: PlayerSport[]
  homeVenues: NamedRef[]
}

export interface GenderCorrectionRequest {
  gender: Gender
  reason: string
}

export const PLAYERS_ENDPOINT = '/api/v1/admin/players'

/** The code the server answers for an account that never finished onboarding (it has no profile yet). */
export const PLAYER_NOT_FOUND = 'PLAYER_NOT_FOUND'

const playerPath = (userId: string) => `${PLAYERS_ENDPOINT}/${encodeURIComponent(userId)}`

/** The photo's address for an `<img>`: a server path is put on the API origin; an absolute URL is kept. */
export function playerPhotoSrc(photoUrl: string | null | undefined): string | null {
  if (!photoUrl) return null
  if (/^https?:\/\//i.test(photoUrl)) return photoUrl
  return `${API_BASE_URL.replace(/\/+$/, '')}/${photoUrl.replace(/^\/+/, '')}`
}

/** True when a read failed because the account has no profile yet (404 `PLAYER_NOT_FOUND`). */
export function isPlayerNotFound(error: unknown): boolean {
  if (!axios.isAxiosError(error) || error.response?.status !== 404) return false
  const code = getApiErrorCode(error)
  return code === null || code === PLAYER_NOT_FOUND
}

export const playersApi = {
  async get(userId: string): Promise<AdminPlayerProfile> {
    const { data } = await apiClient.get<AdminPlayerProfile>(playerPath(userId))
    return data
  },

  /** The player is notified of the correction. */
  async correctGender(userId: string, request: GenderCorrectionRequest): Promise<void> {
    await apiClient.post(`${playerPath(userId)}/gender`, request)
  },

  /** A DELETE with a JSON body: the reason is recorded in the audit log. */
  async removePhoto(userId: string, reason: string): Promise<void> {
    await apiClient.delete(`${playerPath(userId)}/photo`, { data: { reason } })
  },
}
