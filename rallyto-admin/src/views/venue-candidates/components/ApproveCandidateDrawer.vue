<template>
  <a-drawer
    :open="open"
    :title="t('candidates.approve.title', { name: candidate?.name ?? '' })"
    :width="620"
    :mask-closable="false"
    data-testid="approve-drawer"
    @close="close"
  >
    <a-alert v-if="errorMessage" class="form-alert" type="error" show-icon :message="errorMessage" data-testid="approve-error" />
    <p class="muted">{{ t('candidates.approve.description') }}</p>
    <a-alert class="form-alert" type="info" show-icon :message="t('catalog.sportsEditor.laterHint')" data-testid="approve-hint" />

    <a-form layout="vertical">
      <VenueDetailsFields :form="form" :errors="errors" :sports="sportsStore.items" />
    </a-form>

    <template #footer>
      <div class="drawer-footer">
        <a-button data-testid="approve-cancel" @click="close">{{ t('catalog.cancel') }}</a-button>
        <a-button type="primary" :loading="submitting" data-testid="approve-submit" @click="submit">
          {{ t('candidates.approve.submit') }}
        </a-button>
      </div>
    </template>
  </a-drawer>
</template>

<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { message } from 'ant-design-vue'
import type { VenueCandidate } from '../../../api/venueCandidates.api'
import VenueDetailsFields from '../../../components/catalog/VenueDetailsFields.vue'
import {
  emptyVenueForm,
  toVenueDetails,
  validateVenueForm,
  type VenueFormErrors,
  type VenueFormState,
} from '../../../components/catalog/venueForm'
import { useSportsStore } from '../../../stores/sports.store'
import { useVenueCandidatesStore } from '../../../stores/venueCandidates.store'
import { getApiErrorMessage } from '../../../utils/axios'

/** Approves one candidate into a new club, with Google's name, address and position prefilled for review. */
const props = defineProps<{ open: boolean; candidate: VenueCandidate | null }>()
const emit = defineEmits<{ 'update:open': [open: boolean] }>()

const { t } = useI18n()
const store = useVenueCandidatesStore()
const sportsStore = useSportsStore()

const form = reactive<VenueFormState>(emptyVenueForm())
const errors = reactive<VenueFormErrors>({})
const errorMessage = ref('')
const submitting = ref(false)

function clearErrors() {
  for (const key of Object.keys(errors) as (keyof VenueFormErrors)[]) delete errors[key]
}

watch(
  () => props.open,
  (open) => {
    if (!open) return
    const candidate = props.candidate
    Object.assign(form, emptyVenueForm(), {
      name: candidate?.name ?? '',
      address: candidate?.address ?? '',
      latitude: candidate?.latitude ?? null,
      longitude: candidate?.longitude ?? null,
    })
    clearErrors()
    errorMessage.value = ''
    submitting.value = false
    void sportsStore.ensureLoaded()
  },
  { immediate: true },
)

function close() {
  if (!submitting.value) emit('update:open', false)
}

async function submit() {
  if (!props.candidate || submitting.value) return
  errorMessage.value = ''
  clearErrors()
  Object.assign(errors, validateVenueForm(form, t))
  if (Object.keys(errors).length > 0) return

  submitting.value = true
  try {
    await store.approve(props.candidate.id, toVenueDetails(form))
    void message.success(t('candidates.messages.approved'))
    submitting.value = false
    emit('update:open', false)
  } catch (failure) {
    errorMessage.value = getApiErrorMessage(failure)
    submitting.value = false
  }
}
</script>

<style scoped>
.form-alert {
  margin-bottom: 16px;
}

.muted {
  color: var(--ty-text-secondary);
}

.drawer-footer {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}
</style>
