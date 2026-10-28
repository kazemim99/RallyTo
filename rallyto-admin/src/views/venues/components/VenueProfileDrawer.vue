<template>
  <a-drawer
    :open="open"
    :title="venue ? t('venues.profile.title', { name: venue.name }) : ''"
    :width="620"
    :mask-closable="false"
    data-testid="venue-profile-drawer"
    @close="close"
  >
    <a-alert v-if="errorMessage" class="form-alert" type="error" show-icon :message="errorMessage" data-testid="profile-error" />

    <h4 class="section-title">{{ t('venues.profile.photos') }}</h4>
    <p class="muted">{{ t('venues.profile.photosHelp', { max: toPersianDigits(MAX_VENUE_IMAGES) }) }}</p>
    <div class="photos" data-testid="profile-photos">
      <div v-for="(path, index) in images" :key="path" class="photo" data-testid="profile-photo">
        <img :src="venueImageSrc(path) ?? ''" :alt="venue?.name ?? ''" loading="lazy" />
        <a-tag v-if="index === 0" color="green" class="cover-tag">{{ t('venues.profile.cover') }}</a-tag>
        <a-button
          size="small"
          danger
          class="photo-remove"
          :disabled="busy"
          data-testid="profile-photo-remove"
          @click="removePhoto(path)"
        >
          {{ t('venues.profile.removePhoto') }}
        </a-button>
      </div>
      <a-upload
        v-if="images.length < MAX_VENUE_IMAGES"
        accept="image/jpeg,image/png,image/webp"
        :show-upload-list="false"
        :multiple="true"
        :disabled="busy"
        :custom-request="uploadPhoto"
        data-testid="profile-photo-upload"
      >
        <a-button :loading="busy" data-testid="profile-photo-add">
          <template #icon><PlusOutlined /></template>
          {{ t('venues.profile.addPhoto') }}
        </a-button>
      </a-upload>
    </div>

    <a-divider />

    <a-form layout="vertical">
      <a-form-item :label="t('venues.profile.tagline')">
        <a-input v-model:value="form.tagline" :maxlength="200" data-testid="profile-tagline" />
      </a-form-item>
      <a-form-item :label="t('venues.profile.description')">
        <a-textarea v-model:value="form.description" :rows="6" :maxlength="4000" show-count data-testid="profile-description" />
      </a-form-item>
      <a-form-item :label="t('venues.profile.workingHours')">
        <a-input v-model:value="form.workingHours" :maxlength="200" data-testid="profile-hours" />
      </a-form-item>
      <a-form-item :label="t('venues.profile.website')" :extra="t('venues.profile.linkHelp')">
        <a-input v-model:value="form.website" dir="ltr" placeholder="https://" data-testid="profile-website" />
      </a-form-item>
      <a-form-item :label="t('venues.profile.instagram')">
        <a-input v-model:value="form.instagram" dir="ltr" placeholder="https://instagram.com/" data-testid="profile-instagram" />
      </a-form-item>
      <a-form-item :label="t('venues.profile.telegram')">
        <a-input v-model:value="form.telegram" dir="ltr" placeholder="https://t.me/" data-testid="profile-telegram" />
      </a-form-item>
      <a-form-item :label="t('venues.profile.amenities')" :extra="t('venues.profile.tagsHelp')">
        <a-select v-model:value="form.amenities" mode="tags" :token-separators="[',', '،']" :open="false" data-testid="profile-amenities" />
      </a-form-item>
      <a-form-item :label="t('venues.profile.courtTypes')">
        <a-select v-model:value="form.courtTypes" mode="tags" :token-separators="[',', '،']" :open="false" data-testid="profile-court-types" />
      </a-form-item>
      <p v-if="venue?.googleRating" class="muted" data-testid="profile-google-rating">
        {{ t('venues.profile.googleRating', { rating: toPersianDigits(venue.googleRating), count: toPersianDigits(venue.googleReviewCount ?? 0) }) }}
      </p>
      <p v-if="venue?.sourceUrl" class="muted">
        {{ t('venues.profile.source') }}
        <a :href="venue.sourceUrl" target="_blank" rel="noopener noreferrer" dir="ltr">{{ venue.sourceUrl }}</a>
      </p>
    </a-form>

    <template #footer>
      <div class="drawer-footer">
        <a-button data-testid="profile-cancel" @click="close">{{ t('catalog.cancel') }}</a-button>
        <a-button type="primary" :loading="submitting" :disabled="busy" data-testid="profile-submit" @click="save">
          {{ t('venues.form.submitEdit') }}
        </a-button>
      </div>
    </template>
  </a-drawer>
