<template>
  <a-modal
    :open="open"
    :title="t('ratings.removeModal.title', { rater: rating?.raterName ?? '' })"
    :mask-closable="false"
    @cancel="close"
  >
    <a-alert v-if="errorMessage" class="modal-alert" type="error" show-icon :message="errorMessage" data-testid="rating-remove-error" />
    <p class="description">{{ t('ratings.removeModal.description') }}</p>

    <a-form layout="vertical">
      <a-form-item
        :label="t('safety.reason.label')"
        required
        :validate-status="reasonError ? 'error' : undefined"
        :help="reasonError || undefined"
      >
        <a-textarea
          v-model:value="reason"
          :rows="3"
          :maxlength="500"
          :placeholder="t('safety.reason.placeholder')"
          data-testid="rating-remove-reason"
        />
      </a-form-item>
    </a-form>

    <template #footer>
      <a-button data-testid="rating-remove-cancel" @click="close">{{ t('safety.cancel') }}</a-button>
      <a-button type="primary" danger :loading="submitting" data-testid="rating-remove-submit" @click="submit">
        {{ t('ratings.removeModal.submit') }}
      </a-button>
    </template>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { message } from 'ant-design-vue'
import type { AdminRating } from '../../../api/ratings.api'
import { getApiErrorMessage } from '../../../utils/axios'

/** Removes an abusive rating; the reason is required and audited. A refusal stays in the modal. */
const props = defineProps<{
  open: boolean
  rating: AdminRating | null
  remove: (ratingId: string, reason: string) => Promise<unknown>
}>()
const emit = defineEmits<{ 'update:open': [open: boolean] }>()

const { t } = useI18n()

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
  if (!props.rating || submitting.value) return
  errorMessage.value = ''
  reasonError.value = reason.value.trim() ? '' : t('moderation.errors.reasonRequired')
  if (reasonError.value) return

  submitting.value = true
  try {
    await props.remove(props.rating.id, reason.value.trim())
    void message.success(t('ratings.removeModal.success'))
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
