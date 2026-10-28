import apiClient from '../utils/axios'
import type { PagedResult } from './users.api'
import type { Gender } from './players.api'

/**
 * Trust and safety as an admin works it (trust-safety › Admin report queue, Admin actions, Admin audit log,
 * Disputed matches). Every route is admin-only; the client adds the bearer token and unwraps the envelope, so these
 * functions return the payload itself. Enum members travel as their names (`"Harassment"`, `"HidePost"`); instants
 * are UTC ISO-8601; Jalali days are `yyyy/MM/dd` with ASCII digits. Commands without a payload answer 204.
 */

export const REPORT_TARGET_TYPES = ['Player', 'Message', 'Post', 'Photo'] as const
export type ReportTargetType = (typeof REPORT_TARGET_TYPES)[number]

export const REPORT_REASONS = [
  'Harassment',
  'InappropriateContent',
  'FakeProfile',
  'Spam',
  'UnsafeBehaviour',
  'Underage',
  'Other',
] as const
export type ReportReason = (typeof REPORT_REASONS)[number]

export const REPORT_STATUSES = ['Open', 'Resolved', 'Dismissed'] as const
export type ReportStatus = (typeof REPORT_STATUSES)[number]

export const MODERATION_ACTIONS = [
  'Warn',
  'RemovePhoto',
  'HidePost',
  'DeleteMessage',
  'Suspend',
  'LiftSuspension',
  'Ban',
  'CorrectGender',
] as const
export type ModerationActionType = (typeof MODERATION_ACTIONS)[number]

export const RELIABILITY_TIERS = ['Unknown', 'New', 'Low', 'Good', 'High'] as const
export type ReliabilityTier = (typeof RELIABILITY_TIERS)[number]

export type AttendanceAnswer = 'Played' | 'DidNotHappen'
export type AttendanceOutcome = 'Played' | 'NoShow' | 'Contested'
export type MatchStatus =
  | 'Open'
  | 'Pending'
  | 'Confirmed'
  | 'Completed'
  | 'Disputed'
  | 'Unconfirmed'
  | 'Cancelled'
  | 'Expired'

/** The target as the reporter saw it when reporting; it survives an edit or a deletion. */
export interface ReportEvidence {
  text: string | null
  displayName: string | null
  bio: string | null
  /** A path on the API origin (put it through `playerPhotoSrc`); a photo report keeps its own copy. */
  photoUrl: string | null
  /** When the reported message was sent. */
  sentAt: string | null
}

export interface AdminReport {
  id: string
  reporterId: string
  reporterName: string
  targetType: ReportTargetType
  /** The reported thing: the player's id, the message id, or the post's match id. */
  targetId: string
  reason: ReportReason
  details: string | null
  evidence: ReportEvidence
  status: ReportStatus
  createdAt: string
}

/** One reported player in the queue, with their open reports oldest first. */
export interface ReportGroup {
  targetUserId: string
  targetName: string
  highPriority: boolean
  openReports: number
  distinctReporters: number
  oldestReportAt: string
  reports: AdminReport[]
}

export interface ModerationAction {
  id: string
  adminId: string
  targetUserId: string
  action: ModerationActionType
  reason: string
  reportId: string | null
  /** What the action applied to: the hidden match id, the deleted message id, the suspension's last day, the gender. */
  subject: string | null
  at: string
}

export interface DisputeSummary {
  /** Disputed matches the player took part in during the last 90 days. */
  count: number
  matchIds: string[]
}

export interface PrivateNote {
  ratingId: string
  matchId: string
  raterId: string
  raterName: string
  stars: number
  note: string
  submittedAt: string
}

export interface TargetDetail {
  userId: string
  displayName: string
  reliability: ReliabilityTier
  /** Every report on the player, open and closed. */
  reports: AdminReport[]
  actions: ModerationAction[]
  disputes: DisputeSummary
  privateNotes: PrivateNote[]
}

/**
 * One admin action (`POST /admin/moderation/actions`). Only the members the action needs are sent:
 * Warn → `warningText`; HidePost → `matchId`; DeleteMessage → `messageId`; Suspend → `until` (the suspension's last
 * Jalali day, `yyyy/MM/dd`, suspended through that whole Tehran day); CorrectGender → `gender`.
 */
export interface ModerationActionRequest {
  targetUserId: string
  action: ModerationActionType
  reason: string
  reportId?: string
  until?: string
  messageId?: string
  matchId?: string
  gender?: Gender
  warningText?: string
}

export interface AuditEntry {
  id: string
  adminId: string
  /** `moderation.warn`, `account.suspend`, `venue.update`, …; new ones may appear, so it stays a string. */
  action: string
  targetType: string
  targetId: string
  targetUserId: string | null
  reason: string | null
  at: string
}

