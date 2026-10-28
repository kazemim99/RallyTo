<template>
  <div class="page-container" data-testid="candidates-page">
    <a-page-header :title="t('navigation.venueCandidates')" class="page-header">
      <template #tags>
        <a-tag data-testid="candidates-total">{{ t('candidates.total', { total: toPersianDigits(store.totalCount) }) }}</a-tag>
      </template>
      <template #extra>
        <a-button type="primary" :disabled="selectedRows.length === 0" data-testid="candidates-bulk" @click="bulkOpen = true">
          {{ t('candidates.bulkApprove', { count: toPersianDigits(selectedRows.length) }) }}
        </a-button>
      </template>
    </a-page-header>

    <a-card>
      <a-alert class="list-alert" type="info" show-icon :message="t('catalog.sportsEditor.laterHint')" data-testid="candidates-hint" />

      <div class="filters">
        <ProvinceCitySelect
          :province-id="store.filters.provinceId"
          :city-id="store.filters.cityId"
          allow-clear
          test-id="candidates-location"
          @change="applyLocation"
        />
        <a-select
          :value="store.filters.status"
          class="filter-status"
          allow-clear
          :options="statusOptions"
          :placeholder="t('candidates.statusPlaceholder')"
          data-testid="candidates-status"
          @change="applyStatus"
        />
        <a-input-search
          v-model:value="keyword"
          class="filter-search"
          allow-clear
          enter-button
          :placeholder="t('candidates.keywordPlaceholder')"
          data-testid="candidates-keyword"
          @search="applyKeyword"
        />
      </div>

      <a-alert v-if="store.error" class="list-alert" type="error" show-icon :message="store.error" data-testid="candidates-error" />

      <a-table
        row-key="id"
        :columns="columns"
        :data-source="store.items"
        :loading="store.loading"
        :pagination="pagination"
        :row-selection="rowSelection"
        :locale="{ emptyText: t('candidates.empty') }"
        :scroll="{ x: 1000 }"
        size="middle"
        data-testid="candidates-table"
        @change="handleTableChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'name'">
            <span class="candidate-name">{{ record.name }}</span>
          </template>

          <template v-else-if="column.key === 'address'">
            <span v-if="record.address">{{ record.address }}</span>
            <span v-else class="muted">{{ t('catalog.noValue') }}</span>
          </template>

          <template v-else-if="column.key === 'keyword'">
            <a-tag v-if="record.keyword">{{ record.keyword }}</a-tag>
            <span v-else class="muted">{{ t('catalog.noValue') }}</span>
          </template>

          <template v-else-if="column.key === 'importedAt'">
            <span data-testid="cell-imported">{{ formatDate(record.importedAt) }}</span>
          </template>

          <template v-else-if="column.key === 'status'">
            <a-tag :color="STATUS_COLORS[record.status as CandidateStatus] ?? 'default'" data-testid="cell-status">
              {{ t(`candidates.status.${record.status}`) }}
            </a-tag>
          </template>

          <template v-else-if="column.key === 'actions'">
            <a-space v-if="record.status === 'Pending'" :size="0" wrap>
              <a-button type="link" size="small" data-testid="action-approve" @click="openAction('approve', record as VenueCandidate)">
                {{ t('candidates.actions.approve') }}
              </a-button>
              <a-button type="link" size="small" data-testid="action-merge" @click="openAction('merge', record as VenueCandidate)">
                {{ t('candidates.actions.merge') }}
              </a-button>
              <a-button
                type="link"
                size="small"
                danger
                data-testid="action-reject"
                @click="openAction('reject', record as VenueCandidate)"
              >
                {{ t('candidates.actions.reject') }}
              </a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <ApproveCandidateDrawer v-model:open="dialogs.approve" :candidate="selected" />
    <MergeCandidateModal v-model:open="dialogs.merge" :candidate="selected" />
    <RejectCandidateModal v-model:open="dialogs.reject" :candidate="selected" />
    <BulkApproveModal v-model:open="bulkOpen" :candidates="selectedRows" @approved="selectedKeys = []" />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import type { TablePaginationConfig } from 'ant-design-vue'
