import { defineStore } from 'pinia'
import { safetyApi, type AuditEntry } from '../api/safety.api'
import { emptyAuditFilters, toAuditQuery, type AuditFilters } from '../views/audit-log/auditFilters'
import { usePagedList } from './pagedList'

/**
 * The admin audit log: one server-side page of entries, newest first, with the filters the screen applied. The
 * screen validates the filters before it sets them; the store only turns them into the query. Read-only.
 */
export const useAuditStore = defineStore('audit', () => {
  const list = usePagedList<AuditEntry, AuditFilters>(emptyAuditFilters(), (filters, page, pageSize) =>
    safetyApi.audit({ ...toAuditQuery({ ...filters }), page, pageSize }),
  )

  return {
    items: list.items,
    totalCount: list.totalCount,
    page: list.page,
    pageSize: list.pageSize,
    filters: list.filters,
    loading: list.loading,
    error: list.error,
    fetchEntries: list.fetch,
    setFilters: list.setFilters,
    setPage: list.setPage,
  }
})
