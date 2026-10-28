<template>
  <a-modal
    :open="open"
    :title="t('users.player.removePhoto.title', { name: profile?.displayName ?? '' })"
    :mask-closable="false"
    @cancel="close"
  >
    <a-alert
      v-if="errorMessage"
      class="modal-alert"
      type="error"
      show-icon
      :message="errorMessage"
      data-testid="photo-error"
    />
    <p class="description">{{ t('users.player.removePhoto.description') }}</p>

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
          data-testid="photo-reason"
        />
      </a-form-item>
    </a-form>

    <template #footer>
      <a-button data-testid="photo-cancel" @click="close">{{ t('users.cancel') }}</a-button>
      <a-button type="primary" danger :loading="submitting" data-testid="photo-submit" @click="submit">
        {{ t('users.player.removePhoto.submit') }}
      </a-button>
    </template>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { message } from 'ant-design-vue'
import type { AdminPlayerProfile } from '../../../api/players.api'
import { usePlayersStore } from '../../../stores/players.store'
import { getApiErrorMessage } from '../../../utils/axios'

/** Removes a player's profile photo, with a required reason. */
const props = defineProps<{ open: boolean; profile: AdminPlayerProfile | null }>()
const emit = defineEmits<{ 'update:open': [open: boolean] }>()

const { t } = useI18n()
const store = usePlayersStore()

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
  if (!props.profile || submitting.value) return
  errorMessage.value = ''
  reasonError.value = reason.value.trim() ? '' : t('users.reason.required')
  if (reasonError.value) return

  submitting.value = true
  try {
    await store.removePhoto(props.profile.userId, reason.value)
    void message.success(t('users.player.messages.photoRemoved'))
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
