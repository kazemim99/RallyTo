<template>
  <div class="page-container" data-testid="target-page">
    <a-page-header
      :title="detail ? t('reportTarget.title', { name: detail.displayName }) : t('navigation.reports')"
      class="page-header"
      @back="goBack"
    >
      <template #backIcon>
        <span data-testid="target-back" :title="t('reportTarget.back')"><ArrowRightOutlined /></span>
      </template>
      <template v-if="detail" #tags>
        <a-tag v-if="account" :color="STATUS_COLORS[account.status] ?? 'default'" data-testid="target-account-status">
          {{ t(`users.status.${account.status}`) }}
        </a-tag>
        <a-tag :color="RELIABILITY_COLORS[detail.reliability] ?? 'default'" data-testid="target-reliability-tag">
          {{ t('reportTarget.reliability') }}: {{ label('reliability', detail.reliability) }}
        </a-tag>
      </template>
    </a-page-header>

    <a-spin :spinning="store.loading">
      <a-alert v-if="store.error" type="error" show-icon :message="store.error" data-testid="target-error" />
      <a-empty v-else-if="store.notFound" :description="t('reportTarget.notFound')" data-testid="target-not-found" />

      <template v-else-if="detail">
        <a-card class="section">
          <a-descriptions :column="{ xs: 1, md: 2 }" size="small" bordered data-testid="target-summary">
            <a-descriptions-item :label="t('reportTarget.userId')">
              <span dir="ltr" class="mono">{{ detail.userId }}</span>
            </a-descriptions-item>
            <a-descriptions-item :label="t('reportTarget.account')">
              <span v-if="account" data-testid="target-account">
                {{ t(`users.status.${account.status}`) }}
                <template v-if="account.status === 'Suspended' && account.suspendedUntil">
                  — {{ t('reportTarget.suspendedUntil') }} {{ formatDateTime(account.suspendedUntil) }}
                </template>
              </span>
              <span v-else class="muted" data-testid="target-account">{{ t('reportTarget.accountUnknown') }}</span>
            </a-descriptions-item>
            <a-descriptions-item :label="t('reportTarget.reliability')">
              <span data-testid="target-reliability">{{ label('reliability', detail.reliability) }}</span>
            </a-descriptions-item>
            <a-descriptions-item :label="t('reportTarget.sections.disputes')">
              <span data-testid="target-dispute-count">
                {{ t('reportTarget.disputeCount', { count: toPersianDigits(detail.disputes.count) }) }}
              </span>
            </a-descriptions-item>
          </a-descriptions>

          <div class="action-bar" data-testid="target-actions">
            <template v-if="actions.length">
              <a-button
                v-for="action in actions"
                :key="action"
                :danger="DANGEROUS_ACTIONS.has(action)"
                :data-testid="`target-action-${action}`"
                @click="openAction(action)"
              >
                {{ t(`moderation.actions.${action}`) }}
              </a-button>
            </template>
            <span v-else class="muted">{{ t('reportTarget.noActionsAvailable') }}</span>
          </div>
        </a-card>

        <a-card :title="t('reportTarget.sections.reports')" class="section" data-testid="target-reports">
          <a-empty v-if="detail.reports.length === 0" :description="t('reportTarget.noReports')" />
          <ReportCard v-for="report in detail.reports" :key="report.id" :report="report" show-status>
            <template v-if="report.status === 'Open'" #actions>
              <a-button
                v-if="actions.length"
                size="small"
                type="primary"
                ghost
                :data-testid="`report-act-${report.id}`"
                @click="actOnReport(report)"
              >
                {{ t('reportTarget.actOnReport') }}
              </a-button>
              <a-button size="small" :data-testid="`report-dismiss-${report.id}`" @click="openDismiss(report)">
                {{ t('reports.dismiss.action') }}
              </a-button>
            </template>
          </ReportCard>
        </a-card>

        <a-card :title="t('reportTarget.sections.history')" class="section">
          <a-table
            row-key="id"
            :columns="historyColumns"
            :data-source="detail.actions"
            :pagination="false"
            :locale="{ emptyText: t('reportTarget.noHistory') }"
            :scroll="{ x: 800 }"
            size="small"
            data-testid="target-history"
          >
            <template #bodyCell="{ column, record }">
              <template v-if="column.key === 'at'">{{ formatDateTime(record.at) }}</template>
              <template v-else-if="column.key === 'action'">
                <a-tag :color="DANGEROUS_ACTIONS.has(record.action) ? 'red' : 'default'" data-testid="history-action">
                  {{ te(`moderation.actions.${record.action}`) ? t(`moderation.actions.${record.action}`) : record.action }}
                </a-tag>
              </template>
              <template v-else-if="column.key === 'subject'">
                <span v-if="record.subject" dir="ltr" class="mono">{{ subjectText(record.subject) }}</span>
                <span v-else class="muted">{{ t('safety.noValue') }}</span>
              </template>
              <template v-else-if="column.key === 'report'">
                <span v-if="record.reportId" dir="ltr" class="mono" :title="record.reportId">{{ shortId(record.reportId) }}</span>
                <span v-else class="muted">{{ t('safety.noValue') }}</span>
              </template>
              <template v-else-if="column.key === 'admin'">
                <span dir="ltr" class="mono" :title="record.adminId">{{ shortId(record.adminId) }}</span>
              </template>
            </template>
          </a-table>
        </a-card>

        <a-card :title="t('reportTarget.sections.disputes')" class="section" data-testid="target-disputes">
          <p>{{ t('reportTarget.disputeCount', { count: toPersianDigits(detail.disputes.count) }) }}</p>
          <a-space wrap>
            <router-link
              v-for="matchId in detail.disputes.matchIds"
              :key="matchId"
              :to="{ name: 'DisputedMatches', query: { match: matchId } }"
              :title="matchId"
              :data-testid="`dispute-link-${matchId}`"
            >
              <a-tag color="orange"><span dir="ltr" class="mono">{{ shortId(matchId) }}</span></a-tag>
            </router-link>
          </a-space>
        </a-card>

        <a-card :title="t('reportTarget.sections.notes')" class="section">
          <a-table
            row-key="ratingId"
            :columns="noteColumns"
            :data-source="detail.privateNotes"
            :pagination="false"
            :locale="{ emptyText: t('reportTarget.noNotes') }"
            :scroll="{ x: 700 }"
            size="small"
            data-testid="target-notes"
          >
            <template #bodyCell="{ column, record }">
              <template v-if="column.key === 'stars'">
                <span data-testid="note-stars">{{ t('ratings.stars', { count: toPersianDigits(record.stars) }) }}</span>
              </template>
              <template v-else-if="column.key === 'note'">
                <span class="multiline" data-testid="note-text">{{ record.note }}</span>
              </template>
              <template v-else-if="column.key === 'match'">
                <span dir="ltr" class="mono" :title="record.matchId">{{ shortId(record.matchId) }}</span>
              </template>
              <template v-else-if="column.key === 'at'">{{ formatDateTime(record.submittedAt) }}</template>
            </template>
          </a-table>
        </a-card>
      </template>
    </a-spin>

    <ModerationActionModal
      v-model:open="actionOpen"
      :initial-action="initialAction"
      :actions="actions"
      :target="detail ? { userId: detail.userId, displayName: detail.displayName } : null"
      :reports="detail?.reports ?? []"
      :initial="initialForm"
      :submit="store.act"
    />
    <DismissReportModal v-model:open="dismissOpen" :report="dismissing" :dismiss="dismiss" />
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { ArrowRightOutlined } from '@ant-design/icons-vue'
import type { AdminReport, ModerationActionType } from '../../api/safety.api'
import { useReportTargetStore } from '../../stores/reportTarget.store'
import { formatDateTime, parseJalaliDay } from '../../utils/date'
import { toPersianDigits } from '../../utils/digits'
import { STATUS_COLORS } from '../users/userActions'
import ReportCard from './components/ReportCard.vue'
import DismissReportModal from './components/DismissReportModal.vue'
import ModerationActionModal from './components/ModerationActionModal.vue'
import {
  DANGEROUS_ACTIONS,
  RELIABILITY_COLORS,
  availableModerationActions,
  prefillFromReport,
  shortId,
  type ModerationForm,
} from './moderation'