import { CANDIDATE_STATUSES, type CandidateStatus, type VenueCandidate } from '../../api/venueCandidates.api'
import ProvinceCitySelect from '../../components/catalog/ProvinceCitySelect.vue'
import { useSportsStore } from '../../stores/sports.store'
import { useVenueCandidatesStore } from '../../stores/venueCandidates.store'
import { formatDate } from '../../utils/date'
import { toPersianDigits } from '../../utils/digits'
import ApproveCandidateDrawer from './components/ApproveCandidateDrawer.vue'
import BulkApproveModal from './components/BulkApproveModal.vue'
import MergeCandidateModal from './components/MergeCandidateModal.vue'
import RejectCandidateModal from './components/RejectCandidateModal.vue'

type CandidateAction = 'approve' | 'merge' | 'reject'

const STATUS_COLORS: Record<CandidateStatus, string> = {
  Pending: 'gold',
  Approved: 'green',
  Merged: 'blue',
  Rejected: 'default',
}

const { t } = useI18n()
const store = useVenueCandidatesStore()
const sportsStore = useSportsStore()

const keyword = ref(store.filters.keyword)
const selected = ref<VenueCandidate | null>(null)
const dialogs = reactive<Record<CandidateAction, boolean>>({ approve: false, merge: false, reject: false })
const bulkOpen = ref(false)
/** Selected row ids on the current page; only pending candidates can be selected. */
const selectedKeys = ref<string[]>([])

const selectedRows = computed(() => store.items.filter((item) => selectedKeys.value.includes(item.id)))

// After a refresh, rows that left the page or were reviewed (by this admin or another) drop out of the selection.
watch(
  () => store.items,
  (items) => {
    const pending = new Set(items.filter((item) => item.status === 'Pending').map((item) => item.id))
    selectedKeys.value = selectedKeys.value.filter((key) => pending.has(key))
  },
)

const rowSelection = computed(() => ({
  selectedRowKeys: selectedKeys.value,
  onChange: (keys: (string | number)[]) => {
    selectedKeys.value = keys.map(String)
  },
  getCheckboxProps: (record: VenueCandidate) => ({ disabled: record.status !== 'Pending' }),
}))

const statusOptions = computed(() =>
  CANDIDATE_STATUSES.map((status) => ({ value: status, label: t(`candidates.status.${status}`) })),
)

const columns = computed(() => [
  { title: t('candidates.columns.name'), key: 'name', width: 220 },
  { title: t('candidates.columns.address'), key: 'address', ellipsis: true },
  { title: t('candidates.columns.keyword'), key: 'keyword', width: 140 },
  { title: t('candidates.columns.importedAt'), key: 'importedAt', width: 120 },
  { title: t('candidates.columns.status'), key: 'status', width: 130 },
  { title: t('candidates.columns.actions'), key: 'actions', width: 190 },
])

const pagination = computed<TablePaginationConfig>(() => ({
  current: store.page,
  pageSize: store.pageSize,
  total: store.totalCount,
  showSizeChanger: true,
  pageSizeOptions: ['10', '20', '50', '100'],
}))

function applyLocation(value: { provinceId: number | undefined; cityId: number | undefined }) {
  void store.setFilters(value)
}

function applyStatus(value: unknown) {
  void store.setFilters({ status: (value as CandidateStatus | undefined) || undefined })
}

function applyKeyword() {
  void store.setFilters({ keyword: keyword.value ?? '' })
}

function handleTableChange(next: TablePaginationConfig) {
  void store.setPage(next.current ?? 1, next.pageSize ?? store.pageSize)
}

function openAction(action: CandidateAction, candidate: VenueCandidate) {
  selected.value = candidate
  dialogs[action] = true
}

onMounted(() => {
  void sportsStore.ensureLoaded()
  void store.fetchCandidates()
})
</script>

<style scoped>
.filters {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  margin-bottom: 16px;
}

.filter-search {
  width: 240px;
  max-width: 100%;
}

.filter-status {
  width: 160px;
}

.list-alert {
  margin-bottom: 16px;
}

.candidate-name {
  font-weight: 500;
}

.muted {
  color: var(--ty-text-secondary);
}
</style>
