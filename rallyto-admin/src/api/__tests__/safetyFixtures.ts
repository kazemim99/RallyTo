import type {
  AdminReport,
  AuditEntry,
  DisputedMatch,
  ModerationAction,
  PrivateNote,
  ReportGroup,
  TargetDetail,
} from '../safety.api'
import type { AdminRating } from '../ratings.api'

/** Ids are GUIDs, as the server sends them. */
export const TARGET_ID = '11111111-1111-1111-1111-111111111111'
export const REPORTER_ID = '22222222-2222-2222-2222-222222222222'
export const ADMIN_ID = '33333333-3333-3333-3333-333333333333'
export const MATCH_ID = '44444444-4444-4444-4444-444444444444'
export const MESSAGE_ID = '55555555-5555-5555-5555-555555555555'

/** One report as `GET /api/v1/admin/reports` returns it; override what the test is about. */
export const report = (overrides: Partial<AdminReport> = {}): AdminReport => ({
  id: 'r-1',
  reporterId: REPORTER_ID,
  reporterName: 'بهار احمدی',
  targetType: 'Player',
  targetId: TARGET_ID,
  reason: 'Harassment',
  details: 'در چت بازی توهین کرد.',
  evidence: { text: null, displayName: 'علی رضایی', bio: 'تنیس‌باز عصرها', photoUrl: '/media/avatars/a.jpg', sentAt: null },
  status: 'Open',
  createdAt: '2026-10-20T08:00:00Z',
  ...overrides,
})

export const reportGroup = (overrides: Partial<ReportGroup> = {}): ReportGroup => ({
  targetUserId: TARGET_ID,
  targetName: 'علی رضایی',
  highPriority: false,
  openReports: 1,
  distinctReporters: 1,
  oldestReportAt: '2026-10-20T08:00:00Z',
  reports: [report()],
  ...overrides,
})

export const moderationAction = (overrides: Partial<ModerationAction> = {}): ModerationAction => ({
  id: 'a-1',
  adminId: ADMIN_ID,
  targetUserId: TARGET_ID,
  action: 'Warn',
  reason: 'توهین در چت',
  reportId: 'r-0',
  subject: null,
  at: '2026-09-01T10:00:00Z',
  ...overrides,
})

export const privateNote = (overrides: Partial<PrivateNote> = {}): PrivateNote => ({
  ratingId: 'rt-1',
  matchId: MATCH_ID,
  raterId: REPORTER_ID,
  raterName: 'بهار احمدی',
  stars: 2,
  note: 'سر امتیازها بحث کرد.',
  submittedAt: '2026-10-10T18:00:00Z',
  ...overrides,
})

export const targetDetail = (overrides: Partial<TargetDetail> = {}): TargetDetail => ({
  userId: TARGET_ID,
  displayName: 'علی رضایی',
  reliability: 'Low',
  reports: [report()],
  actions: [moderationAction()],
  disputes: { count: 2, matchIds: [MATCH_ID, '66666666-6666-6666-6666-666666666666'] },
  privateNotes: [privateNote()],
  ...overrides,
})

export const auditEntry = (overrides: Partial<AuditEntry> = {}): AuditEntry => ({
  id: 'e-1',
  adminId: ADMIN_ID,
  action: 'moderation.warn',
  targetType: 'Player',
  targetId: TARGET_ID,
  targetUserId: TARGET_ID,
  reason: 'توهین در چت',
  at: '2026-10-23T08:30:00Z',
  ...overrides,
})

export const disputedMatch = (overrides: Partial<DisputedMatch> = {}): DisputedMatch => ({
  matchId: MATCH_ID,
  status: 'Disputed',
  sportId: 's-tennis',
  date: '1405/07/28',
  resolvedAt: '2026-10-21T12:00:00Z',
  players: [
    { userId: TARGET_ID, displayName: 'علی رضایی', answer: 'Played', outcome: null },
    { userId: REPORTER_ID, displayName: 'بهار احمدی', answer: 'DidNotHappen', outcome: null },
  ],
  ...overrides,
})

/** One rating as `GET /api/v1/admin/players/{id}/ratings` returns it. */
export const adminRating = (overrides: Partial<AdminRating> = {}): AdminRating => ({
  id: 'rt-1',
  matchId: MATCH_ID,
  sportId: 's-tennis',
  raterId: REPORTER_ID,
  raterName: 'بهار احمدی',
  rateeId: TARGET_ID,
  stars: 1,
  tags: ['OnTime'],
  levelAccuracy: 'Higher',
  privateNote: 'بعد از اختلاف امتیاز بد داد.',
  submittedAt: '2026-10-10T18:00:00Z',
  revealed: true,
  removedAt: null,
  removalReason: null,
  ...overrides,
})