export interface AuditQuery {
  adminId?: string
  targetUserId?: string
  /** An exact action name; the server does not match patterns. */
  action?: string
  /** Jalali `yyyy/MM/dd`, ASCII digits; both ends are inclusive Tehran days. */
  from?: string
  to?: string
  page?: number
  pageSize?: number
}

export interface DisputedPlayer {
  userId: string
  displayName: string
  answer: AttendanceAnswer | null
  outcome: AttendanceOutcome | null
}

export interface DisputedMatch {
  matchId: string
  status: MatchStatus
  sportId: string
  /** The match day, Jalali `yyyy/MM/dd` with ASCII digits. */
  date: string
  resolvedAt: string | null
  players: DisputedPlayer[]
}

/**
 * Every action name the server writes to the audit log today, by owning context. The list feeds the filter's
 * suggestions and the Persian labels; an entry with any other name is shown as the server sent it.
 */
export const KNOWN_AUDIT_ACTIONS = [
  'moderation.warn',
  'moderation.hide-post',
  'moderation.delete-message',
  'report.dismiss',
  'rating.remove',
  'player.correct-gender',
  'player.remove-photo',
  'account.suspend',
  'account.lift-suspension',
  'account.ban',
  'account.grant-admin',
  'account.revoke-admin',
  'sport.create',
  'sport.update',
  'sport.activate',
  'sport.deactivate',
  'venue.create',
  'venue.update',
  'venue.hide',
  'venue.unhide',
  'venue-candidate.approve',
  'venue-candidate.merge',
  'venue-candidate.reject',
  'venue-candidates.import',
  'venue-candidates.bulk-approve',
] as const

export const ADMIN_ENDPOINT = '/api/v1/admin'
export const REPORTS_ENDPOINT = `${ADMIN_ENDPOINT}/reports`
export const MODERATION_ACTIONS_ENDPOINT = `${ADMIN_ENDPOINT}/moderation/actions`
export const AUDIT_ENDPOINT = `${ADMIN_ENDPOINT}/audit`
export const DISPUTED_MATCHES_ENDPOINT = `${ADMIN_ENDPOINT}/matches/disputed`

/** Drops blank members so the query string carries only the filters actually set. */
function auditParams(query: AuditQuery): Record<string, string | number> {
  const params: Record<string, string | number> = {}
  for (const key of ['adminId', 'targetUserId', 'action', 'from', 'to'] as const) {
    const value = query[key]?.trim()
    if (value) params[key] = value
  }
  if (query.page) params.page = query.page
  if (query.pageSize) params.pageSize = query.pageSize
  return params
}

/** The request without the members left unset, so the body carries only what the action needs. */
function actionBody(request: ModerationActionRequest): ModerationActionRequest {
  return Object.fromEntries(
    Object.entries(request).filter(([, value]) => value !== undefined && value !== null && value !== ''),
  ) as unknown as ModerationActionRequest
}

export const safetyApi = {
  /** Open reports grouped by target: high priority first, then the oldest. The order is the server's. */
  async queue(): Promise<ReportGroup[]> {
    const { data } = await apiClient.get<ReportGroup[]>(REPORTS_ENDPOINT)
    return data ?? []
  },

  async target(userId: string): Promise<TargetDetail> {
    const { data } = await apiClient.get<TargetDetail>(`${REPORTS_ENDPOINT}/targets/${encodeURIComponent(userId)}`)
    return data
  },

  /** Closes the report without an action; the reason is audited. */
  async dismiss(reportId: string, reason: string): Promise<void> {
    await apiClient.post(`${REPORTS_ENDPOINT}/${encodeURIComponent(reportId)}/dismiss`, { reason })
  },

  /** Applies the action and, with `reportId`, resolves that report. */
  async act(request: ModerationActionRequest): Promise<ModerationAction> {
    const { data } = await apiClient.post<ModerationAction>(MODERATION_ACTIONS_ENDPOINT, actionBody(request))
    return data
  },

  async audit(query: AuditQuery = {}): Promise<PagedResult<AuditEntry>> {
    const { data } = await apiClient.get<PagedResult<AuditEntry>>(AUDIT_ENDPOINT, { params: auditParams(query) })
    return data
  },

  /** Disputed matches and matches with a contested no-show, newest first (at most 100). */
  async disputedMatches(): Promise<DisputedMatch[]> {
    const { data } = await apiClient.get<DisputedMatch[]>(DISPUTED_MATCHES_ENDPOINT)
    return data ?? []
  },
}
