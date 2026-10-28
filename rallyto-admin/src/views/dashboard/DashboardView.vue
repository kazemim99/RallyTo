<template>
  <div class="page-container" data-testid="dashboard-page">
    <a-page-header :title="t('navigation.dashboard')" class="page-header">
      <template v-if="store.stats" #tags>
        <a-tag data-testid="dashboard-period">
          {{ t('dashboard.period', { from: toPersianDigits(store.stats.from), to: toPersianDigits(store.stats.to) }) }}
        </a-tag>
      </template>
    </a-page-header>

    <a-card class="filters-card">
      <a-form layout="vertical" class="filters">
        <a-form-item :label="t('dashboard.from')" v-bind="status('from')">
          <JalaliDateInput v-model="range.from" test-id="dashboard-from" />
        </a-form-item>
        <a-form-item :label="t('dashboard.to')" v-bind="status('to')">
          <JalaliDateInput v-model="range.to" test-id="dashboard-to" />
        </a-form-item>
        <a-form-item>
          <a-space wrap>
            <a-button type="primary" :loading="store.loading" data-testid="dashboard-apply" @click="apply">
              {{ t('dashboard.apply') }}
            </a-button>
            <a-button v-for="days in PRESETS" :key="days" :data-testid="`dashboard-last-${days}`" @click="preset(days)">
              {{ t('dashboard.lastDays', { count: toPersianDigits(days) }) }}
            </a-button>
          </a-space>
        </a-form-item>
      </a-form>
    </a-card>

    <a-alert v-if="store.error" class="list-alert" type="error" show-icon :message="store.error" data-testid="dashboard-error" />

    <a-spin :spinning="store.loading">
      <div v-for="group in GROUPS" :key="group.key" class="group">
        <h3 class="group-title">{{ t(`dashboard.groups.${group.key}`) }}</h3>
        <a-row :gutter="[16, 16]">
          <a-col v-for="metric in group.metrics" :key="metric" :xs="24" :sm="12" :lg="6">
            <a-card class="tile" :data-testid="`tile-${metric}`">
              <div class="tile-label">{{ t(`dashboard.metrics.${metric}`) }}</div>
              <div class="tile-value" data-testid="tile-value">{{ value(metric) }}</div>
              <div class="tile-hint">{{ t(`dashboard.hints.${metric}`) }}</div>
            </a-card>
          </a-col>
        </a-row>
      </div>
    </a-spin>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import type { UsageStats } from '../../api/stats.api'
import JalaliDateInput from '../../components/common/JalaliDateInput.vue'
import { useStatsStore } from '../../stores/stats.store'
import { toPersianDigits } from '../../utils/digits'
import { formatCount, formatRate, lastDays, toStatsQuery, validateStatsRange, type StatsRange } from './stats'

/**
 * The usage dashboard (tasks 10.9): sign-ups, activity, posts and matches, completion and reports for a period of
 * Jalali Tehran days, both inclusive. It opens on the server's default (the last 30 days) and shows the period the
 * server used; the completion rate is completed ÷ resolved matches, "—" when none were resolved.
 */
type Metric = Exclude<keyof UsageStats, 'from' | 'to'>

const PRESETS = [7, 30, 90] as const
const GROUPS: { key: string; metrics: Metric[] }[] = [
  { key: 'players', metrics: ['signUps', 'activePlayers'] },
  { key: 'matches', metrics: ['posts', 'invitations', 'confirmedMatches', 'completedMatches', 'resolvedMatches', 'completionRate'] },
  { key: 'safety', metrics: ['reports', 'openReports'] },
]

const { t } = useI18n()
const store = useStatsStore()

const range = reactive<StatsRange>({ from: '', to: '' })
const errors = ref<Partial<Record<keyof StatsRange, string>>>({})

const value = (metric: Metric) => {
  const stats = store.stats
  if (!stats) return '—'
  return metric === 'completionRate' ? formatRate(stats.completionRate) : formatCount(stats[metric])
}

function status(field: keyof StatsRange) {
  const key = errors.value[field]
  return { validateStatus: key ? ('error' as const) : undefined, help: key ? t(key) : undefined }
}

function apply() {
  errors.value = validateStatsRange(range)
  if (Object.keys(errors.value).length > 0) return
  void store.load(toStatsQuery(range))
}

function preset(days: number) {
  Object.assign(range, lastDays(days))
  apply()
}

// The filter shows the period the server counted (its default on the first read).
watch(
  () => store.stats,
  (stats) => {
    if (stats) Object.assign(range, { from: stats.from, to: stats.to })
  },
)

onMounted(() => {
  void store.load()
})
</script>

<style scoped>
.filters-card {
  margin-bottom: 16px;
}

.filters {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  gap: 0 16px;
}

.list-alert {
  margin-bottom: 16px;
}

.group {
  margin-bottom: 24px;
}

.group-title {
  margin-bottom: 12px;
}

.tile {
  height: 100%;
}

.tile-label {
  color: var(--ty-text-secondary);
}

.tile-value {
  font-size: 28px;
  font-weight: 600;
  margin: 4px 0;
}

.tile-hint {
  font-size: 12px;
  color: var(--ty-text-secondary);
}
</style>
