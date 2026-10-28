<template>
  <a-modal :open="open" :title="t(`users.${kind}.title`)" :mask-closable="false" @cancel="close">
    <a-alert
      v-if="errorMessage"
      class="modal-alert"
      type="error"
      show-icon
      :message="errorMessage"
      :data-testid="`${kind}-error`"
    />
    <p>{{ t(`users.${kind}.confirm`, { phone }) }}</p>

    <template #footer>
      <a-button :data-testid="`${kind}-cancel`" @click="close">{{ t('users.cancel') }}</a-button>
      <a-button
        type="primary"
        :danger="kind === 'revokeAdmin'"
        :loading="submitting"
        :data-testid="`${kind}-submit`"
        @click="submit"
      >
        {{ t(`users.${kind}.submit`) }}
      </a-button>
    </template>
  </a-modal>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { message } from 'ant-design-vue'
import type { AdminAccount } from '../../../api/users.api'
import { useUsersStore } from '../../../stores/users.store'
import { getApiErrorMessage } from '../../../utils/axios'
import { formatPhone } from '../../../utils/phone'

/** Granting or revoking the Admin role, behind a confirmation. Revoking the last admin is refused by the server. */
const props = defineProps<{ open: boolean; account: AdminAccount | null; kind: 'grantAdmin' | 'revokeAdmin' }>()
const emit = defineEmits<{ 'update:open': [open: boolean] }>()

const { t } = useI18n()
const store = useUsersStore()

const errorMessage = ref('')
const submitting = ref(false)

const phone = computed(() => formatPhone(props.account?.phoneNumber) || props.account?.userId || '')

watch(
  () => props.open,
  (open) => {
    if (!open) return
    errorMessage.value = ''
    submitting.value = false
  },
  { immediate: true },
)

function close() {
  if (!submitting.value) emit('update:open', false)
}

async function submit() {
  if (!props.account || submitting.value) return
  errorMessage.value = ''
  submitting.value = true
  try {
    if (props.kind === 'grantAdmin') {
      await store.grantAdmin(props.account.userId)
      void message.success(t('users.messages.granted'))
    } else {
      await store.revokeAdmin(props.account.userId)
      void message.success(t('users.messages.revoked'))
    }
    submitting.value = false
    emit('update:open', false)
  } catch (failure) {
    errorMessage.value = getApiErrorMessage(failure)
    submitting.value = false
  }
}
</script>

<style scoped>
.modal-alert {
  margin-bottom: 16px;
}
</style>
