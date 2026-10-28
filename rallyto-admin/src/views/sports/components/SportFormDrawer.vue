<template>
  <a-drawer
    :open="open"
    :title="sport ? t('sports.form.editTitle', { name: sport.nameFa }) : t('sports.form.createTitle')"
    :width="560"
    :mask-closable="false"
    data-testid="sport-drawer"
    @close="close"
  >
    <a-alert v-if="errorMessage" class="form-alert" type="error" show-icon :message="errorMessage" data-testid="sport-error" />

    <a-form layout="vertical">
      <a-form-item
        :label="t('sports.form.code')"
        required
        :extra="sport ? undefined : t('sports.form.codeHelp')"
        :validate-status="errors.code ? 'error' : undefined"
        :help="errors.code || undefined"
      >
        <a-input v-model:value="form.code" dir="ltr" :disabled="!!sport" :maxlength="40" data-testid="sport-code" />
      </a-form-item>

      <div class="two-columns">
        <a-form-item
          :label="t('sports.form.nameFa')"
          required
          :validate-status="errors.nameFa ? 'error' : undefined"
          :help="errors.nameFa || undefined"
        >
          <a-input v-model:value="form.nameFa" :maxlength="60" data-testid="sport-name-fa" />
        </a-form-item>
        <a-form-item
          :label="t('sports.form.nameEn')"
          required
          :validate-status="errors.nameEn ? 'error' : undefined"
          :help="errors.nameEn || undefined"
        >
          <a-input v-model:value="form.nameEn" dir="ltr" :maxlength="60" data-testid="sport-name-en" />
        </a-form-item>
      </div>

      <div class="two-columns">
        <a-form-item
          :label="t('sports.form.session')"
          required
          :validate-status="errors.session ? 'error' : undefined"
          :help="errors.session || undefined"
        >
          <a-input-number
            v-model:value="form.defaultSessionMinutes"
            class="full-width"
            :min="SESSION_MINUTES.min"
            :max="SESSION_MINUTES.max"
            :step="SESSION_MINUTES.step"
            :precision="0"
            :parser="parseNumber"
            data-testid="sport-session"
          />
        </a-form-item>
        <a-form-item :label="t('sports.form.sortOrder')">
          <a-input-number v-model:value="form.sortOrder" class="full-width" :min="0" :precision="0" :parser="parseNumber" data-testid="sport-sort" />
        </a-form-item>
      </div>

      <a-form-item
        :label="t('sports.form.formats')"
        required
        :validate-status="errors.formats ? 'error' : undefined"
        :help="errors.formats || undefined"
      >
        <a-form-item-rest>
          <div class="formats">
            <div v-for="format in PLAY_FORMATS" :key="format" class="format-row">
              <a-checkbox v-model:checked="form.formats[format].enabled" :data-testid="`sport-format-${format}`">
                {{ t(`catalog.formats.${format}`) }}
              </a-checkbox>
              <span class="pps-label">{{ t('sports.form.playersPerSide') }}</span>
              <a-input-number
                v-model:value="form.formats[format].playersPerSide"
                class="pps"
                :min="1"
                :max="2"
                :precision="0"
                :disabled="!form.formats[format].enabled"
                :parser="parseNumber"
                :data-testid="`sport-pps-${format}`"
              />
            </div>
          </div>
        </a-form-item-rest>
      </a-form-item>

      <a-form-item :label="t('sports.form.surfaces')">
        <a-select
          v-model:value="form.surfaces"
          mode="multiple"
          allow-clear
          :options="surfaceOptions"
          :placeholder="t('sports.form.surfacesPlaceholder')"
          data-testid="sport-surfaces"
        />
      </a-form-item>

      <a-divider orientation="right" class="levels-divider">{{ t('sports.form.levels') }}</a-divider>
      <p class="muted">{{ t('sports.form.levelsHelp') }}</p>
      <a-form-item
        v-for="tier in LEVEL_TIERS"
        :key="tier"
        :label="t(`catalog.tiers.${tier}`)"
        required
        :validate-status="errors[`level-${tier}`] ? 'error' : undefined"
        :help="errors[`level-${tier}`] || undefined"
      >
        <a-textarea v-model:value="form.levels[tier]" :rows="2" :maxlength="500" :data-testid="`sport-level-${tier}`" />
      </a-form-item>
    </a-form>

    <template #footer>
      <div class="drawer-footer">
        <a-button data-testid="sport-cancel" @click="close">{{ t('catalog.cancel') }}</a-button>
        <a-button type="primary" :loading="submitting" data-testid="sport-submit" @click="submit">
          {{ sport ? t('sports.form.submitEdit') : t('sports.form.submitCreate') }}
        </a-button>
      </div>
    </template>
  </a-drawer>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { message } from 'ant-design-vue'
import {
  COURT_SURFACES,
  LEVEL_TIERS,
  PLAY_FORMATS,
  SESSION_MINUTES,
  SPORT_CODE_PATTERN,
  type CourtSurface,
  type LevelTier,
  type PlayFormat,
  type Sport,
  type SportRequest,
} from '../../../api/sports.api'
import { useSportsStore } from '../../../stores/sports.store'
import { getApiErrorMessage } from '../../../utils/axios'
import { toAsciiDigits } from '../../../utils/digits'

