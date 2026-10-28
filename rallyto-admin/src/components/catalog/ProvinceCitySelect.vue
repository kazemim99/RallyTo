<template>
  <div class="province-city" :data-testid="testId">
    <a-select
      :value="provinceId"
      class="select-province"
      show-search
      option-filter-prop="label"
      :allow-clear="allowClear"
      :disabled="disabled"
      :options="provinceOptions"
      :placeholder="allowClear ? t('catalog.location.allProvinces') : t('catalog.location.chooseProvince')"
      :aria-label="t('catalog.location.province')"
      :status="invalid ? 'error' : undefined"
      :data-testid="`${testId}-province`"
      @change="changeProvince"
    />
    <a-select
      :value="cityId"
      class="select-city"
      show-search
      option-filter-prop="label"
      :allow-clear="allowClear"
      :disabled="disabled || !provinceId"
      :loading="loadingCities"
      :options="cityOptions"
      :placeholder="allowClear ? t('catalog.location.allCities') : t('catalog.location.chooseCity')"
      :aria-label="t('catalog.location.city')"
      :status="invalid ? 'error' : undefined"
      :data-testid="`${testId}-city`"
      @change="changeCity"
    />
    <span v-if="loadError" class="load-error" :data-testid="`${testId}-load-error`">{{ loadError }}</span>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useLocationsStore } from '../../stores/locations.store'

/**
 * A province, then a city in it. The lists come from the locations store, which loads each one once per session.
 * Changing the province clears the city. `change` fires once per pick, after both models are updated.
 */
const props = withDefaults(
  defineProps<{
    provinceId: number | undefined
    cityId: number | undefined
    allowClear?: boolean
    disabled?: boolean
    invalid?: boolean
    testId?: string
  }>(),
  { allowClear: false, disabled: false, invalid: false, testId: 'location' },
)
const emit = defineEmits<{
  'update:provinceId': [value: number | undefined]
  'update:cityId': [value: number | undefined]
  change: [value: { provinceId: number | undefined; cityId: number | undefined }]
}>()

const { t } = useI18n()
const locations = useLocationsStore()

const loadingCities = ref(false)
const loadError = ref('')

const provinceOptions = computed(() => locations.provinces.map((p) => ({ value: p.id, label: p.name })))
const cityOptions = computed(() => locations.citiesOf(props.provinceId).map((c) => ({ value: c.id, label: c.name })))

async function loadCities(provinceId: number | undefined) {
  if (!provinceId) return
  loadingCities.value = true
  try {
    await locations.loadCities(provinceId)
  } catch {
    loadError.value = t('catalog.location.loadFailed')
  } finally {
    loadingCities.value = false
  }
}

function changeProvince(value: unknown) {
  const provinceId = (value as number | undefined) || undefined
  emit('update:provinceId', provinceId)
  emit('update:cityId', undefined)
  emit('change', { provinceId, cityId: undefined })
}

function changeCity(value: unknown) {
  const cityId = (value as number | undefined) || undefined
  emit('update:cityId', cityId)
  emit('change', { provinceId: props.provinceId, cityId })
}

watch(() => props.provinceId, loadCities)

onMounted(async () => {
  try {
    await locations.loadProvinces()
  } catch {
    loadError.value = t('catalog.location.loadFailed')
  }
  await loadCities(props.provinceId)
})
</script>

<style scoped>
.province-city {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}

.select-province,
.select-city {
  width: 180px;
  max-width: 100%;
}

.load-error {
  color: #ff4d4f;
}
</style>
