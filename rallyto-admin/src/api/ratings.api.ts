import apiClient from '../utils/axios'

/**
 * Individual ratings as an admin oversees them (player-ratings › Admin oversight of ratings). Admin-only; the
 * client adds the bearer token and unwraps the envelope. Enum members travel as their names. Removal answers 204;
 * aggregates are computed on read, so a removed rating stops counting at once.
 */

export const RATING_TAGS = ['OnTime', 'Friendly', 'FairCalls', 'GoodRally', 'Sportsmanship', 'WellOrganised'] as const
export type RatingTag = (typeof RATING_TAGS)[number]

export const LEVEL_ACCURACIES = ['Lower', 'AboutRight', 'Higher'] as const
export type LevelAccuracy = (typeof LEVEL_ACCURACIES)[number]

export interface AdminRating {
  id: string
  matchId: string
  sportId: string
  raterId: string
  raterName: string
  rateeId: string
  stars: number
  tags: RatingTag[]
  levelAccuracy: LevelAccuracy
  /** Seen only by admins. */
  privateNote: string | null
  submittedAt: string
  /** Double-blind: false until both sides rated or the window closed. */
  revealed: boolean
  /** Set once an admin removed the rating. */
  removedAt: string | null
  removalReason: string | null
}

export const ADMIN_RATINGS_ENDPOINT = '/api/v1/admin/ratings'

export const ratingsApi = {
  /** Every rating the player received, removed ones included. */
  async listForPlayer(userId: string): Promise<AdminRating[]> {
    const { data } = await apiClient.get<AdminRating[]>(`/api/v1/admin/players/${encodeURIComponent(userId)}/ratings`)
    return data ?? []
  },

  /** A DELETE with a JSON body: the reason is kept on the rating and in the audit log. */
  async remove(ratingId: string, reason: string): Promise<void> {
    await apiClient.delete(`${ADMIN_RATINGS_ENDPOINT}/${encodeURIComponent(ratingId)}`, { data: { reason } })
  },
}
