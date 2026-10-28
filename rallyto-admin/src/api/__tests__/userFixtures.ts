import type { AdminAccount, PagedResult } from '../users.api'

/** An account as `GET /api/v1/admin/users` returns it; override what the test is about. */
export const account = (overrides: Partial<AdminAccount> = {}): AdminAccount => ({
  userId: 'u-1',
  phoneNumber: '+989121234567',
  roles: ['Player'],
  status: 'Active',
  suspendedUntil: null,
  statusReason: null,
  createdAt: '2026-10-01T08:00:00Z',
  ...overrides,
})

export const page = (items: AdminAccount[], overrides: Partial<PagedResult<AdminAccount>> = {}) => ({
  items,
  page: 1,
  pageSize: 20,
  totalCount: items.length,
  ...overrides,
})
