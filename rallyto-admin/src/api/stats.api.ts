import apiClient from '../utils/axios'

/**
 * The admin usage dashboard (tasks 10.9). Admin-only; the client adds the bearer token and unwraps the envelope.
 * Dates are Jalali Tehran days, `yyyy/MM/dd` with ASCII digits, both ends inclusive; without them the server takes
 * the last 30 days (today included) and answers with the period it used.
 */

export interface UsageStats {
  /** The period counted, as the server resolved it. */
  from: string
  to: string
  /** Profiles created in the period. */
  signUps: number
  /** Players last active in the period. */
  activePlayers: number
  /** Public play posts created in the period. */
  posts: number
  /** Private invitations created in the period. */
  invitations: number
  /** Matches starting in the period that were confirmed (and possibly resolved since). */
  confirmedMatches: number
  /** Matches resolved in the period as Completed. */
  completedMatches: number
  /** Matches resolved in the period: Completed, Disputed or Unconfirmed. */
  resolvedMatches: number
  /** Completed ÷ resolved, 0..1 to three decimals; null when nothing was resolved. */
  completionRate: number | null
  /** Reports filed in the period. */
  reports: number
  /** Reports open now, whatever their age. */
  openReports: number
}

export interface UsageStatsQuery {
  from?: string
  to?: string
}

export const STATS_ENDPOINT = '/api/v1/admin/stats'

export const statsApi = {
  async usage(query: UsageStatsQuery = {}): Promise<UsageStats> {
    const params: Record<string, string> = {}
    const from = query.from?.trim()
    const to = query.to?.trim()
    if (from) params.from = from
    if (to) params.to = to
    const { data } = await apiClient.get<UsageStats>(STATS_ENDPOINT, { params })
    return data
  },
}
