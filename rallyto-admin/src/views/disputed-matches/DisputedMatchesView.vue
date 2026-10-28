<template>
  <div class="page-container" data-testid="disputes-page">
    <a-page-header :title="t('navigation.disputedMatches')" :sub-title="t('disputes.description')" class="page-header">
      <template #tags>
        <a-tag data-testid="disputes-total">{{ t('disputes.total', { total: toPersianDigits(store.items.length) }) }}</a-tag>
      </template>
      <template #extra>
        <a-button :loading="store.loading" data-testid="disputes-refresh" @click="store.fetch()">
          <template #icon><ReloadOutlined /></template>
          {{ t('safety.refresh') }}
        </a-button>
      </template>
    </a-page-header>

    <a-card>
      <a-alert v-if="store.error" class="list-alert" type="error" show-icon :message="store.error" data-testid="disputes-error" />

      <a-table
        row-key="matchId"
        :columns="columns"
        :data-source="store.items"
        :loading="store.loading"
        :pagination="{ pageSize: 20, hideOnSinglePage: true }"
        :row-class-name="rowClass"
        :locale="{ emptyText: t('disputes.empty') }"
        :scroll="{ x: 1000 }"
        size="middle"
        data-testid="disputes-table"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'date'">
            <span data-testid="cell-date">{{ toPersianDigits(record.date) }}</span>
          </template>

          <template v-else-if="column.key === 'sport'">{{ sportName(record.sportId) }}</template>

          <template v-else-if="column.key === 'status'">
            <a-tag :color="record.status === 'Disputed' ? 'orange' : 'default'" data-testid="cell-status">
              {{ label('matchStatus', record.status) }}
            </a-tag>
          </template>

          <template v-else-if="column.key === 'players'">
            <ul class="players">
              <li v-for="player in (record as DisputedMatch).players" :key="player.userId" :data-testid="`player-${player.userId}`">
                <router-link :to="{ name: 'ReportTarget', params: { userId: player.userId } }" :title="t('disputes.openPlayer')">
                  {{ player.displayName }}
                </router-link>
                <a-tag v-if="player.answer" :color="player.answer === 'Played' ? 'green' : 'volcano'" data-testid="player-answer">
                  {{ label('answers', player.answer) }}
                </a-tag>
                <a-tag v-else data-testid="player-answer">{{ t('disputes.noAnswer') }}</a-tag>
                <a-tag v-if="player.outcome" :color="OUTCOME_COLORS[player.outcome] ?? 'default'" data-testid="player-outcome">
                  {{ label('outcomes', player.outcome) }}
                </a-tag>
              </li>
            </ul>
          </template>

          <template v-else-if="column.key === 'resolvedAt'">
            <span v-if="record.resolvedAt">{{ formatDateTime(record.resolvedAt) }}</span>
            <span v-else class="muted">{{ t('safety.noValue') }}</span>
          </template>

          <template v-else-if="column.key === 'matchId'">
            <span dir="ltr" class="mono" data-testid="cell-match-id">{{ record.matchId }}</span>
          </template>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { ReloadOutlined } from '@ant-design/icons-vue'
import type { DisputedMatch } from '../../api/safety.api'
import { useDisputedMatchesStore } from '../../stores/disputedMatches.store'
import { useSportsStore } from '../../stores/sports.store'
import { formatDateTime } from '../../utils/date'
import { toPersianDigits } from '../../utils/digits'

/**
 * Disputed matches and matches with a contested no-show (trust-safety › Disputed matches are visible to admins),
 * newest first: each player's answer and outcome, the match day and status. A player's dispute count links here
 * with `?match=<id>`, which highlights that match.
 */
const OUTCOME_COLORS: Record<string, string> = { Played: 'green', NoShow: 'red', Contested: 'orange' }

const { t, te } = useI18n()
const route = useRoute()
const store = useDisputedMatchesStore()
const sportsStore = useSportsStore()

const highlighted = computed(() => (typeof route.query.match === 'string' ? route.query.match.toLowerCase() : ''))
const sportsById = computed(() => new Map(sportsStore.items.map((sport) => [sport.id, sport])))

const label = (group: string, value: string) => (te(`safety.${group}.${value}`) ? t(`safety.${group}.${value}`) : value)
const sportName = (sportId: string) => sportsById.value.get(sportId)?.nameFa ?? sportId
const rowClass = (record: DisputedMatch) => (record.matchId.toLowerCase() === highlighted.value ? 'highlighted' : '')

const columns = computed(() => [
  { title: t('disputes.columns.date'), key: 'date', width: 110 },
  { title: t('disputes.columns.sport'), key: 'sport', width: 100 },
  { title: t('disputes.columns.status'), key: 'status', width: 120 },
  { title: t('disputes.columns.players'), key: 'players' },
  { title: t('disputes.columns.resolvedAt'), key: 'resolvedAt', width: 150 },
  { title: t('disputes.columns.matchId'), key: 'matchId', width: 300 },
])

onMounted(() => {
  void store.fetch()
  // Sport names come from the catalog; until it arrives (or if it cannot be read) the id stands in.
  void sportsStore.ensureLoaded()
})
</script>

<style scoped>
.list-alert {
  margin-bottom: 16px;
}

.players {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.players a {
  margin-inline-end: 8px;
}

:deep(.highlighted) > td {
  background: #fff7e6 !important;
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