</template>

<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { message } from 'ant-design-vue'
import { PlusOutlined } from '@ant-design/icons-vue'
import { MAX_VENUE_IMAGES, venueImageSrc, type Venue, type VenueProfileRequest } from '../../../api/venues.api'
import { useVenuesStore } from '../../../stores/venues.store'
import { toPersianDigits } from '../../../utils/digits'
import { getApiErrorMessage } from '../../../utils/axios'

/**
 * Everything about a club that is not its name, place and sports: the descriptive profile and its photos. Photos
 * are added and removed at once (each is its own request); the text fields are saved together with the button.
 * The first photo is the cover.
 */
const props = defineProps<{ open: boolean; venue: Venue | null }>()
const emit = defineEmits<{ 'update:open': [open: boolean] }>()

const { t } = useI18n()
const store = useVenuesStore()

const emptyForm = (): VenueProfileRequest => ({
  tagline: null,
  description: null,
  website: null,
  instagram: null,
  telegram: null,
  workingHours: null,
  amenities: [],
  courtTypes: [],
})

const form = reactive<VenueProfileRequest>(emptyForm())
const images = ref<string[]>([])
const errorMessage = ref('')
const submitting = ref(false)
const busy = ref(false)

watch(
  () => props.open,
  (open) => {
    if (!open || !props.venue) return
    const venue = props.venue
    Object.assign(form, {
      tagline: venue.tagline,
      description: venue.description,
      website: venue.website,
      instagram: venue.instagram,
      telegram: venue.telegram,
      workingHours: venue.workingHours,
      amenities: [...venue.amenities],
      courtTypes: [...venue.courtTypes],
    })
    images.value = [...venue.images]
    errorMessage.value = ''
    submitting.value = false
    busy.value = false
  },
  { immediate: true },
)

const blankToNull = (value: string | null) => (value?.trim() ? value.trim() : null)

function close() {
  if (!submitting.value && !busy.value) emit('update:open', false)
}

async function save() {
  if (!props.venue || submitting.value) return
  errorMessage.value = ''
  submitting.value = true
  try {
    await store.updateProfile(props.venue.id, {
      tagline: blankToNull(form.tagline),
      description: blankToNull(form.description),
      website: blankToNull(form.website),
      instagram: blankToNull(form.instagram),
      telegram: blankToNull(form.telegram),
      workingHours: blankToNull(form.workingHours),
      amenities: form.amenities.map((a) => a.trim()).filter(Boolean),
      courtTypes: form.courtTypes.map((a) => a.trim()).filter(Boolean),
    })
    void message.success(t('venues.profile.saved'))
    submitting.value = false
    emit('update:open', false)
  } catch (failure) {
    errorMessage.value = getApiErrorMessage(failure)
    submitting.value = false
  }
}

async function uploadPhoto(options: { file: string | Blob | File; onSuccess?: (body: unknown) => void; onError?: (e: Error) => void }) {
  if (!props.venue || !(options.file instanceof File)) return
  errorMessage.value = ''
  busy.value = true
  try {
    const venue = await store.addImage(props.venue.id, options.file)
    images.value = [...venue.images]
    options.onSuccess?.(venue)
  } catch (failure) {
    errorMessage.value = getApiErrorMessage(failure)
    options.onError?.(failure instanceof Error ? failure : new Error(String(failure)))
  } finally {
    busy.value = false
  }
}

async function removePhoto(path: string) {
  if (!props.venue || busy.value) return
  errorMessage.value = ''
  busy.value = true
  try {
    const venue = await store.removeImage(props.venue.id, path)
    images.value = [...venue.images]
  } catch (failure) {
    errorMessage.value = getApiErrorMessage(failure)
  } finally {
    busy.value = false
  }
}
</script>

<style scoped>
.form-alert {
  margin-bottom: 16px;
}

.section-title {
  margin-bottom: 4px;
}

.muted {
  color: var(--ty-text-secondary);
}

.photos {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  align-items: flex-start;
}

.photo {
  position: relative;
  width: 168px;
}

.photo img {
  display: block;
  width: 168px;
  height: 112px;
  object-fit: cover;
  border-radius: 6px;
  background: var(--ty-text-secondary);
}

.cover-tag {
  position: absolute;
  top: 6px;
  inset-inline-start: 6px;
  margin: 0;
}

.photo-remove {
  margin-top: 6px;
}

.drawer-footer {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}
</style>
