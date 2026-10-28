<template>
  <a-modal :open="open" :title="title" :mask-closable="false" @cancel="close">
    <a-alert
      v-if="errorMessage"
      class="modal-alert"
      type="error"
      show-icon
      :message="errorMessage"
      :data-testid="`${testId}-error`"
    />
    <p>{{ content }}</p>

    <template #footer>
      <a-button :data-testid="`${testId}-cancel`" @click="close">{{ t('catalog.cancel') }}</a-button>
      <a-button type="primary" :danger="danger" :loading="submitting" :data-testid="`${testId}-submit`" @click="submit">
        {{ submitText }}
      </a-button>
    </template>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { message } from 'ant-design-vue'
import { getApiErrorMessage } from '../../utils/axios'

/**
 * A yes/no confirmation in front of one command (activate a sport, hide a club). The command runs on the primary
 * button; a refusal stays in the modal with the server's Persian message, success closes it with a toast.
 */
const props = defineProps<{
  open: boolean
  title: string
  content: string
  submitText: string
  /** The toast after the command succeeds. */
  successMessage: string
  action: () => Promise<unknown>
  danger?: boolean
  /** Prefix of the modal's test ids: `<testId>-submit`, `<testId>-error`. */
  testId: string
}>()
const emit = defineEmits<{ 'update:open': [open: boolean] }>()

const { t } = useI18n()

const errorMessage = ref('')
const submitting = ref(false)

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
  if (submitting.value) return
  errorMessage.value = ''
  submitting.value = true
  try {
    await props.action()
    void message.success(props.successMessage)
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
