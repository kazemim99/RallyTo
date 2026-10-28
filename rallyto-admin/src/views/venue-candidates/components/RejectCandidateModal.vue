<template>
  <a-modal
    :open="open"
    :title="t('candidates.reject.title', { name: candidate?.name ?? '' })"
    :mask-closable="false"
    @cancel="close"
  >
    <a-alert v-if="errorMessage" class="modal-alert" type="error" show-icon :message="errorMessage" data-testid="reject-error" />

    <a-form layout="vertical">
      <a-form-item
        :label="t('candidates.reject.reason')"
        required
        :validate-status="reasonError ? 'error' : undefined"
        :help="reasonError || undefined"
      >
        <a-textarea
          v-model:value="reason"
          :rows="3"
          :maxlength="500"
          :placeholder="t('candidates.reject.reasonPlaceholder')"
          data-testid="reject-reason"
        />
      </a-form-item>
    </a-form>

    <template #footer>
      <a-button data-testid="reject-cancel" @click="close">{{ t('catalog.cancel') }}</a-button>
      <a-button type="primary" danger :loading="submitting" data-testid="reject-submit" @click="submit">
        {{ t('candidates.reject.submit') }}
      </a-button>
    </template>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { message } from 'ant-design-vue'
import type { VenueCandidate } from '../../../api/venueCandidates.api'
import { useVenueCandidatesStore } from '../../../stores/venueCandidates.store'
import { getApiErrorMessage } from '../../../utils/axios'

/** Rejects a candidate (not a racket venue, closed, a duplicate of nothing): a reason is required. */
const props = defineProps<{ open: boolean; candidate: VenueCandidate | null }>()
const emit = defineEmits<{ 'update:open': [open: boolean] }>()

const { t } = useI18n()
const store = useVenueCandidatesStore()

const reason = ref('')
const reasonError = ref('')
const errorMessage = ref('')
const submitting = ref(false)

watch(
  () => props.open,
  (open) => {
    if (!open) return
    reason.value = ''
    reasonError.value = ''
    errorMessage.value = ''
    submitting.value = false
  },
  { immediate: true },
)

function close() {
  if (!submitting.value) emit('update:open', false)
}

async function submit() {
  if (!props.candidate || submitting.value) return
  errorMessage.value = ''
  reasonError.value = reason.value.trim() ? '' : t('candidates.reject.reasonRequired')
  if (reasonError.value) return

  submitting.value = true
  try {
    await store.reject(props.candidate.id, reason.value)
    void message.success(t('candidates.messages.rejected'))
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
