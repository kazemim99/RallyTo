<template>
  <div class="jalali-date" dir="rtl" :data-testid="testId">
    <a-select
      v-model:value="parts.day"
      :options="dayOptions"
      :placeholder="t('jalaliDate.day')"
      :aria-label="t('jalaliDate.day')"
      allow-clear
      :virtual="false"
      class="part-day"
      :data-testid="`${testId}-day`"
    />
    <a-select
      v-model:value="parts.month"
      :options="monthOptions"
      :placeholder="t('jalaliDate.month')"
      :aria-label="t('jalaliDate.month')"
      allow-clear
      :virtual="false"
      class="part-month"
      :data-testid="`${testId}-month`"
    />
    <a-select
      v-model:value="parts.year"
      :options="yearOptions"
      :placeholder="t('jalaliDate.year')"
      :aria-label="t('jalaliDate.year')"
      allow-clear
      :virtual="false"
      class="part-year"
      :data-testid="`${testId}-year`"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { JALALI_MONTH_NAMES, formatJalaliDay, jalaliMonthLength, parseJalaliDay, tehranJalaliDay } from '../../utils/date'
import { toPersianDigits } from '../../utils/digits'

/**
 * A Jalali calendar day picked from day, month and year lists, so no day that does not exist can be entered. The
 * model is the API's wire format, `yyyy/MM/dd` with ASCII digits, and an empty string until all three are chosen.
 */
const props = withDefaults(
  defineProps<{
    modelValue: string
    /** Prefix of the test ids: `<testId>-day`, `<testId>-month`, `<testId>-year`. */
    testId: string
    /** The years offered; by default two years back to next year. */
    years?: number[]
  }>(),
  { years: undefined },
)
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

const { t } = useI18n()

const parts = reactive<{ year?: number; month?: number; day?: number }>({})

const yearOptions = computed(() => {
  const thisYear = tehranJalaliDay().year
  const years = props.years ?? [thisYear - 2, thisYear - 1, thisYear, thisYear + 1]
  return years.map((year) => ({ value: year, label: toPersianDigits(year) }))
})
const monthOptions = JALALI_MONTH_NAMES.map((name, index) => ({ value: index + 1, label: name }))
const dayOptions = computed(() => {
  const length = parts.year && parts.month ? jalaliMonthLength(parts.year, parts.month) : 31
  return Array.from({ length }, (_, index) => ({ value: index + 1, label: toPersianDigits(index + 1) }))
})

const current = () =>
  parts.year && parts.month && parts.day ? formatJalaliDay({ year: parts.year, month: parts.month, day: parts.day }) : ''

// The model set from outside (a preset, a reset): show it; an emptied model clears a complete pick, not a partial one.
watch(
  () => props.modelValue,
  (value) => {
    if (value === current()) return
    const day = parseJalaliDay(value)
    if (day) Object.assign(parts, day)
    else if (!value && current()) Object.assign(parts, { year: undefined, month: undefined, day: undefined })
  },
  { immediate: true },
)

watch(
  () => [parts.year, parts.month, parts.day],
  () => {
    // 31 Mehr, 30 Esfand in a common year: the day follows the month's length.
    if (parts.year && parts.month && parts.day) {
      const length = jalaliMonthLength(parts.year, parts.month)
      if (parts.day > length) parts.day = length
    }
    const value = current()
    if (value !== props.modelValue) emit('update:modelValue', value)
  },
)
</script>

<style scoped>
.jalali-date {
  display: inline-flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}

.part-day {
  width: 76px;
}

.part-month {
  width: 120px;
}

.part-year {
  width: 96px;
}
</style>
