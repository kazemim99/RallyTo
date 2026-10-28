import type { AccountStatus } from '../../api/users.api'
import type { Gender } from '../../api/players.api'
import {
  MODERATION_ACTIONS,
  type AdminReport,
  type ModerationActionRequest,
  type ModerationActionType,
  type ReliabilityTier,
} from '../../api/safety.api'
import { compareJalaliDays, formatJalaliDay, parseJalaliDay, type JalaliDay } from '../../utils/date'
import { toAsciiDigits } from '../../utils/digits'

/**
 * The rules behind the moderation screens, kept out of the components so they can be tested on their own: which
 * actions a target's account allows, what each action's dialog must collect, and the request it sends.
 */

const GUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

/** A pasted or typed id: trimmed, with Persian digits made ASCII. */
export const normaliseId = (value: string | null | undefined) => toAsciiDigits(value ?? '').trim()

export const isGuid = (value: string | null | undefined) => GUID.test(normaliseId(value))

/**
 * The actions offered for a target, given their account's status; the others are not offered at all.
 * - Active: everything but lifting a suspension.
 * - Suspended: everything but a new suspension (lift it, or ban).
 * - Banned: only content clean-up (photo, post, message).
 * - Deleted: nothing.
 * - Unknown (the account could not be read): everything; the server stays the authority.
 */
export function availableModerationActions(status: AccountStatus | null | undefined): ModerationActionType[] {
  switch (status) {
    case 'Active':
      return MODERATION_ACTIONS.filter((action) => action !== 'LiftSuspension')
    case 'Suspended':
      return MODERATION_ACTIONS.filter((action) => action !== 'Suspend')
    case 'Banned':
      return ['RemovePhoto', 'HidePost', 'DeleteMessage']
    case 'Deleted':
      return []
    default:
      return [...MODERATION_ACTIONS]
  }
}

/** Actions that change the account, drawn as dangerous. */
export const DANGEROUS_ACTIONS: ReadonlySet<ModerationActionType> = new Set(['Suspend', 'Ban'])

/** What an action dialog collects. Blank members are simply not used by actions that do not need them. */
export interface ModerationForm {
  reason: string
  /** The report the action resolves; empty for none. */
  reportId: string
  warningText: string
  matchId: string
  messageId: string
  /** The suspension's last Jalali day, `yyyy/MM/dd`; empty until chosen. */
  until: string
  gender: Gender | null
  /** Ban only: the admin ticked "this is permanent". */
  acknowledged: boolean
  /** Ban only: the target's display name, typed again. */
  confirmName: string
}

export type ModerationField = 'reason' | 'warningText' | 'matchId' | 'messageId' | 'until' | 'gender' | 'confirm'

/** Field → i18n key of the problem. */
export type ModerationErrors = Partial<Record<ModerationField, string>>

export const emptyModerationForm = (): ModerationForm => ({
  reason: '',
  reportId: '',
  warningText: '',
  matchId: '',
  messageId: '',
  until: '',
  gender: null,
  acknowledged: false,
  confirmName: '',
})

export type BuildResult = { request: ModerationActionRequest; errors: null } | { request: null; errors: ModerationErrors }

/** The name typed to confirm a ban matches, ignoring outer and repeated spaces. */
export const sameName = (a: string, b: string) => a.trim().replace(/\s+/g, ' ') === b.trim().replace(/\s+/g, ' ')

/**
 * Checks the dialog and builds the request. Every action needs a reason; besides that:
 * Warn needs the warning text; HidePost a match id; DeleteMessage a message id; Suspend a last day that exists and
 * is not before today (Tehran); CorrectGender a gender; Ban both the acknowledgement and the name typed again.
 */
