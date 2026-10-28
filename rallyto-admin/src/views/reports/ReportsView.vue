<template>
  <div class="page-container" data-testid="reports-page">
    <a-page-header :title="t('navigation.reports')" class="page-header">
      <template #tags>
        <a-tag data-testid="reports-total">{{ t('reports.total', { total: toPersianDigits(store.groups.length) }) }}</a-tag>
      </template>
      <template #extra>
        <a-button :loading="store.loading" data-testid="reports-refresh" @click="store.fetchQueue()">
          <template #icon><ReloadOutlined /></template>
          {{ t('safety.refresh') }}
        </a-button>
      </template>
    </a-page-header>

    <a-card>
      <a-alert v-if="store.error" class="list-alert" type="error" show-icon :message="store.error" data-testid="reports-error" />

      <!-- The order is the server's: high priority first, then the oldest report. -->
      <a-table
        row-key="targetUserId"
        :columns="columns"
        :data-source="store.groups"
        :loading="store.loading"
        :pagination="false"
        :locale="{ emptyText: t('reports.empty') }"
        :scroll="{ x: 900 }"
        size="middle"
        data-testid="reports-table"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'target'">
            <a class="target-name" data-testid="group-target" @click="openTarget(record as ReportGroup)">{{ record.targetName }}</a>
          </template>

          <template v-else-if="column.key === 'priority'">
            <a-tag v-if="record.highPriority" color="red" data-testid="group-priority">
              <template #icon><FireOutlined /></template>
              {{ t('reports.priority.high') }}
            </a-tag>
            <a-tag v-else data-testid="group-priority">{{ t('reports.priority.normal') }}</a-tag>
          </template>

          <template v-else-if="column.key === 'openReports'">
            <span data-testid="group-open">{{ toPersianDigits(record.openReports) }}</span>
          </template>

          <template v-else-if="column.key === 'reporters'">
            <span data-testid="group-reporters">{{ toPersianDigits(record.distinctReporters) }}</span>
          </template>

          <template v-else-if="column.key === 'oldest'">
            <a-tooltip :title="formatDateTime(record.oldestReportAt)">
              <span data-testid="group-oldest">{{ ageText(record.oldestReportAt) }}</span>
            </a-tooltip>
          </template>

          <template v-else-if="column.key === 'actions'">
            <a-button type="link" size="small" data-testid="group-open-detail" @click="openTarget(record as ReportGroup)">
              {{ t('reports.openDetail') }}
            </a-button>
          </template>
        </template>

        <template #expandedRowRender="{ record }">
          <div :data-testid="`group-reports-${record.targetUserId}`">
            <ReportCard v-for="report in (record as ReportGroup).reports" :key="report.id" :report="report">
              <template #actions>
                <a-button size="small" :data-testid="`report-dismiss-${report.id}`" @click="openDismiss(report)">
                  {{ t('reports.dismiss.action') }}
                </a-button>
                <a-button size="small" type="primary" ghost @click="openTarget(record as ReportGroup)">
                  {{ t('reports.openDetail') }}
                </a-button>
              </template>
            </ReportCard>
          </div>
        </template>
      </a-table>
    </a-card>

    <DismissReportModal v-model:open="dismissOpen" :report="dismissing" :dismiss="store.dismiss" />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { FireOutlined, ReloadOutlined } from '@ant-design/icons-vue'
import type { AdminReport, ReportGroup } from '../../api/safety.api'
import { useReportsStore } from '../../stores/reports.store'
import { formatDateTime } from '../../utils/date'
import { toPersianDigits } from '../../utils/digits'
import ReportCard from './components/ReportCard.vue'
import DismissReportModal from './components/DismissReportModal.vue'
import { ageOf } from './moderation'

/**
 * The report queue (trust-safety › Admin report queue): open reports grouped by the reported player, in the
 * server's order. Each group expands to its reports with the evidence; a report can be dismissed here, and every
 * other action is taken from the player's file.
 */
const { t } = useI18n()
const router = useRouter()
const store = useReportsStore()

const dismissOpen = ref(false)
const dismissing = ref<AdminReport | null>(null)

const columns = computed(() => [
  { title: t('reports.columns.target'), key: 'target' },
  { title: t('reports.columns.priority'), key: 'priority', width: 130 },
  { title: t('reports.columns.openReports'), key: 'openReports', width: 120 },
  { title: t('reports.columns.reporters'), key: 'reporters', width: 130 },
  { title: t('reports.columns.oldest'), key: 'oldest', width: 170 },
  { title: t('reports.columns.actions'), key: 'actions', width: 140 },
])

function ageText(instant: string) {
  const age = ageOf(instant)
  return age.unit === 'justNow' ? t('reports.age.justNow') : t(`reports.age.${age.unit}`, { count: toPersianDigits(age.count) })
}

function openTarget(group: ReportGroup) {
  void router.push({ name: 'ReportTarget', params: { userId: group.targetUserId } })
}

function openDismiss(report: AdminReport) {
  dismissing.value = report
  dismissOpen.value = true
}

onMounted(() => {
  void store.fetchQueue()
})
</script>

<style scoped>
.list-alert {
  margin-bottom: 16px;
}

.target-name {
  font-weight: 600;
}
</style>
