<template>
  <a-form-item
    :label="t('venues.form.name')"
    required
    :validate-status="errors.name ? 'error' : undefined"
    :help="errors.name || undefined"
  >
    <a-input v-model:value="form.name" :maxlength="120" data-testid="venue-name" />
  </a-form-item>
  <slot name="after-name" />

  <a-form-item :label="t('venues.form.address')">
    <a-textarea v-model:value="form.address" :rows="2" :maxlength="300" data-testid="venue-address" />
  </a-form-item>

  <a-form-item :label="t('venues.form.phone')">
    <a-input v-model:value="form.phone" dir="ltr" inputmode="tel" :maxlength="30" data-testid="venue-phone" />
  </a-form-item>

  <a-form-item
    :label="t('venues.form.coordinates')"
    :extra="errors.coordinates ? undefined : t('venues.form.coordinatesHelp')"
    :validate-status="errors.coordinates ? 'error' : undefined"
    :help="errors.coordinates || undefined"
  >
    <a-form-item-rest>
      <div class="coordinates" dir="ltr">
        <a-input-number
          v-model:value="form.latitude"
          class="coordinate"
          :min="-90"
          :max="90"
          :step="0.000001"
          :parser="parseCoordinate"
          :placeholder="t('venues.form.latitude')"
          :aria-label="t('venues.form.latitude')"
          data-testid="venue-latitude"
        />
        <a-input-number
          v-model:value="form.longitude"
          class="coordinate"
          :min="-180"
          :max="180"
          :step="0.000001"
          :parser="parseCoordinate"
          :placeholder="t('venues.form.longitude')"
          :aria-label="t('venues.form.longitude')"
          data-testid="venue-longitude"
        />
      </div>
    </a-form-item-rest>
  </a-form-item>

  <a-form-item
    :label="t('venues.form.sports')"
    required
    :validate-status="errors.sports ? 'error' : undefined"
    :help="errors.sports || undefined"
  >
    <VenueSportsEditor v-model="form.sports" :sports="sports" :invalid="!!errors.sports" />
  </a-form-item>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import type { Sport } from '../../api/sports.api'
import { toAsciiDigits } from '../../utils/digits'
import VenueSportsEditor from './VenueSportsEditor.vue'
import type { VenueFormErrors, VenueFormState } from './venueForm'

/**
 * The fields of a club's details, bound to the parent's reactive form object (the parent owns it, resets it and
 * builds the request from it). Rendered inside the parent's `<a-form>`.
 */
defineProps<{ form: VenueFormState; errors: VenueFormErrors; sports: Sport[] }>()

const { t } = useI18n()

/** Persian digits and the Persian decimal separator are read as ASCII. */
const parseCoordinate = (value: string) =>
  toAsciiDigits(value)
    .replace(/[٫,]/g, '.')
    .replace(/[^\d.-]/g, '')
</script>

<style scoped>
.coordinates {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.coordinate {
  width: 180px;
}
</style>
