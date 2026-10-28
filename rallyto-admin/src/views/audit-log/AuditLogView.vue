<template>
  <div class="page-container" data-testid="audit-page">
    <a-page-header :title="t('navigation.auditLog')" class="page-header">
      <template #tags>
        <a-tag data-testid="audit-total">{{ t('audit.total', { total: toPersianDigits(store.totalCount) }) }}</a-tag>
      </template>
    </a-page-header>

    <a-card>
      <a-form layout="vertical" class="filters" data-testid="audit-filters">
        <a-form-item :label="t('audit.filters.adminId')" v-bind="status('adminId')">
          <a-input v-model:value="draft.adminId" dir="ltr" allow-clear class="filter-id" data-testid="audit-admin" />
        </a-form-item>
        <a-form-item :label="t('audit.filters.targetUserId')" v-bind="status('targetUserId')">
          <a-input v-model:value="draft.targetUserId" dir="ltr" allow-clear class="filter-id" data-testid="audit-target" />
        </a-form-item>
        <a-form-item :label="t('audit.filters.action')">
          <!-- Free text with the known actions offered: a new action name works before the panel knows it. -->
          <a-auto-complete
            v-model:value="draft.action"
            :options="actionOptions"
            :filter-option="filterAction"
            :placeholder="t('audit.filters.actionPlaceholder')"
            allow-clear
            class="filter-action"
            data-testid="audit-action"
          />
        </a-form-item>
        <a-form-item :label="t('audit.filters.from')" v-bind="status('from')">
          <JalaliDateInput v-model="draft.from" test-id="audit-from" />
        </a-form-item>
        <a-form-item :label="t('audit.filters.to')" v-bind="status('to')">
          <JalaliDateInput v-model="draft.to" test-id="audit-to" />
        </a-form-item>
        <a-form-item class="filter-buttons">
          <a-space wrap>
            <a-button type="primary" data-testid="audit-apply" @click="apply">{{ t('audit.filters.apply') }}</a-button>
            <a-button data-testid="audit-last7" @click="lastWeek">{{ t('audit.filters.last7Days') }}</a-button>
            <a-button data-testid="audit-reset" @click="reset">{{ t('audit.filters.reset') }}</a-button>
          </a-space>
        </a-form-item>
      </a-form>

      <a-alert v-if="store.error" class="list-alert" type="error" show-icon :message="store.error" data-testid="audit-error" />

      <a-table
        row-key="id"
        :columns="columns"
        :data-source="store.items"
        :loading="store.loading"
        :pagination="pagination"
        :locale="{ emptyText: t('audit.empty') }"
        :scroll="{ x: 1000 }"
        size="middle"
        data-testid="audit-table"
        @change="handleTableChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'at'">{{ formatDateTime(record.at) }}</template>

          <template v-else-if="column.key === 'action'">
            <div data-testid="cell-action">{{ actionLabel(record.action) }}</div>
            <div v-if="te(auditActionKey(record.action))" dir="ltr" class="mono muted">{{ record.action }}</div>
          </template>

          <template v-else-if="column.key === 'admin'">
            <span dir="ltr" class="mono" :title="record.adminId" data-testid="cell-admin">{{ shortId(record.adminId) }}</span>
          </template>

          <template v-else-if="column.key === 'target'">
            <div>
              {{ te(`audit.targetTypes.${record.targetType}`) ? t(`audit.targetTypes.${record.targetType}`) : record.targetType }}
              <span dir="ltr" class="mono" :title="record.targetId">{{ shortId(record.targetId) }}</span>
            </div>
            <router-link
              v-if="record.targetUserId"
              :to="{ name: 'ReportTarget', params: { userId: record.targetUserId } }"
              data-testid="cell-target-link"
            >
              {{ t('audit.openTarget') }}
            </router-link>
          </template>

          <template v-else-if="column.key === 'reason'">
            <span v-if="record.reason">{{ record.reason }}</span>
            <span v-else class="muted">{{ t('safety.noValue') }}</span>
          </template>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import type { TablePaginationConfig } from 'ant-design-vue'
import { KNOWN_AUDIT_ACTIONS } from '../../api/safety.api'
import JalaliDateInput from '../../components/common/JalaliDateInput.vue'
import { useAuditStore } from '../../stores/audit.store'
import { formatDateTime } from '../../utils/date'
import { toPersianDigits } from '../../utils/digits'
import { shortId } from '../reports/moderation'
import {
  auditActionKey,
  emptyAuditFilters,
  lastSevenDays,
  validateAuditFilters,
  type AuditFilterErrors,
  type AuditFilters,
} from './auditFilters'

/**
 * The admin audit log (trust-safety › Admin audit log): every admin action across the system, newest first, paged on
 * the server, with filters for the admin, the target player, the action and Jalali days (both inclusive, Tehran).
 */
const { t, te } = useI18n()
const store = useAuditStore()

const draft = reactive<AuditFilters>({ ...store.filters })
const errors = ref<AuditFilterErrors>({})

const actionLabel = (action: string) => (te(auditActionKey(action)) ? t(auditActionKey(action)) : action)

const actionOptions = computed(() =>
  KNOWN_AUDIT_ACTIONS.map((action) => ({ value: action, label: `${actionLabel(action)} (${action})` })),
)

const filterAction = (input: string, option?: { value?: unknown; label?: unknown }) => {
  const needle = input.trim().toLowerCase()
  return !needle || `${option?.label ?? ''} ${option?.value ?? ''}`.toLowerCase().includes(needle)
}

const columns = computed(() => [
  { title: t('audit.columns.at'), key: 'at', width: 150 },
  { title: t('audit.columns.action'), key: 'action', width: 220 },
  { title: t('audit.columns.admin'), key: 'admin', width: 110 },
  { title: t('audit.columns.target'), key: 'target', width: 200 },
  { title: t('audit.columns.reason'), key: 'reason' },
])

const pagination = computed<TablePaginationConfig>(() => ({
  current: store.page,
  pageSize: store.pageSize,
  total: store.totalCount,
  showSizeChanger: true,
  pageSizeOptions: ['20', '50', '100', '200'],
}))

function status(field: keyof AuditFilters) {
  const key = errors.value[field]
  return { validateStatus: key ? ('error' as const) : undefined, help: key ? t(key) : undefined }
}

function apply() {
  errors.value = validateAuditFilters(draft)
  if (Object.keys(errors.value).length > 0) return
  void store.setFilters({ ...draft, action: draft.action ?? '' })
}

function lastWeek() {
  Object.assign(draft, lastSevenDays())
  apply()
}

function reset() {
  Object.assign(draft, emptyAuditFilters())
  errors.value = {}
  void store.setFilters(emptyAuditFilters())
}

function handleTableChange(next: TablePaginationConfig) {
  void store.setPage(next.current ?? 1, next.pageSize ?? store.pageSize)
}

onMounted(() => {
  void store.fetchEntries()
})
</script>

<style scoped>
.filters {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  gap: 0 16px;
  margin-bottom: 8px;
}

.filter-id {
  width: 300px;
  max-width: 100%;
}

.filter-action {
  width: 280px;
  max-width: 100%;
}

.list-alert {
  margin-bottom: 16px;
}

.mono {
  font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
  font-size: 12px;
}

.muted {
  color: var(--ty-text-secondary);
}
</style>