/** Adds a sport (sport = null) or edits one. The code is fixed once the sport exists. */
const props = defineProps<{ open: boolean; sport: Sport | null }>()
const emit = defineEmits<{ 'update:open': [open: boolean] }>()

const DEFAULT_SESSION_MINUTES = 60

const { t } = useI18n()
const store = useSportsStore()

interface FormState {
  code: string
  nameFa: string
  nameEn: string
  sortOrder: number
  defaultSessionMinutes: number | null
  formats: Record<PlayFormat, { enabled: boolean; playersPerSide: number }>
  levels: Record<LevelTier, string>
  surfaces: CourtSurface[]
}

const emptyLevels = () => Object.fromEntries(LEVEL_TIERS.map((tier) => [tier, ''])) as Record<LevelTier, string>

const form = reactive<FormState>({
  code: '',
  nameFa: '',
  nameEn: '',
  sortOrder: 0,
  defaultSessionMinutes: DEFAULT_SESSION_MINUTES,
  formats: { Singles: { enabled: true, playersPerSide: 1 }, Doubles: { enabled: false, playersPerSide: 2 } },
  levels: emptyLevels(),
  surfaces: [],
})
const errors = reactive<Record<string, string>>({})
const errorMessage = ref('')
const submitting = ref(false)

const surfaceOptions = computed(() => COURT_SURFACES.map((value) => ({ value, label: t(`catalog.surfaces.${value}`) })))

const parseNumber = (value: string) => toAsciiDigits(value).replace(/[^\d]/g, '')

function reset() {
  const sport = props.sport
  const formatOf = (format: PlayFormat) => sport?.formats.find((f) => f.format === format)
  Object.assign(form, {
    code: sport?.code ?? '',
    nameFa: sport?.nameFa ?? '',
    nameEn: sport?.nameEn ?? '',
    sortOrder: sport?.sortOrder ?? Math.max(0, ...store.items.map((s) => s.sortOrder)) + 1,
    defaultSessionMinutes: sport?.defaultSessionMinutes ?? DEFAULT_SESSION_MINUTES,
    formats: {
      Singles: { enabled: sport ? !!formatOf('Singles') : true, playersPerSide: formatOf('Singles')?.playersPerSide ?? 1 },
      Doubles: { enabled: !!formatOf('Doubles'), playersPerSide: formatOf('Doubles')?.playersPerSide ?? 2 },
    },
    levels: { ...emptyLevels(), ...Object.fromEntries((sport?.levels ?? []).map((l) => [l.tier, l.description])) },
    surfaces: [...(sport?.surfaces ?? [])],
  })
  for (const key of Object.keys(errors)) delete errors[key]
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

function validate(): boolean {
  for (const key of Object.keys(errors)) delete errors[key]
  if (!props.sport && !SPORT_CODE_PATTERN.test(form.code.trim())) errors.code = t('sports.form.codeInvalid')
  if (!form.nameFa.trim()) errors.nameFa = t('sports.form.nameRequired')
  if (!form.nameEn.trim()) errors.nameEn = t('sports.form.nameRequired')
  const minutes = form.defaultSessionMinutes
  if (minutes === null || minutes < SESSION_MINUTES.min || minutes > SESSION_MINUTES.max || minutes % SESSION_MINUTES.step !== 0) {
    errors.session = t('sports.form.sessionInvalid')
  }
  if (!PLAY_FORMATS.some((format) => form.formats[format].enabled)) errors.formats = t('sports.form.formatsRequired')
  for (const tier of LEVEL_TIERS) {
    if (!form.levels[tier].trim()) errors[`level-${tier}`] = t('sports.form.levelRequired')
  }
  return Object.keys(errors).length === 0
}

/** The request body: every one of the five tiers, in order, and only the ticked formats. */
function toRequest(): SportRequest {
  return {
    code: props.sport?.code ?? form.code.trim(),
    nameFa: form.nameFa.trim(),
    nameEn: form.nameEn.trim(),
    sortOrder: form.sortOrder ?? 0,
    defaultSessionMinutes: form.defaultSessionMinutes ?? DEFAULT_SESSION_MINUTES,
    formats: PLAY_FORMATS.filter((format) => form.formats[format].enabled).map((format) => ({
      format,
      playersPerSide: form.formats[format].playersPerSide,
    })),
    levels: LEVEL_TIERS.map((tier) => ({ tier, description: form.levels[tier].trim() })),
    surfaces: [...form.surfaces],
  }
}

function close() {
  if (!submitting.value) emit('update:open', false)
}

async function submit() {
  if (submitting.value) return
  errorMessage.value = ''
  if (!validate()) return

  submitting.value = true
  try {
    if (props.sport) {
      await store.update(props.sport.id, toRequest())
      void message.success(t('sports.messages.updated'))
    } else {
      await store.create(toRequest())
      void message.success(t('sports.messages.created'))
    }
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

.two-columns {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0 16px;
}

.full-width {
  width: 100%;
}

.formats {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.format-row {
  display: flex;
  align-items: center;
  gap: 12px;
}

.format-row :deep(.ant-checkbox-wrapper) {
  min-width: 90px;
}

.pps-label {
  color: var(--ty-text-secondary);
}

.pps {
  width: 72px;
}

.levels-divider {
  margin-top: 8px;
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
