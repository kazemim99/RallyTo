import type { UsageStats } from '../stats.api'

/** The figures as `GET /api/v1/admin/stats` returns them. */
export const usageStats = (overrides: Partial<UsageStats> = {}): UsageStats => ({
  from: '1405/07/02',
  to: '1405/08/01',
  signUps: 1234,
  activePlayers: 560,
  posts: 87,
  invitations: 12,
  confirmedMatches: 40,
  completedMatches: 20,
  resolvedMatches: 30,
  completionRate: 0.667,
  reports: 9,
  openReports: 4,
  ...overrides,
})