/**
 * A reported player's file (trust-safety › Admin report queue, Admin actions): every report with its evidence,
 * earlier actions, the account status and reliability, disputes in the last 90 days with their matches, and the
 * private notes left in ratings. The action dialogs are opened from here, generally or for one report.
 */
const { t, te } = useI18n()
const route = useRoute()
const router = useRouter()
const store = useReportTargetStore()

const userId = computed(() => String(route.params.userId ?? ''))
const detail = computed(() => (store.userId === userId.value ? store.detail : null))
const account = computed(() => (store.userId === userId.value ? store.account : null))
const actions = computed(() => availableModerationActions(account.value?.status ?? null))

const actionOpen = ref(false)
const initialAction = ref<ModerationActionType | null>(null)
const initialForm = ref<Partial<ModerationForm>>({})
const dismissOpen = ref(false)
const dismissing = ref<AdminReport | null>(null)

const label = (group: string, value: string) => (te(`safety.${group}.${value}`) ? t(`safety.${group}.${value}`) : value)

/** A suspension's last day reads in Persian digits; a gender in Persian; an id as sent. */
function subjectText(subject: string) {
  if (parseJalaliDay(subject)) return toPersianDigits(subject)
  if (te(`users.player.gender.${subject}`)) return t(`users.player.gender.${subject}`)
  return subject
}

