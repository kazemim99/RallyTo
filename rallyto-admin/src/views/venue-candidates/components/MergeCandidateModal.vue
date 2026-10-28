<template>
  <a-modal
    :open="open"
    :title="t('candidates.merge.title', { name: candidate?.name ?? '' })"
    :mask-closable="false"
    @cancel="close"
  >
    <a-alert v-if="errorMessage" class="modal-alert" type="error" show-icon :message="errorMessage" data-testid="merge-error" />
    <p class="muted">{{ t('candidates.merge.description') }}</p>

    <a-form layout="vertical">
      <a-form-item
        :label="t('candidates.merge.venue')"
        required
        :validate-status="venueError ? 'error' : undefined"
        :help="venueError || undefined"
      >
        <a-select
          v-model:value="venueId"
          show-search
          option-filter-prop="label"
          :loading="loading"
          :options="venueOptions"
          :placeholder="t('candidates.merge.venuePlaceholder')"
          :not-found-content="loading ? undefined : t('candidates.merge.noVenues')"
          data-testid="merge-venue"
        />
      </a-form-item>
    </a-form>

    <template #footer>
      <a-button data-testid="merge-cancel" @click="close">{{ t('catalog.cancel') }}</a-button>
      <a-button type="primary" :loading="submitting" data-testid="merge-submit" @click="submit">
        {{ t('candidates.merge.submit') }}
      </a-button>
    </template>
  </a-modal>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { message } from 'ant-design-vue'
import type { VenueCandidate } from '../../../api/venueCandidates.api'
import type { Venue } from '../../../api/venues.api'
import { useVenueCandidatesStore } from '../../../stores/venueCandidates.store'
import { useVenuesStore } from '../../../stores/venues.store'
import { getApiErrorMessage } from '../../../utils/axios'

/** Marks a candidate as a club already in the catalog: the admin picks it among the clubs of the same city. */
const props = defineProps<{ open: boolean; candidate: VenueCandidate | null }>()
const emit = defineEmits<{ 'update:open': [open: boolean] }>()

const { t } = useI18n()
const store = useVenueCandidatesStore()
const venuesStore = useVenuesStore()

const venues = ref<Venue[]>([])
const venueId = ref<string | undefined>()
const venueError = ref('')
const errorMessage = ref('')
const loading = ref(false)
const submitting = ref(false)

const venueOptions = computed(() =>
  venues.value.map((venue) => ({
    value: venue.id,
    label: venue.address ? `${venue.name} — ${venue.address}` : venue.name,
  })),
)

watch(
  () => props.open,
  async (open) => {
    if (!open) return
    venues.value = []
    venueId.value = undefined
    venueError.value = ''
    errorMessage.value = ''
    submitting.value = false
    const candidate = props.candidate
    if (!candidate) return
    loading.value = true
    try {
      const page = await venuesStore.listInCity(candidate.cityId)
      if (props.candidate?.id === candidate.id) venues.value = page?.items ?? []
    } catch (failure) {
      errorMessage.value = getApiErrorMessage(failure)
    } finally {
      loading.value = false
    }
  },
  { immediate: true },
)

function close() {
  if (!submitting.value) emit('update:open', false)
}

async function submit() {
  if (!props.candidate || submitting.value) return
  errorMessage.value = ''
  venueError.value = venueId.value ? '' : t('candidates.merge.venueRequired')
  if (venueError.value || !venueId.value) return

  submitting.value = true
  try {
    await store.merge(props.candidate.id, venueId.value)
    void message.success(t('candidates.messages.merged'))
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

.muted {
  color: var(--ty-text-secondary);
}
</style>
