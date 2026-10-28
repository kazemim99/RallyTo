<template>
  <div class="page-container" data-testid="sports-page">
    <a-page-header :title="t('navigation.sports')" class="page-header">
      <template #tags>
        <a-tag data-testid="sports-total">{{ t('sports.total', { total: toPersianDigits(store.items.length) }) }}</a-tag>
      </template>
      <template #extra>
        <a-button type="primary" data-testid="sports-add" @click="openCreate">
          <template #icon><PlusOutlined /></template>
          {{ t('sports.add') }}
        </a-button>
      </template>
    </a-page-header>

    <a-card>
      <a-alert v-if="store.error" class="list-alert" type="error" show-icon :message="store.error" data-testid="sports-error" />

      <a-table
        row-key="id"
        :columns="columns"
        :data-source="store.items"
        :loading="store.loading"
        :pagination="false"
        :locale="{ emptyText: t('sports.empty') }"
        :scroll="{ x: 900 }"
        size="middle"
        data-testid="sports-table"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'name'">
            <div class="sport-name">{{ record.nameFa }}</div>
            <div class="muted" dir="ltr">{{ record.nameEn }}</div>
          </template>

          <template v-else-if="column.key === 'code'">
            <span dir="ltr" class="mono" data-testid="cell-code">{{ record.code }}</span>
          </template>

          <template v-else-if="column.key === 'status'">
            <a-tag :color="record.isActive ? 'green' : 'default'" data-testid="cell-status">
              {{ record.isActive ? t('sports.status.active') : t('sports.status.inactive') }}
            </a-tag>
          </template>

          <template v-else-if="column.key === 'formats'">
            <a-tag v-for="format in record.formats" :key="format.format" data-testid="cell-format">
              {{ t(`catalog.formats.${format.format}`) }}
              ({{ t('sports.playersPerSideShort', { count: toPersianDigits(format.playersPerSide) }) }})
            </a-tag>
          </template>

          <template v-else-if="column.key === 'session'">
            {{ t('sports.minutes', { count: toPersianDigits(record.defaultSessionMinutes) }) }}
          </template>

          <template v-else-if="column.key === 'actions'">
            <a-space :size="0" wrap>
              <a-button type="link" size="small" data-testid="action-edit" @click="openEdit(record as Sport)">
                {{ t('sports.actions.edit') }}
              </a-button>
              <a-button
                v-if="record.isActive"
                type="link"
                size="small"
                danger
                data-testid="action-deactivate"
                @click="openToggle(record as Sport)"
              >
                {{ t('sports.actions.deactivate') }}
              </a-button>
              <a-button v-else type="link" size="small" data-testid="action-activate" @click="openToggle(record as Sport)">
                {{ t('sports.actions.activate') }}
              </a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <SportFormDrawer v-model:open="drawerOpen" :sport="editing" />
    <ConfirmModal
      v-model:open="toggleOpen"
      :title="toggleKind ? t(`sports.${toggleKind}.title`, { name: toggling?.nameFa ?? '' }) : ''"
      :content="toggleKind ? t(`sports.${toggleKind}.confirm`) : ''"
      :submit-text="toggleKind ? t(`sports.${toggleKind}.submit`) : ''"
      :success-message="toggleKind === 'activate' ? t('sports.messages.activated') : t('sports.messages.deactivated')"
      :danger="toggleKind === 'deactivate'"
      :action="runToggle"
      :test-id="toggleKind ?? 'sport-toggle'"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { PlusOutlined } from '@ant-design/icons-vue'
import type { Sport } from '../../api/sports.api'
import ConfirmModal from '../../components/common/ConfirmModal.vue'
import { useSportsStore } from '../../stores/sports.store'
import { toPersianDigits } from '../../utils/digits'
import SportFormDrawer from './components/SportFormDrawer.vue'

const { t } = useI18n()
const store = useSportsStore()

const drawerOpen = ref(false)
const editing = ref<Sport | null>(null)
const toggleOpen = ref(false)
const toggling = ref<Sport | null>(null)
const toggleKind = computed<'activate' | 'deactivate' | null>(() =>
  toggling.value ? (toggling.value.isActive ? 'deactivate' : 'activate') : null,
)

const columns = computed(() => [
  { title: t('sports.columns.name'), key: 'name', width: 180 },
  { title: t('sports.columns.code'), key: 'code', width: 120 },
  { title: t('sports.columns.status'), key: 'status', width: 100 },
  { title: t('sports.columns.formats'), key: 'formats' },
  { title: t('sports.columns.session'), key: 'session', width: 150 },
  { title: t('sports.columns.actions'), key: 'actions', width: 200 },
])

function openCreate() {
  editing.value = null
  drawerOpen.value = true
}

function openEdit(sport: Sport) {
  editing.value = sport
  drawerOpen.value = true
}

function openToggle(sport: Sport) {
  // Captured now: the list refreshes after the command, and the modal's wording must not flip under the admin.
  toggling.value = { ...sport }
  toggleOpen.value = true
}

function runToggle(): Promise<void> {
  const sport = toggling.value
  if (!sport) return Promise.resolve()
  return sport.isActive ? store.deactivate(sport.id) : store.activate(sport.id)
}

onMounted(() => {
  void store.fetchSports()
})
</script>

<style scoped>
.list-alert {
  margin-bottom: 16px;
}

.sport-name {
  font-weight: 500;
}

.mono {
  font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
  font-size: 12px;
}

.muted {
  color: var(--ty-text-secondary);
  font-size: 12px;
}
</style>
