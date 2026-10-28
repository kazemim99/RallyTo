<template>
  <a-modal :open="open" :title="t('candidates.bulk.title')" :width="680" :mask-closable="false" @cancel="close">
    <a-alert v-if="errorMessage" class="modal-alert" type="error" show-icon :message="errorMessage" data-testid="bulk-error" />
    <p data-testid="bulk-description">{{ t('candidates.bulk.description', { count: toPersianDigits(candidates.length) }) }}</p>
    <ul class="names" data-testid="bulk-names">
      <li v-for="candidate in candidates" :key="candidate.id">{{ candidate.name }}</li>
    </ul>
    <a-alert class="modal-alert" type="info" show-icon :message="t('catalog.sportsEditor.laterHint')" data-testid="bulk-hint" />

    <a-form layout="vertical">
      <a-form-item
        :label="t('venues.form.sports')"
        required
        :validate-status="sportsError ? 'error' : undefined"
        :help="sportsError || undefined"
      >
        <VenueSportsEditor v-model="sports" :sports="sportsStore.items" :invalid="!!sportsError" />
      </a-form-item>
    </a-form>

    <template #footer>
      <a-button data-testid="bulk-cancel" @click="close">{{ t('catalog.cancel') }}</a-button>
      <a-button type="primary" :loading="submitting" data-testid="bulk-submit" @click="submit">
        {{ t('candidates.bulk.submit') }}
      </a-button>
    </template>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { message } from 'ant-design-vue'
import type { VenueCandidate } from '../../../api/venueCandidates.api'
import type { VenueSport } from '../../../api/venues.api'
import VenueSportsEditor from '../../../components/catalog/VenueSportsEditor.vue'
import { useSportsStore } from '../../../stores/sports.store'
import { useVenueCandidatesStore } from '../../../stores/venueCandidates.store'
import { getApiErrorMessage } from '../../../utils/axios'
import { toPersianDigits } from '../../../utils/digits'

/** Approves every selected candidate with one set of sports; names and addresses come from Google. */
const props = defineProps<{ open: boolean; candidates: VenueCandidate[] }>()
const emit = defineEmits<{ 'update:open': [open: boolean]; approved: [] }>()

const { t } = useI18n()
const store = useVenueCandidatesStore()
const sportsStore = useSportsStore()

const sports = ref<VenueSport[]>([])
const sportsError = ref('')
const errorMessage = ref('')
const submitting = ref(false)

watch(
  () => props.open,
  (open) => {
    if (!open) return
    sports.value = []
    sportsError.value = ''
    errorMessage.value = ''
    submitting.value = false
    void sportsStore.ensureLoaded()
  },
  { immediate: true },
)

watch(sports, (value) => {
  if (value.length > 0) sportsError.value = ''
})

function close() {
  if (!submitting.value) emit('update:open', false)
}

async function submit() {
  if (submitting.value || props.candidates.length === 0) return
  errorMessage.value = ''
  sportsError.value = sports.value.length > 0 ? '' : t('catalog.sportsEditor.required')
  if (sportsError.value) return

  const count = props.candidates.length
  submitting.value = true
  try {
    await store.bulkApprove(
      props.candidates.map((candidate) => candidate.id),
      sports.value.map((sport) => ({ ...sport })),
    )
    void message.success(t('candidates.messages.bulkApproved', { count: toPersianDigits(count) }))
    submitting.value = false
    emit('approved')
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

.names {
  max-height: 140px;
  overflow-y: auto;
  padding-inline-start: 20px;
  color: var(--ty-text-secondary);
}
</style>
