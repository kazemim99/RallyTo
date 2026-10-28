<template>
  <a-drawer
    :open="open"
    :title="venue ? t('venues.form.editTitle', { name: venue.name }) : t('venues.form.createTitle')"
    :width="620"
    :mask-closable="false"
    data-testid="venue-drawer"
    @close="close"
  >
    <a-alert
      v-if="errorMessage && !conflict"
      class="form-alert"
      type="error"
      show-icon
      :message="errorMessage"
      data-testid="venue-error"
    />

    <!-- The server refused a near-duplicate name: show what it collides with, and let the admin insist. -->
    <a-alert
      v-if="conflict"
      class="form-alert"
      type="warning"
      show-icon
      :message="t('venues.form.conflictTitle')"
      data-testid="venue-similar-conflict"
    >
      <template #description>
        <p v-if="errorMessage" class="conflict-message">{{ errorMessage }}</p>
        <ul class="similar-list">
          <li v-for="match in conflict" :key="match.id" data-testid="venue-conflict-match">
            <strong>{{ match.name }}</strong>
            <span v-if="match.address" class="muted"> — {{ match.address }}</span>
          </li>
        </ul>
        <a-button danger :loading="submitting" data-testid="venue-save-anyway" @click="submit(true)">
          {{ t('venues.form.saveAnyway') }}
        </a-button>
      </template>
    </a-alert>

    <a-form layout="vertical">
      <a-form-item
        :label="t('catalog.location.city')"
        required
        :extra="venue ? t('venues.form.cityFixed') : undefined"
        :validate-status="cityError ? 'error' : undefined"
        :help="cityError || undefined"
      >
        <a-input v-if="venue" :value="venue.cityName" disabled data-testid="venue-city-fixed" />
        <a-form-item-rest v-else>
          <ProvinceCitySelect
            v-model:province-id="provinceId"
            v-model:city-id="cityId"
            :invalid="!!cityError"
            test-id="venue-location"
          />
        </a-form-item-rest>
      </a-form-item>

      <VenueDetailsFields :form="form" :errors="errors" :sports="sportsStore.items">
        <template #after-name>
          <a-alert
            v-if="similar.length > 0 && !conflict"
            class="similar-alert"
            type="warning"
            show-icon
            :message="t('venues.form.similarTitle')"
            data-testid="venue-similar"
          >
            <template #description>
              <ul class="similar-list">
                <li v-for="match in similar" :key="match.id" data-testid="venue-similar-match">
                  <strong>{{ match.name }}</strong>
                  <span v-if="match.address" class="muted"> — {{ match.address }}</span>
                </li>
              </ul>
              <span class="muted">{{ t('venues.form.similarHint') }}</span>
            </template>
          </a-alert>
        </template>
      </VenueDetailsFields>
    </a-form>

    <template #footer>
      <div class="drawer-footer">
        <a-button data-testid="venue-cancel" @click="close">{{ t('catalog.cancel') }}</a-button>
        <a-button type="primary" :loading="submitting" data-testid="venue-submit" @click="submit(false)">
          {{ venue ? t('venues.form.submitEdit') : t('venues.form.submitCreate') }}
        </a-button>
      </div>
    </template>
  </a-drawer>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { message } from 'ant-design-vue'
import { SIMILAR_VENUE_EXISTS, type Venue } from '../../../api/venues.api'
import ProvinceCitySelect from '../../../components/catalog/ProvinceCitySelect.vue'
import VenueDetailsFields from '../../../components/catalog/VenueDetailsFields.vue'
import {
  SIMILAR_LOOKUP_DELAY_MS,
  SIMILAR_LOOKUP_MIN_LENGTH,
  emptyVenueForm,
  toVenueDetails,
  validateVenueForm,
  type VenueFormErrors,
  type VenueFormState,
} from '../../../components/catalog/venueForm'
import { useSportsStore } from '../../../stores/sports.store'
import { useVenuesStore } from '../../../stores/venues.store'
import { getApiErrorCode, getApiErrorMessage } from '../../../utils/axios'

/**
 * Adds a club by hand (venue = null) or edits one. While the name is typed, clubs with a similar name in the same
 * city are looked up (debounced) and listed as a warning. If the server still refuses a new club as a near
 * duplicate (SIMILAR_VENUE_EXISTS), the matches are shown with a button that sends it again with allowSimilar.
 * A club's city is fixed once it exists.
 */
