<template>
  <a-modal :open="open" :title="title" :mask-closable="false" @cancel="close">
    <a-alert
      v-if="errorMessage"
      class="modal-alert"
      type="error"
      show-icon
      :message="errorMessage"
      :data-testid="`${kind}-error`"
    />

    <!-- A ban is final: say so plainly, and ask for an explicit acknowledgement before the button arms. -->
    <a-alert
      v-if="kind === 'ban'"
      class="modal-alert"
      type="error"
      show-icon
      :message="t('users.ban.warningTitle')"
      :description="t('users.ban.warning')"
      data-testid="ban-warning"
    />
    <p v-else class="description">{{ t('users.lift.description') }}</p>

    <a-form layout="vertical">
      <a-form-item
        :label="t('users.reason.label')"
        required
        :validate-status="reasonError ? 'error' : undefined"
        :help="reasonError || undefined"
      >
        <a-textarea
          v-model:value="reason"
          :rows="3"
          :placeholder="t('users.reason.placeholder')"
          :data-testid="`${kind}-reason`"
        />
      </a-form-item>

      <a-checkbox v-if="kind === 'ban'" v-model:checked="acknowledged" data-testid="ban-acknowledge">
        {{ t('users.ban.acknowledge') }}
      </a-checkbox>
    </a-form>

    <template #footer>
      <a-button :data-testid="`${kind}-cancel`" @click="close">{{ t('users.cancel') }}</a-button>
      <a-button
        type="primary"
        :danger="kind === 'ban'"
        :disabled="kind === 'ban' && !acknowledged"
        :loading="submitting"
        :data-testid="`${kind}-submit`"
        @click="submit"
      >
        {{ kind === 'ban' ? t('users.ban.submit') : t('users.lift.submit') }}
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

/** The two actions that take only a reason: lifting a suspension, and the permanent ban. */
const props = defineProps<{ open: boolean; account: AdminAccount | null; kind: 'liftSuspension' | 'ban' }>()
const emit = defineEmits<{ 'update:open': [open: boolean] }>()

const { t } = useI18n()
const store = useUsersStore()

const reason = ref('')
const reasonError = ref('')
const acknowledged = ref(false)
const errorMessage = ref('')
const submitting = ref(false)

const phone = computed(() => formatPhone(props.account?.phoneNumber))
const title = computed(() =>
  props.kind === 'ban' ? t('users.ban.title', { phone: phone.value }) : t('users.lift.title', { phone: phone.value }),
)

watch(
  () => props.open,
  (open) => {
    if (!open) return
    reason.value = ''
    reasonError.value = ''
    acknowledged.value = false
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
  if (props.kind === 'ban' && !acknowledged.value) return
  errorMessage.value = ''
  reasonError.value = reason.value.trim() ? '' : t('users.reason.required')
  if (reasonError.value) return

  submitting.value = true
  try {
    if (props.kind === 'ban') {
      await store.ban(props.account.userId, reason.value)
      void message.success(t('users.messages.banned'))
    } else {
      await store.liftSuspension(props.account.userId, reason.value)
      void message.success(t('users.messages.lifted'))
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

.description {
  color: var(--ty-text-secondary);
}
</style>
