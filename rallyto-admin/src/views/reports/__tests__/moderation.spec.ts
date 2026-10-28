import { describe, expect, it } from 'vitest'
import {
  ageOf,
  availableModerationActions,
  buildModerationRequest,
  emptyModerationForm,
  isGuid,
  prefillFromReport,
  reportedMessageIds,
  reportedPostIds,
  type ModerationForm,
} from '../moderation'
import { MATCH_ID, MESSAGE_ID, TARGET_ID, report } from '../../../api/__tests__/safetyFixtures'

const TARGET = { userId: TARGET_ID, displayName: 'علی رضایی' }
const TODAY = { year: 1405, month: 8, day: 1 }
const form = (overrides: Partial<ModerationForm> = {}): ModerationForm => ({
  ...emptyModerationForm(),
  reason: 'توهین در چت',
  ...overrides,
})

describe('actions offered for a reported player', () => {
  it.each([
    ['Active', ['Warn', 'RemovePhoto', 'HidePost', 'DeleteMessage', 'Suspend', 'Ban', 'CorrectGender']],
    ['Suspended', ['Warn', 'RemovePhoto', 'HidePost', 'DeleteMessage', 'LiftSuspension', 'Ban', 'CorrectGender']],
    ['Banned', ['RemovePhoto', 'HidePost', 'DeleteMessage']],
    ['Deleted', []],
  ] as const)('%s offers %j', (status, expected) => {
    expect(availableModerationActions(status)).toEqual(expected)
  })

  it('offers every action when the account could not be read, leaving the server to decide', () => {
    expect(availableModerationActions(null)).toHaveLength(8)
  })
})

describe('building a moderation request', () => {
  it('requires a reason for every action, and trims it', () => {
    expect(buildModerationRequest('RemovePhoto', TARGET, form({ reason: '  ' }), TODAY).errors).toEqual({
      reason: 'moderation.errors.reasonRequired',
    })
    expect(buildModerationRequest('RemovePhoto', TARGET, form({ reason: ' عکس نامناسب ' }), TODAY).request).toEqual({
      targetUserId: TARGET_ID,
      action: 'RemovePhoto',
      reason: 'عکس نامناسب',
    })
  })

  it('links the report when one is chosen', () => {
    expect(buildModerationRequest('LiftSuspension', TARGET, form({ reportId: 'r-1' }), TODAY).request).toEqual({
      targetUserId: TARGET_ID,
      action: 'LiftSuspension',
      reason: 'توهین در چت',
      reportId: 'r-1',
    })
  })

  it('needs the warning text to warn', () => {
    expect(buildModerationRequest('Warn', TARGET, form(), TODAY).errors).toEqual({
      warningText: 'moderation.errors.warningTextRequired',
    })
    expect(buildModerationRequest('Warn', TARGET, form({ warningText: ' دوباره تکرار نشود ' }), TODAY).request).toMatchObject({
      action: 'Warn',
      warningText: 'دوباره تکرار نشود',
    })
  })

  it('needs a valid match id to hide a post, and a valid message id to delete a message', () => {
    expect(buildModerationRequest('HidePost', TARGET, form({ matchId: 'abc' }), TODAY).errors).toEqual({
      matchId: 'moderation.errors.matchIdInvalid',
    })
    expect(buildModerationRequest('HidePost', TARGET, form({ matchId: ` ${MATCH_ID.toUpperCase()} ` }), TODAY).request).toMatchObject({
      matchId: MATCH_ID,
    })
    expect(buildModerationRequest('DeleteMessage', TARGET, form(), TODAY).errors).toEqual({
      messageId: 'moderation.errors.messageIdInvalid',
    })
    expect(buildModerationRequest('DeleteMessage', TARGET, form({ messageId: MESSAGE_ID }), TODAY).request).toMatchObject({
      messageId: MESSAGE_ID,
    })
  })

  it('suspends until a Jalali last day that exists and is not before today, sent as yyyy/MM/dd', () => {
    expect(buildModerationRequest('Suspend', TARGET, form({ until: '' }), TODAY).errors).toEqual({
      until: 'moderation.errors.untilInvalid',
    })
    expect(buildModerationRequest('Suspend', TARGET, form({ until: '1405/07/30' }), TODAY).errors).toEqual({
      until: 'moderation.errors.untilPast',
    })
    expect(buildModerationRequest('Suspend', TARGET, form({ until: '1405/08/01' }), TODAY).request).toMatchObject({ until: '1405/08/01' })
    expect(
      buildModerationRequest('Suspend', TARGET, form({ until: '۱۴۰۵/۰۸/۰۸', reason: 'harassment in chat' }), TODAY).request,
    ).toEqual({ targetUserId: TARGET_ID, action: 'Suspend', reason: 'harassment in chat', until: '1405/08/08' })
  })

  it('needs a gender to correct it', () => {
    expect(buildModerationRequest('CorrectGender', TARGET, form(), TODAY).errors).toEqual({ gender: 'moderation.errors.genderRequired' })
    expect(buildModerationRequest('CorrectGender', TARGET, form({ gender: 'Female' }), TODAY).request).toMatchObject({ gender: 'Female' })
  })

  it('bans only with the acknowledgement and the name typed again', () => {
    const unconfirmed = { confirm: 'moderation.errors.banUnconfirmed' }
    expect(buildModerationRequest('Ban', TARGET, form({ acknowledged: false, confirmName: 'علی رضایی' }), TODAY).errors).toEqual(unconfirmed)
    expect(buildModerationRequest('Ban', TARGET, form({ acknowledged: true, confirmName: 'علی' }), TODAY).errors).toEqual(unconfirmed)
    expect(buildModerationRequest('Ban', TARGET, form({ acknowledged: true, confirmName: ' علی  رضایی ' }), TODAY).request).toEqual({
      targetUserId: TARGET_ID,
      action: 'Ban',
      reason: 'توهین در چت',
    })
  })

  it('sends only what the action needs, whatever else the form holds', () => {
    const full = form({ warningText: 'x', matchId: MATCH_ID, messageId: MESSAGE_ID, until: '1405/08/08', gender: 'Male' })
    expect(buildModerationRequest('RemovePhoto', TARGET, full, TODAY).request).toEqual({
      targetUserId: TARGET_ID,
      action: 'RemovePhoto',
      reason: 'توهین در چت',
    })
  })
})

