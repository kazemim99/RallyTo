<template>
  <div class="page-container" data-testid="users-page">
    <a-page-header :title="t('navigation.users')" class="page-header">
      <template #tags>
        <a-tag data-testid="users-total">{{ t('users.total', { total: toPersianDigits(store.totalCount) }) }}</a-tag>
      </template>
    </a-page-header>

    <a-card>
      <div class="filters">
        <a-input-search
          v-model:value="search"
          class="filter-search"
          allow-clear
          enter-button
          inputmode="tel"
          :placeholder="t('users.searchPlaceholder')"
          data-testid="users-search"
          @search="applySearch"
        />
        <a-select
          :value="store.filters.status"
          class="filter-status"
          allow-clear
          :options="statusOptions"
          :placeholder="t('users.statusPlaceholder')"
          data-testid="users-status"
          @change="applyStatus"
        />
      </div>

      <a-alert v-if="store.error" class="list-alert" type="error" show-icon :message="store.error" data-testid="users-error" />

      <a-table
        row-key="userId"
        :columns="columns"
        :data-source="store.items"
        :loading="store.loading"
        :pagination="pagination"
        :locale="{ emptyText: t('users.empty') }"
        :scroll="{ x: 1100 }"
        size="middle"
        data-testid="users-table"
        @change="handleTableChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'phone'">
            <span v-if="record.phoneNumber" dir="ltr" class="phone" data-testid="cell-phone">
              {{ formatPhone(record.phoneNumber) }}
            </span>
            <span v-else class="muted">{{ t('users.noValue') }}</span>
          </template>

          <template v-else-if="column.key === 'roles'">
            <a-tag v-for="role in record.roles" :key="role" :color="ROLE_COLORS[role] ?? 'default'">
              {{ roleLabel(role) }}
            </a-tag>
          </template>

          <template v-else-if="column.key === 'status'">
            <a-tag :color="STATUS_COLORS[record.status as AccountStatus] ?? 'default'" data-testid="cell-status">
              {{ statusLabel(record.status) }}
            </a-tag>
          </template>

          <template v-else-if="column.key === 'suspendedUntil'">
            <span v-if="record.suspendedUntil">{{ formatDateTime(record.suspendedUntil) }}</span>
            <span v-else class="muted">{{ t('users.noValue') }}</span>
          </template>

          <template v-else-if="column.key === 'statusReason'">
            <span v-if="record.statusReason">{{ record.statusReason }}</span>
            <span v-else class="muted">{{ t('users.noValue') }}</span>
          </template>

          <template v-else-if="column.key === 'createdAt'">
            {{ formatDate(record.createdAt) }}
          </template>

          <template v-else-if="column.key === 'actions'">
            <a-space :size="0" wrap>
              <a-button type="link" size="small" data-testid="action-details" @click="openDetails(record as AdminAccount)">
                {{ t('users.actions.details') }}
              </a-button>
              <a-button
                v-for="action in availableActions(record as AdminAccount)"
                :key="action"
                type="link"
                size="small"
                :danger="action === 'ban' || action === 'revokeAdmin'"
                :data-testid="`action-${action}`"
                @click="openAction(action, record as AdminAccount)"
              >
                {{ t(`users.actions.${action}`) }}
              </a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <SuspendModal v-model:open="modals.suspend" :account="selected" />
    <ReasonModal v-model:open="modals.liftSuspension" :account="selected" kind="liftSuspension" />
    <ReasonModal v-model:open="modals.ban" :account="selected" kind="ban" />
    <RoleConfirmModal v-model:open="modals.grantAdmin" :account="selected" kind="grantAdmin" />
    <RoleConfirmModal v-model:open="modals.revokeAdmin" :account="selected" kind="revokeAdmin" />
    <UserDetailDrawer v-model:open="drawerOpen" :user-id="drawerUserId" />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import type { TablePaginationConfig } from 'ant-design-vue'
import { ACCOUNT_STATUSES, type AccountStatus, type AdminAccount } from '../../api/users.api'
import { useUsersStore } from '../../stores/users.store'
import { formatDate, formatDateTime } from '../../utils/date'
import { toPersianDigits } from '../../utils/digits'
import { formatPhone } from '../../utils/phone'
import SuspendModal from './components/SuspendModal.vue'
import ReasonModal from './components/ReasonModal.vue'
import RoleConfirmModal from './components/RoleConfirmModal.vue'
import UserDetailDrawer from './components/UserDetailDrawer.vue'
import { ROLE_COLORS, STATUS_COLORS, availableActions, type UserAction } from './userActions'

const { t, te } = useI18n()
const store = useUsersStore()

const search = ref(store.filters.search)
const selected = ref<AdminAccount | null>(null)
const modals = reactive<Record<UserAction, boolean>>({
  suspend: false,
  liftSuspension: false,
  ban: false,
  grantAdmin: false,
  revokeAdmin: false,
})
const drawerOpen = ref(false)
const drawerUserId = ref<string | null>(null)

const statusLabel = (status: string) => (te(`users.status.${status}`) ? t(`users.status.${status}`) : status)
const roleLabel = (role: string) => (te(`users.roles.${role}`) ? t(`users.roles.${role}`) : role)

const statusOptions = computed(() => ACCOUNT_STATUSES.map((status) => ({ value: status, label: statusLabel(status) })))

const columns = computed(() => [
  { title: t('users.columns.phone'), key: 'phone', width: 150 },
  { title: t('users.columns.roles'), key: 'roles', width: 140 },
  { title: t('users.columns.status'), key: 'status', width: 110 },
  { title: t('users.columns.suspendedUntil'), key: 'suspendedUntil', width: 150 },
  { title: t('users.columns.reason'), key: 'statusReason', dataIndex: 'statusReason', ellipsis: true },
  { title: t('users.columns.createdAt'), key: 'createdAt', width: 120 },
  { title: t('users.columns.actions'), key: 'actions', width: 260 },
])

const pagination = computed<TablePaginationConfig>(() => ({
  current: store.page,
  pageSize: store.pageSize,
  total: store.totalCount,
  showSizeChanger: true,
  pageSizeOptions: ['10', '20', '50', '100'],
}))

function applySearch() {
  void store.setFilters({ search: search.value ?? '' })
}

function applyStatus(value: unknown) {
  void store.setFilters({ status: (value as AccountStatus | undefined) || undefined })
}

function handleTableChange(next: TablePaginationConfig) {
  void store.setPage(next.current ?? 1, next.pageSize ?? store.pageSize)
}

function openAction(action: UserAction, account: AdminAccount) {
  selected.value = account
  modals[action] = true
}

function openDetails(account: AdminAccount) {
  drawerUserId.value = account.userId
  drawerOpen.value = true
}

onMounted(() => {
  void store.fetchUsers()
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
  width: 280px;
  max-width: 100%;
}

.filter-status {
  width: 180px;
}

.list-alert {
  margin-bottom: 16px;
}

.phone {
  white-space: nowrap;
}

.muted {
  color: var(--ty-text-secondary);
}
</style>