const historyColumns = computed(() => [
  { title: t('reportTarget.historyColumns.at'), key: 'at', width: 150 },
  { title: t('reportTarget.historyColumns.action'), key: 'action', width: 150 },
  { title: t('reportTarget.historyColumns.reason'), key: 'reason', dataIndex: 'reason' },
  { title: t('reportTarget.historyColumns.subject'), key: 'subject', width: 160 },
  { title: t('reportTarget.historyColumns.report'), key: 'report', width: 110 },
  { title: t('reportTarget.historyColumns.admin'), key: 'admin', width: 110 },
])

const noteColumns = computed(() => [
  { title: t('reportTarget.noteColumns.rater'), key: 'rater', dataIndex: 'raterName', width: 160 },
  { title: t('reportTarget.noteColumns.stars'), key: 'stars', width: 90 },
  { title: t('reportTarget.noteColumns.note'), key: 'note' },
  { title: t('reportTarget.noteColumns.match'), key: 'match', width: 110 },
  { title: t('reportTarget.noteColumns.at'), key: 'at', width: 150 },
])

function openAction(action: ModerationActionType) {
  initialAction.value = action
  initialForm.value = {}
  actionOpen.value = true
}

function actOnReport(report: AdminReport) {
  const { action, form } = prefillFromReport(report)
  initialAction.value = actions.value.includes(action) ? action : (actions.value[0] ?? null)
  initialForm.value = form
  actionOpen.value = true
}

function openDismiss(report: AdminReport) {
  dismissing.value = report
  dismissOpen.value = true
}

const dismiss = (reportId: string, reason: string) => store.dismiss(userId.value, reportId, reason)

function goBack() {
  void router.push({ name: 'Reports' })
}

watch(
  userId,
  (id) => {
    actionOpen.value = false
    dismissOpen.value = false
    if (id) void store.load(id)
  },
  { immediate: true },
)

onBeforeUnmount(() => store.reset())
</script>

<style scoped>
.section {
  margin-bottom: 16px;
}

.action-bar {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 16px;
}

.multiline {
  white-space: pre-line;
}

.mono {
  font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
  font-size: 12px;
  word-break: break-all;
}

.muted {
  color: var(--ty-text-secondary);
}
</style>