describe('acting on a report', () => {
  it('suggests the action the report calls for, with the id it already identifies', () => {
    expect(prefillFromReport(report({ id: 'r-p', targetType: 'Post', targetId: MATCH_ID }))).toEqual({
      action: 'HidePost',
      form: { reportId: 'r-p', matchId: MATCH_ID },
    })
    expect(prefillFromReport(report({ id: 'r-m', targetType: 'Message', targetId: MESSAGE_ID }))).toEqual({
      action: 'DeleteMessage',
      form: { reportId: 'r-m', messageId: MESSAGE_ID },
    })
    expect(prefillFromReport(report({ id: 'r-f', targetType: 'Photo' }))).toEqual({ action: 'RemovePhoto', form: { reportId: 'r-f' } })
    expect(prefillFromReport(report({ id: 'r-u', targetType: 'Player' }))).toEqual({ action: 'Warn', form: { reportId: 'r-u' } })
  })

  it('lists each reported post and message once', () => {
    const reports = [
      report({ id: '1', targetType: 'Post', targetId: MATCH_ID }),
      report({ id: '2', targetType: 'Post', targetId: MATCH_ID }),
      report({ id: '3', targetType: 'Message', targetId: MESSAGE_ID }),
      report({ id: '4', targetType: 'Player' }),
    ]
    expect(reportedPostIds(reports)).toEqual([MATCH_ID])
    expect(reportedMessageIds(reports)).toEqual([MESSAGE_ID])
  })

  it('recognises a GUID, Persian digits included', () => {
    expect(isGuid(MATCH_ID)).toBe(true)
    expect(isGuid('۴۴۴۴۴۴۴۴-4444-4444-4444-444444444444')).toBe(true)
    expect(isGuid('r-1')).toBe(false)
  })
})

describe('report age', () => {
  const now = Date.parse('2026-10-23T08:00:00Z')

  it('reads in days, else hours, else "just now"', () => {
    expect(ageOf('2026-10-20T07:00:00Z', now)).toEqual({ unit: 'days', count: 3 })
    expect(ageOf('2026-10-23T03:00:00Z', now)).toEqual({ unit: 'hours', count: 5 })
    expect(ageOf('2026-10-23T07:30:00Z', now)).toEqual({ unit: 'justNow', count: 0 })
    expect(ageOf('2026-10-23T09:00:00Z', now)).toEqual({ unit: 'justNow', count: 0 })
  })
})
