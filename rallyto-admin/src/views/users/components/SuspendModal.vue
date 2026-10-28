<template>
  <a-modal :open="open" :title="t('users.suspend.title', { phone })" :mask-closable="false" @cancel="close">
    <a-alert
      v-if="errorMessage"
      class="modal-alert"
      type="error"
      show-icon
      :message="errorMessage"
      data-testid="suspend-error"
    />

    <a-form layout="vertical">
      <a-form-item :label="t('users.suspend.durationLabel')">
        <a-radio-group v-model:value="mode" button-style="solid" data-testid="suspend-duration">
          <a-radio-button v-for="days in DURATIONS" :key="days" :value="String(days)" :data-testid="`duration-${days}`">
            {{ t('users.suspend.days', { count: toPersianDigits(days) }) }}
          </a-radio-button>
          <a-radio-button value="custom" data-testid="duration-custom">{{ t('users.suspend.custom') }}</a-radio-button>
        </a-radio-group>
      </a-form-item>

      <a-form-item v-if="mode === 'custom'" :label="t('users.suspend.untilLabel')">
        <div class="jalali-picker" dir="rtl" data-testid="suspend-custom">
          <a-select
            v-model:value="custom.day"
            :options="dayOptions"
            :aria-label="t('users.suspend.day')"
            class="part-day"
            data-testid="custom-day"
          />
          <a-select
            v-model:value="custom.month"
            :options="monthOptions"
            :aria-label="t('users.suspend.month')"
            class="part-month"
            data-testid="custom-month"
          />
          <a-select
            v-model:value="custom.year"
            :options="yearOptions"
            :aria-label="t('users.suspend.year')"
            class="part-year"
            data-testid="custom-year"
          />
          <span class="time" dir="ltr">
            <a-select
              v-model:value="custom.hour"
              :options="hourOptions"
              :aria-label="t('users.suspend.hour')"
              class="part-time"
              data-testid="custom-hour"
            />
            <span aria-hidden="true">:</span>
            <a-select
              v-model:value="custom.minute"
              :options="minuteOptions"
              :aria-label="t('users.suspend.minute')"
              class="part-time"
              data-testid="custom-minute"
            />
          </span>
        </div>
      </a-form-item>

      <p v-if="untilError" class="until-error" data-testid="suspend-until-error">{{ untilError }}</p>
      <p v-else-if="previewUntil" class="until-preview" data-testid="suspend-preview">
        {{ t('users.suspend.preview', { date: formatDateTime(previewUntil) }) }}
      </p>

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
          data-testid="suspend-reason"
        />
      </a-form-item>
    </a-form>

    <template #footer>
      <a-button data-testid="suspend-cancel" @click="close">{{ t('users.cancel') }}</a-button>
      <a-button type="primary" danger :loading="submitting" data-testid="suspend-submit" @click="submit">
        {{ t('users.suspend.submit') }}
      </a-button>
    </template>
  </a-modal>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { message } from 'ant-design-vue'
import type { AdminAccount } from '../../../api/users.api'
import { useUsersStore } from '../../../stores/users.store'
import { getApiErrorMessage } from '../../../utils/axios'
import {
  JALALI_MONTH_NAMES,
  formatDateTime,
  jalaliMonthLength,
  tehranJalaliToUtc,
  toTehranJalali,
  type JalaliDateTime,
} from '../../../utils/date'
import { toPersianDigits } from '../../../utils/digits'
import { formatPhone } from '../../../utils/phone'

const props = defineProps<{ open: boolean; account: AdminAccount | null }>()
const emit = defineEmits<{ 'update:open': [open: boolean] }>()

const DURATIONS = [1, 3, 7, 30] as const
const DAY_MS = 86_400_000
const MINUTE_STEP = 5

const { t } = useI18n()
const store = useUsersStore()

const mode = ref<string>('1')
const custom = reactive<JalaliDateTime>({ year: 0, month: 1, day: 1, hour: 0, minute: 0 })
const reason = ref('')
const reasonError = ref('')
const untilError = ref('')
const errorMessage = ref('')
const submitting = ref(false)
/** Re-read on every change so the preview of a fixed duration counts from now, not from when the modal opened. */
const tick = ref(0)

const phone = computed(() => formatPhone(props.account?.phoneNumber))

const pad = (value: number) => toPersianDigits(String(value).padStart(2, '0'))
const range = (from: number, to: number, step = 1) =>
  Array.from({ length: Math.floor((to - from) / step) + 1 }, (_, index) => from + index * step)

const thisYear = computed(() => toTehranJalali(new Date()).year)
const yearOptions = computed(() =>
  [thisYear.value, thisYear.value + 1].map((year) => ({ value: year, label: toPersianDigits(year) })),
)
const monthOptions = JALALI_MONTH_NAMES.map((name, index) => ({ value: index + 1, label: name }))
const dayOptions = computed(() =>
  range(1, jalaliMonthLength(custom.year, custom.month)).map((day) => ({ value: day, label: toPersianDigits(day) })),
)
const hourOptions = range(0, 23).map((hour) => ({ value: hour, label: pad(hour) }))
const minuteOptions = range(0, 55, MINUTE_STEP).map((minute) => ({ value: minute, label: pad(minute) }))

// 30 Esfand in a common year, 31 Mehr: the day list shrinks, and the chosen day follows it.
watch(
  () => [custom.year, custom.month],
  () => {
    const length = jalaliMonthLength(custom.year, custom.month)
    if (custom.day > length) custom.day = length
  },
)

/** The chosen end as an instant, or null when the custom date does not exist. */
function chosenUntil(): Date | null {
  if (mode.value === 'custom') return tehranJalaliToUtc(custom)
  return new Date(Date.now() + Number(mode.value) * DAY_MS)
}

const previewUntil = computed(() => {
  void tick.value
  return chosenUntil()
})

watch([mode, custom], () => {
  untilError.value = ''
  tick.value++
})

function reset() {
  // The custom picker starts a day from now, on the next five-minute mark.
  const start = toTehranJalali(new Date(Date.now() + DAY_MS))
  Object.assign(custom, {
    year: start.year,
    month: start.month,
    day: start.day,
    hour: start.hour,
    minute: Math.floor(start.minute / MINUTE_STEP) * MINUTE_STEP,
  })
  mode.value = '1'
  reason.value = ''
  reasonError.value = ''
  untilError.value = ''
  errorMessage.value = ''
  submitting.value = false
}

watch(
  () => props.open,
  (open) => {
    if (open) reset()
  },
  { immediate: true },
)

function close() {
  if (!submitting.value) emit('update:open', false)
}

async function submit() {
  if (!props.account || submitting.value) return
  errorMessage.value = ''

  const until = chosenUntil()
  untilError.value = !until ? t('users.suspend.invalidDate') : until.getTime() <= Date.now() ? t('users.suspend.inPast') : ''
  reasonError.value = reason.value.trim() ? '' : t('users.reason.required')
  if (untilError.value || reasonError.value || !until) return

  submitting.value = true
  try {
    await store.suspend(props.account.userId, until, reason.value)
    void message.success(t('users.messages.suspended'))
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

.jalali-picker {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}

.part-day,
.part-time {
  width: 72px;
}

.part-month {
  width: 120px;
}

.part-year {
  width: 96px;
}

.time {
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.until-preview {
  color: var(--ty-text-secondary);
}

.until-error {
  color: #ff4d4f;
}
</style>