export function buildModerationRequest(
  action: ModerationActionType,
  target: { userId: string; displayName: string },
  form: ModerationForm,
  today: JalaliDay,
): BuildResult {
  const errors: ModerationErrors = {}
  const reason = form.reason.trim()
  if (!reason) errors.reason = 'moderation.errors.reasonRequired'

  const request: ModerationActionRequest = { targetUserId: target.userId, action, reason }
  const reportId = form.reportId.trim()
  if (reportId) request.reportId = reportId

  switch (action) {
    case 'Warn': {
      const text = form.warningText.trim()
      if (!text) errors.warningText = 'moderation.errors.warningTextRequired'
      else request.warningText = text
      break
    }
    case 'HidePost':
      if (!isGuid(form.matchId)) errors.matchId = 'moderation.errors.matchIdInvalid'
      else request.matchId = normaliseId(form.matchId).toLowerCase()
      break
    case 'DeleteMessage':
      if (!isGuid(form.messageId)) errors.messageId = 'moderation.errors.messageIdInvalid'
      else request.messageId = normaliseId(form.messageId).toLowerCase()
      break
    case 'Suspend': {
      const day = parseJalaliDay(form.until)
      if (!day) errors.until = 'moderation.errors.untilInvalid'
      else if (compareJalaliDays(day, today) < 0) errors.until = 'moderation.errors.untilPast'
      else request.until = formatJalaliDay(day)
      break
    }
    case 'CorrectGender':
      if (!form.gender) errors.gender = 'moderation.errors.genderRequired'
      else request.gender = form.gender
      break
    case 'Ban':
      if (!form.acknowledged || !sameName(form.confirmName, target.displayName)) errors.confirm = 'moderation.errors.banUnconfirmed'
      break
    default:
      break
  }

  return Object.keys(errors).length > 0 ? { request: null, errors } : { request, errors: null }
}

/** The action a report most likely calls for, with the member the report already identifies. */
export function prefillFromReport(report: AdminReport): { action: ModerationActionType; form: Partial<ModerationForm> } {
  switch (report.targetType) {
    case 'Post':
      return { action: 'HidePost', form: { reportId: report.id, matchId: report.targetId } }
    case 'Message':
      return { action: 'DeleteMessage', form: { reportId: report.id, messageId: report.targetId } }
    case 'Photo':
      return { action: 'RemovePhoto', form: { reportId: report.id } }
    default:
      return { action: 'Warn', form: { reportId: report.id } }
  }
}

const unique = (values: string[]) => [...new Set(values)]

/** The match ids of the target's reported posts, for the "hide post" dialog to offer. */
export const reportedPostIds = (reports: AdminReport[]) =>
  unique(reports.filter((r) => r.targetType === 'Post').map((r) => r.targetId))

/** The ids of the target's reported messages, for the "delete message" dialog to offer. */
export const reportedMessageIds = (reports: AdminReport[]) =>
  unique(reports.filter((r) => r.targetType === 'Message').map((r) => r.targetId))

/** How long ago, in whole days, else whole hours, else "just now"; never negative. */
export function ageOf(instant: string, now: number = Date.now()): { unit: 'days' | 'hours' | 'justNow'; count: number } {
  const elapsed = Math.max(0, now - new Date(instant).getTime())
  const hours = Math.floor(elapsed / 3_600_000)
  if (hours >= 24) return { unit: 'days', count: Math.floor(hours / 24) }
  if (hours >= 1) return { unit: 'hours', count: hours }
  return { unit: 'justNow', count: 0 }
}

export const RELIABILITY_COLORS: Record<ReliabilityTier, string> = {
  Unknown: 'default',
  New: 'blue',
  Low: 'red',
  Good: 'green',
  High: 'cyan',
}

export const REPORT_STATUS_COLORS: Record<string, string> = {
  Open: 'orange',
  Resolved: 'green',
  Dismissed: 'default',
}

/** High-priority reasons, highlighted on a report (spec trust-safety › Admin report queue). */
export const HIGH_PRIORITY_REASONS: ReadonlySet<string> = new Set(['Harassment', 'Underage'])

/** The first block of a GUID, for a table cell; the full id goes in the cell's title. */
export const shortId = (id: string | null | undefined) => (id ? id.split('-')[0]! : '')
