<template>
  <a-modal
    :open="open"
    :title="t('users.player.correctGender.title', { name: profile?.displayName ?? '' })"
    :mask-closable="false"
    @cancel="close"
  >
    <a-alert
      v-if="errorMessage"
      class="modal-alert"
      type="error"
      show-icon
      :message="errorMessage"
      data-testid="gender-error"
    />
    <a-alert
      class="modal-alert"
      type="warning"
      show-icon
      :message="t('users.player.correctGender.warning')"
      data-testid="gender-warning"
    />

    <p v-if="profile" class="description" data-testid="gender-current">
      {{ t('users.player.correctGender.current', { gender: genderLabel(profile.gender) }) }}
    </p>

    <a-form layout="vertical">
      <a-form-item
        :label="t('users.player.correctGender.newGender')"
        required
        :validate-status="genderError ? 'error' : undefined"
        :help="genderError || undefined"
      >
        <a-radio-group v-model:value="gender" button-style="solid" data-testid="gender-choice">
          <a-radio-button
            v-for="option in GENDERS"
            :key="option"
            :value="option"
            :disabled="option === profile?.gender"
            :data-testid="`gender-${option}`"
          >
            {{ genderLabel(option) }}
          </a-radio-button>
        </a-radio-group>
      </a-form-item>

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
          data-testid="gender-reason"
        />
      </a-form-item>
    </a-form>

    <template #footer>
      <a-button data-testid="gender-cancel" @click="close">{{ t('users.cancel') }}</a-button>
      <a-button type="primary" :loading="submitting" data-testid="gender-submit" @click="submit">
        {{ t('users.player.correctGender.submit') }}
      </a-button>
    </template>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { message } from 'ant-design-vue'
import { GENDERS, type AdminPlayerProfile, type Gender } from '../../../api/players.api'
import { usePlayersStore } from '../../../stores/players.store'
import { getApiErrorMessage } from '../../../utils/axios'

/** Corrects a player's gender. The player is notified, so the modal says so, and a reason is required. */
const props = defineProps<{ open: boolean; profile: AdminPlayerProfile | null }>()
const emit = defineEmits<{ 'update:open': [open: boolean] }>()

const { t } = useI18n()
const store = usePlayersStore()

const gender = ref<Gender | undefined>(undefined)
const reason = ref('')
const genderError = ref('')
const reasonError = ref('')
const errorMessage = ref('')
const submitting = ref(false)

const genderLabel = (value: Gender) => t(`users.player.gender.${value}`)

watch(
  () => props.open,
  (open) => {
    if (!open) return
    // There are two genders: a correction can only go to the other one.
    gender.value = GENDERS.find((option) => option !== props.profile?.gender)
    reason.value = ''
    genderError.value = ''
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
  genderError.value =
    gender.value && gender.value !== props.profile.gender ? '' : t('users.player.correctGender.newGenderRequired')
  reasonError.value = reason.value.trim() ? '' : t('users.reason.required')
  if (genderError.value || reasonError.value || !gender.value) return

  submitting.value = true
  try {
    await store.correctGender(props.profile.userId, gender.value, reason.value)
    void message.success(t('users.player.messages.genderCorrected'))
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
