<template>
  <div class="page-container" data-testid="venues-page">
    <a-page-header :title="t('navigation.venues')" class="page-header">
      <template #tags>
        <a-tag data-testid="venues-total">{{ t('venues.total', { total: toPersianDigits(store.totalCount) }) }}</a-tag>
      </template>
      <template #extra>
        <a-button type="primary" data-testid="venues-add" @click="openCreate">
          <template #icon><PlusOutlined /></template>
          {{ t('venues.add') }}
        </a-button>
      </template>
    </a-page-header>

    <a-card>
      <div class="filters">
        <ProvinceCitySelect
          :province-id="store.filters.provinceId"
          :city-id="store.filters.cityId"
          allow-clear
          test-id="venues-location"
          @change="applyLocation"
        />
        <a-input-search
          v-model:value="search"
          class="filter-search"
          allow-clear
          enter-button
          :placeholder="t('venues.searchPlaceholder')"
          data-testid="venues-search"
          @search="applySearch"
        />
        <a-select
          :value="store.filters.status"
          class="filter-status"
          allow-clear
          :options="statusOptions"
          :placeholder="t('venues.statusPlaceholder')"
          data-testid="venues-status"
          @change="applyStatus"
        />
      </div>

      <a-alert v-if="store.error" class="list-alert" type="error" show-icon :message="store.error" data-testid="venues-error" />

      <a-table
        row-key="id"
        :columns="columns"
        :data-source="store.items"
        :loading="store.loading"
        :pagination="pagination"
        :locale="{ emptyText: t('venues.empty') }"
        :scroll="{ x: 1000 }"
        size="middle"
        data-testid="venues-table"
        @change="handleTableChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'name'">
            <span class="venue-name">{{ record.name }}</span>
            <a-tooltip v-if="record.googlePlaceId" :title="t('venues.googleTitle')">
              <a-tag color="blue" class="google-tag" data-testid="cell-google">
                <template #icon><GoogleOutlined /></template>
                {{ t('venues.google') }}
              </a-tag>
            </a-tooltip>
            <div v-if="record.address" class="muted address">{{ record.address }}</div>
          </template>

          <template v-else-if="column.key === 'city'">{{ record.cityName }}</template>

          <template v-else-if="column.key === 'sports'">
            <a-tag v-for="sport in record.sports" :key="sport.sportCode" data-testid="cell-sport">
              {{ sportName(sport.sportCode) }}<template v-if="sport.courtCount">
                · {{ t('venues.courts', { count: toPersianDigits(sport.courtCount) }) }}</template
              >
            </a-tag>
          </template>

          <template v-else-if="column.key === 'status'">
            <a-tag :color="record.status === 'Active' ? 'green' : 'default'" data-testid="cell-status">
              {{ t(`venues.status.${record.status}`) }}
            </a-tag>
          </template>

          <template v-else-if="column.key === 'actions'">
            <a-space :size="0" wrap>
              <a-button type="link" size="small" data-testid="action-edit" @click="openEdit(record as Venue)">
                {{ t('venues.actions.edit') }}
              </a-button>
              <a-button type="link" size="small" data-testid="action-profile" @click="openProfile(record as Venue)">
                {{ t('venues.actions.profile') }}
              </a-button>
              <a-button
                v-if="record.status === 'Active'"
                type="link"
                size="small"
                danger
                data-testid="action-hide"
                @click="openVisibility(record as Venue)"
              >
                {{ t('venues.actions.hide') }}
              </a-button>
              <a-button v-else type="link" size="small" data-testid="action-unhide" @click="openVisibility(record as Venue)">
                {{ t('venues.actions.unhide') }}
              </a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <VenueFormDrawer v-model:open="drawerOpen" :venue="editing" />
    <VenueProfileDrawer v-model:open="profileOpen" :venue="profiling" />
    <ConfirmModal
      v-model:open="visibilityOpen"
      :title="visibilityKind ? t(`venues.${visibilityKind}.title`, { name: target?.name ?? '' }) : ''"
      :content="visibilityKind ? t(`venues.${visibilityKind}.confirm`) : ''"
      :submit-text="visibilityKind ? t(`venues.${visibilityKind}.submit`) : ''"
      :success-message="visibilityKind === 'hide' ? t('venues.messages.hidden') : t('venues.messages.unhidden')"
      :danger="visibilityKind === 'hide'"
      :action="runVisibility"
      :test-id="visibilityKind ?? 'venue-visibility'"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import type { TablePaginationConfig } from 'ant-design-vue'
import { GoogleOutlined, PlusOutlined } from '@ant-design/icons-vue'
import { VENUE_STATUSES, type Venue, type VenueStatus } from '../../api/venues.api'
import ConfirmModal from '../../components/common/ConfirmModal.vue'
import ProvinceCitySelect from '../../components/catalog/ProvinceCitySelect.vue'
import { useSportsStore } from '../../stores/sports.store'
import { useVenuesStore } from '../../stores/venues.store'
import { toPersianDigits } from '../../utils/digits'
import VenueFormDrawer from './components/VenueFormDrawer.vue'
import VenueProfileDrawer from './components/VenueProfileDrawer.vue'

const { t } = useI18n()
const store = useVenuesStore()
const sportsStore = useSportsStore()

const search = ref(store.filters.q)
const drawerOpen = ref(false)
const editing = ref<Venue | null>(null)
const profileOpen = ref(false)
const profiling = ref<Venue | null>(null)
const visibilityOpen = ref(false)
const target = ref<Venue | null>(null)
const visibilityKind = computed<'hide' | 'unhide' | null>(() =>
  target.value ? (target.value.status === 'Active' ? 'hide' : 'unhide') : null,
)

const sportName = (code: string) => sportsStore.byCode.get(code)?.nameFa ?? code

const statusOptions = computed(() => VENUE_STATUSES.map((status) => ({ value: status, label: t(`venues.status.${status}`) })))

const columns = computed(() => [
  { title: t('venues.columns.name'), key: 'name' },
  { title: t('venues.columns.city'), key: 'city', width: 120 },
  { title: t('venues.columns.sports'), key: 'sports', width: 300 },
  { title: t('venues.columns.status'), key: 'status', width: 100 },
  { title: t('venues.columns.actions'), key: 'actions', width: 280 },
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

function applySearch() {
  void store.setFilters({ q: search.value ?? '' })
}

function applyStatus(value: unknown) {
  void store.setFilters({ status: (value as VenueStatus | undefined) || undefined })
}

function handleTableChange(next: TablePaginationConfig) {
  void store.setPage(next.current ?? 1, next.pageSize ?? store.pageSize)
}

function openCreate() {
  editing.value = null
  drawerOpen.value = true
}

function openEdit(venue: Venue) {
  editing.value = venue
  drawerOpen.value = true
}

function openProfile(venue: Venue) {
  profiling.value = venue
  profileOpen.value = true
}

function openVisibility(venue: Venue) {
  target.value = { ...venue }
  visibilityOpen.value = true
}

function runVisibility(): Promise<void> {
  const venue = target.value
  if (!venue) return Promise.resolve()
  return venue.status === 'Active' ? store.hide(venue.id) : store.unhide(venue.id)
}

onMounted(() => {
  void sportsStore.ensureLoaded()
  void store.fetchVenues()
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
  width: 260px;
  max-width: 100%;
}

.filter-status {
  width: 160px;
}

.list-alert {
  margin-bottom: 16px;
}

.venue-name {
  font-weight: 500;
}

.google-tag {
  margin-inline-start: 8px;
}

.address {
  font-size: 12px;
}

.muted {
  color: var(--ty-text-secondary);
}
</style>
