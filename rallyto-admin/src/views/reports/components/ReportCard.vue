<template>
  <a-card size="small" class="report-card" :data-testid="`report-${report.id}`">
    <template #title>
      <a-space :size="4" wrap>
        <a-tag :color="HIGH_PRIORITY_REASONS.has(report.reason) ? 'red' : 'default'" data-testid="report-reason">
          {{ label('reasons', report.reason) }}
        </a-tag>
        <a-tag data-testid="report-target-type">{{ label('targetTypes', report.targetType) }}</a-tag>
        <a-tag v-if="showStatus" :color="REPORT_STATUS_COLORS[report.status] ?? 'default'" data-testid="report-status">
          {{ label('reportStatus', report.status) }}
        </a-tag>
      </a-space>
    </template>
    <template #extra>
      <span class="muted" data-testid="report-date">{{ formatDateTime(report.createdAt) }}</span>
    </template>

    <dl class="facts">
      <dt>{{ t('reports.report.reporter') }}</dt>
      <dd data-testid="report-reporter">{{ report.reporterName }}</dd>
      <dt>{{ t('reports.report.details') }}</dt>
      <dd class="multiline" data-testid="report-details">
        <span v-if="report.details">{{ report.details }}</span>
        <span v-else class="muted">{{ t('reports.report.noDetails') }}</span>
      </dd>
      <template v-if="report.targetType !== 'Player'">
        <dt>{{ t('reports.report.targetId') }}</dt>
        <dd><span dir="ltr" class="mono" data-testid="report-target-id">{{ report.targetId }}</span></dd>
      </template>
    </dl>

    <div class="evidence" data-testid="report-evidence">
      <div class="evidence-title">{{ t('reports.report.evidence') }}</div>
      <div class="evidence-body">
        <a-image
          v-if="photoSrc"
          :src="photoSrc"
          :width="96"
          :height="96"
          class="evidence-photo"
          :alt="t('reports.evidence.photoAlt', { name: evidence.displayName ?? '' })"
          data-testid="evidence-photo"
        />
        <dl v-if="hasEvidence" class="facts">
          <template v-if="evidence.displayName">
            <dt>{{ t('reports.evidence.displayName') }}</dt>
            <dd data-testid="evidence-name">{{ evidence.displayName }}</dd>
          </template>
          <template v-if="evidence.bio">
            <dt>{{ t('reports.evidence.bio') }}</dt>
            <dd class="multiline" data-testid="evidence-bio">{{ evidence.bio }}</dd>
          </template>
          <template v-if="evidence.text">
            <dt>{{ t('reports.evidence.text') }}</dt>
            <dd class="multiline evidence-text" data-testid="evidence-text">{{ evidence.text }}</dd>
          </template>
          <template v-if="evidence.sentAt">
            <dt>{{ t('reports.evidence.sentAt') }}</dt>
            <dd data-testid="evidence-sent-at">{{ formatDateTime(evidence.sentAt) }}</dd>
          </template>
        </dl>
        <span v-else-if="!photoSrc" class="muted">{{ t('reports.evidence.empty') }}</span>
      </div>
    </div>

    <div v-if="$slots.actions" class="actions">
      <slot name="actions" />
    </div>
  </a-card>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { playerPhotoSrc } from '../../../api/players.api'
import type { AdminReport } from '../../../api/safety.api'
import { formatDateTime } from '../../../utils/date'
import { HIGH_PRIORITY_REASONS, REPORT_STATUS_COLORS } from '../moderation'

/** One report with the evidence snapshot the reporter saw: text, display name, bio, photo and when it was sent. */
const props = defineProps<{ report: AdminReport; showStatus?: boolean }>()

const { t, te } = useI18n()

const evidence = computed(() => props.report.evidence ?? { text: null, displayName: null, bio: null, photoUrl: null, sentAt: null })
const photoSrc = computed(() => playerPhotoSrc(evidence.value.photoUrl))
const hasEvidence = computed(() => Boolean(evidence.value.displayName || evidence.value.bio || evidence.value.text || evidence.value.sentAt))

/** A Persian label for an enum member; an unknown member is shown as the server sent it. */
const label = (group: string, value: string) => (te(`safety.${group}.${value}`) ? t(`safety.${group}.${value}`) : value)
</script>

<style scoped>
.report-card {
  margin-bottom: 12px;
}

.facts {
  display: grid;
  grid-template-columns: max-content 1fr;
  gap: 4px 12px;
  margin: 0;
}

.facts dt {
  color: var(--ty-text-secondary);
}

.facts dd {
  margin: 0;
}

.multiline {
  white-space: pre-line;
}

.evidence {
  margin-top: 12px;
  padding: 8px 12px;
  border-radius: 6px;
  background: rgba(0, 0, 0, 0.02);
  border: 1px dashed rgba(0, 0, 0, 0.12);
}

.evidence-title {
  font-weight: 600;
  margin-bottom: 8px;
}

.evidence-body {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  gap: 12px;
}

.evidence-text {
  background: #fff;
  padding: 4px 8px;
  border-radius: 4px;
}

.actions {
  margin-top: 12px;
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
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