const props = defineProps<{ open: boolean; venue: Venue | null }>()
const emit = defineEmits<{ 'update:open': [open: boolean] }>()

const { t } = useI18n()
const store = useVenuesStore()
const sportsStore = useSportsStore()

const provinceId = ref<number | undefined>()
const cityId = ref<number | undefined>()
const form = reactive<VenueFormState>(emptyVenueForm())
const errors = reactive<VenueFormErrors>({})
const cityError = ref('')
const errorMessage = ref('')
const submitting = ref(false)
const similar = ref<Venue[]>([])
/** The clubs the server's SIMILAR_VENUE_EXISTS refers to; null when there is no such refusal on screen. */
const conflict = ref<Venue[] | null>(null)

const targetCityId = computed(() => props.venue?.cityId ?? cityId.value)

// --- Similar-name lookup ------------------------------------------------------------------------------------------

let lookupTimer: ReturnType<typeof setTimeout> | undefined
let latestLookup = 0

function cancelLookup() {
  clearTimeout(lookupTimer)
  lookupTimer = undefined
  latestLookup++
}

const others = (venues: Venue[]) => venues.filter((venue) => venue.id !== props.venue?.id)

async function lookUpSimilar(city: number, name: string) {
  const ticket = ++latestLookup
  try {
    const found = await store.findSimilar(city, name)
    if (ticket === latestLookup) similar.value = others(found)
  } catch {
    // The warning is advisory; the server checks again on save.
  }
}

watch([() => form.name, targetCityId], ([name, city]) => {
  conflict.value = null
  cancelLookup()
  if (!props.open || !city || name.trim().length < SIMILAR_LOOKUP_MIN_LENGTH) {
    similar.value = []
    return
  }
  lookupTimer = setTimeout(() => void lookUpSimilar(city, name), SIMILAR_LOOKUP_DELAY_MS)
})

onBeforeUnmount(cancelLookup)

// --- Open, save ---------------------------------------------------------------------------------------------------

function reset() {
  const venue = props.venue
  provinceId.value = undefined
  cityId.value = undefined
  Object.assign(form, emptyVenueForm(), venue
    ? {
        name: venue.name,
        address: venue.address ?? '',
        phone: venue.phone ?? '',
        latitude: venue.latitude,
        longitude: venue.longitude,
        sports: venue.sports.map((sport) => ({ ...sport })),
      }
    : {})
  for (const key of Object.keys(errors) as (keyof VenueFormErrors)[]) delete errors[key]
  cityError.value = ''
  errorMessage.value = ''
  submitting.value = false
  conflict.value = null
  similar.value = []
}

watch(
  () => props.open,
  (open) => {
    if (open) {
      reset()
      void sportsStore.ensureLoaded()
    } else {
      cancelLookup()
    }
  },
  { immediate: true },
)

function validate(): boolean {
  for (const key of Object.keys(errors) as (keyof VenueFormErrors)[]) delete errors[key]
  Object.assign(errors, validateVenueForm(form, t))
  cityError.value = targetCityId.value ? '' : t('venues.form.cityRequired')
  return Object.keys(errors).length === 0 && !cityError.value
}

function close() {
  if (!submitting.value) emit('update:open', false)
}

async function showConflict(city: number) {
  try {
    conflict.value = others(await store.findSimilar(city, form.name))
  } catch {
    conflict.value = [...similar.value]
  }
}

async function submit(allowSimilar: boolean) {
  if (submitting.value) return
  errorMessage.value = ''
  if (!validate()) return
  const city = targetCityId.value!

  submitting.value = true
  try {
    if (props.venue) {
      await store.update(props.venue.id, { cityId: city, ...toVenueDetails(form) })
      void message.success(t('venues.messages.updated'))
    } else {
      await store.create({ cityId: city, ...toVenueDetails(form), allowSimilar })
      void message.success(t('venues.messages.created'))
    }
    submitting.value = false
    conflict.value = null
    emit('update:open', false)
  } catch (failure) {
    errorMessage.value = getApiErrorMessage(failure)
    if (!props.venue && getApiErrorCode(failure) === SIMILAR_VENUE_EXISTS) {
      cancelLookup()
      await showConflict(city)
    }
    submitting.value = false
  }
}
</script>

<style scoped>
.form-alert {
  margin-bottom: 16px;
}

.similar-alert {
  margin: -8px 0 16px;
}

.similar-list {
  margin: 4px 0 8px;
  padding-inline-start: 20px;
}

.conflict-message {
  margin-bottom: 4px;
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
