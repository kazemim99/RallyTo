<template>
  <a-drawer :open="open" :title="t('users.detail.title')" :width="560" data-testid="user-drawer" @close="close">
    <a-tabs v-model:active-key="tab" data-testid="user-tabs">
      <a-tab-pane key="profile" :tab="t('ratings.profileTab')">
        <a-spin :spinning="loading">
          <a-alert v-if="errorMessage" type="error" show-icon :message="errorMessage" data-testid="user-drawer-error" />
          <a-descriptions v-if="account" :column="1" bordered size="small" data-testid="user-details">
            <a-descriptions-item :label="t('users.detail.userId')">
              <span dir="ltr" class="mono">{{ account.userId }}</span>
            </a-descriptions-item>
            <a-descriptions-item :label="t('users.columns.phone')">
              <span dir="ltr">{{ formatPhone(account.phoneNumber) || t('users.noValue') }}</span>
            </a-descriptions-item>
            <a-descriptions-item :label="t('users.columns.roles')">
              <a-tag v-for="role in account.roles" :key="role" :color="ROLE_COLORS[role] ?? 'default'">
                {{ roleLabel(role) }}
              </a-tag>
            </a-descriptions-item>
            <a-descriptions-item :label="t('users.columns.status')">
              <a-tag :color="STATUS_COLORS[account.status] ?? 'default'">{{ t(`users.status.${account.status}`) }}</a-tag>
            </a-descriptions-item>
            <a-descriptions-item :label="t('users.columns.suspendedUntil')">
              {{ formatDateTime(account.suspendedUntil) || t('users.noValue') }}
            </a-descriptions-item>
            <a-descriptions-item :label="t('users.columns.reason')">
              {{ account.statusReason || t('users.noValue') }}
            </a-descriptions-item>
            <a-descriptions-item :label="t('users.columns.createdAt')">
              {{ formatDateTime(account.createdAt) }}
            </a-descriptions-item>
          </a-descriptions>
        </a-spin>
        <PlayerProfileSection v-if="open && userId" :user-id="userId" />
      </a-tab-pane>
      <a-tab-pane key="ratings">
        <template #tab><span data-testid="user-tab-ratings">{{ t('ratings.tab') }}</span></template>
        <PlayerRatingsSection v-if="open && userId && tab === 'ratings'" :user-id="userId" />
      </a-tab-pane>
    </a-tabs>
  </a-drawer>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import type { AdminAccount } from '../../../api/users.api'
import { useUsersStore } from '../../../stores/users.store'
import { getApiErrorMessage } from '../../../utils/axios'
import { formatDateTime } from '../../../utils/date'
import { formatPhone } from '../../../utils/phone'
import { ROLE_COLORS, STATUS_COLORS } from '../userActions'
import PlayerProfileSection from './PlayerProfileSection.vue'
import PlayerRatingsSection from './PlayerRatingsSection.vue'

/**
 * Every field of one account, read fresh from `GET /admin/users/{id}` when the drawer opens, and below it the
 * account's player profile with the admin corrections on it. A second tab lists the ratings the player received,
 * read when the tab is opened.
 */
const props = defineProps<{ open: boolean; userId: string | null }>()
const emit = defineEmits<{ 'update:open': [open: boolean] }>()

const { t, te } = useI18n()
const store = useUsersStore()

const account = ref<AdminAccount | null>(null)
const tab = ref<'profile' | 'ratings'>('profile')
const loading = ref(false)
const errorMessage = ref('')

const roleLabel = (role: string) => (te(`users.roles.${role}`) ? t(`users.roles.${role}`) : role)

watch(
  () => [props.open, props.userId] as const,
  async ([open, userId]) => {
    if (!open || !userId) return
    tab.value = 'profile'
    account.value = null
    errorMessage.value = ''
    loading.value = true
    try {
      const loaded = await store.loadUser(userId)
      if (props.userId === userId) account.value = loaded
    } catch (failure) {
      if (props.userId === userId) errorMessage.value = getApiErrorMessage(failure)
    } finally {
      if (props.userId === userId) loading.value = false
    }
  },
  { immediate: true },
)

function close() {
  emit('update:open', false)
}
</script>

<style scoped>
.mono {
  font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
  font-size: 12px;
  word-break: break-all;
}
</style>
