<template>
  <a-form-item-rest>
    <div class="sports-editor" :class="{ invalid }" data-testid="venue-sports-editor">
      <p v-if="rows.length === 0" class="muted">{{ t('catalog.sportsEditor.empty') }}</p>

      <div
        v-for="row in rows"
        :key="row.code"
        class="sport-row"
        :class="{ selected: !!row.entry }"
        :data-testid="`sport-row-${row.code}`"
      >
        <a-checkbox
          :checked="!!row.entry"
          :disabled="disabled"
          :data-testid="`sport-toggle-${row.code}`"
          @change="(event: CheckboxChangeEvent) => toggle(row.code, event.target.checked)"
        >
          <span class="sport-name">{{ row.name }}</span>
          <a-tag v-if="row.inactive" class="inactive-tag">{{ t('catalog.sportsEditor.inactive') }}</a-tag>
        </a-checkbox>

        <div v-if="row.entry" class="sport-details">
          <div class="field">
            <span class="field-label">{{ t('catalog.sportsEditor.courtCount') }}</span>
            <a-input-number
              :value="row.entry.courtCount ?? undefined"
              class="field-courts"
              :min="COURT_COUNT.min"
              :max="COURT_COUNT.max"
              :precision="0"
              :parser="parseNumber"
              :disabled="disabled"
              :placeholder="t('catalog.sportsEditor.unknown')"
              :data-testid="`sport-courts-${row.code}`"
              @change="(value: unknown) => patch(row.code, { courtCount: toCount(value) })"
            />
          </div>

          <div class="field">
            <span class="field-label">{{ t('catalog.sportsEditor.setting') }}</span>
            <a-select
              :value="row.entry.setting"
              class="field-setting"
              :options="settingOptions"
              :disabled="disabled"
              :data-testid="`sport-setting-${row.code}`"
              @change="(value: unknown) => patch(row.code, { setting: value as CourtSetting })"
            />
          </div>

          <div class="field">
            <span class="field-label">{{ t('catalog.sportsEditor.surface') }}</span>
            <a-select
              :value="row.entry.surface ?? undefined"
              class="field-surface"
              allow-clear
              :options="row.surfaceOptions"
              :disabled="disabled || row.surfaceOptions.length === 0"
              :placeholder="t('catalog.sportsEditor.unknown')"
              :data-testid="`sport-surface-${row.code}`"
              @change="(value: unknown) => patch(row.code, { surface: (value as CourtSurface | undefined) ?? null })"
            />
          </div>

          <a-checkbox
            :checked="row.entry.hasLighting"
            class="field-lighting"
            :disabled="disabled"
            :data-testid="`sport-lighting-${row.code}`"
            @change="(event: CheckboxChangeEvent) => patch(row.code, { hasLighting: event.target.checked })"
          >
            {{ t('catalog.sportsEditor.lighting') }}
          </a-checkbox>
        </div>
      </div>
    </div>
  </a-form-item-rest>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import type { CheckboxChangeEvent } from 'ant-design-vue/es/checkbox/interface'
import type { CourtSurface, Sport } from '../../api/sports.api'
import { COURT_COUNT, COURT_SETTINGS, DEFAULT_COURT_SETTING, type CourtSetting, type VenueSport } from '../../api/venues.api'
import { toAsciiDigits } from '../../utils/digits'

/**
 * The sports a club offers: one row per sport, ticked to include it. A ticked row asks for the court details, all of
 * which may stay unknown for now (court count and surface are nullable, the setting defaults to outdoor). The surface
 * list is that sport's own surfaces.
 *
 * Shows every active sport, plus any inactive one the club already has. Emits the whole list on every change, in
 * the sports' catalog order, in exactly the shape the API takes.
 */
const props = withDefaults(
  defineProps<{
    modelValue: VenueSport[]
    /** The catalog, in display order (the sports store's list). */
    sports: Sport[]
    disabled?: boolean
    invalid?: boolean
  }>(),
  { disabled: false, invalid: false },
)
const emit = defineEmits<{ 'update:modelValue': [value: VenueSport[]] }>()


const { t } = useI18n()

const settingOptions = computed(() => COURT_SETTINGS.map((value) => ({ value, label: t(`catalog.settings.${value}`) })))

interface Row {
  code: string
  name: string
  inactive: boolean
  entry: VenueSport | undefined
  surfaceOptions: { value: CourtSurface; label: string }[]
}

const rows = computed<Row[]>(() => {
  const selected = new Map(props.modelValue.map((entry) => [entry.sportCode, entry]))
  const known = new Set(props.sports.map((sport) => sport.code))
  const fromCatalog = props.sports
    .filter((sport) => sport.isActive || selected.has(sport.code))
    .map((sport) => ({
      code: sport.code,
      name: sport.nameFa,
      inactive: !sport.isActive,
      entry: selected.get(sport.code),
      surfaceOptions: sport.surfaces.map((value) => ({ value, label: t(`catalog.surfaces.${value}`) })),
    }))
  // A code the catalog no longer lists still shows, so saving never drops it silently.
  const unknown = props.modelValue
    .filter((entry) => !known.has(entry.sportCode))
    .map((entry) => ({ code: entry.sportCode, name: entry.sportCode, inactive: true, entry, surfaceOptions: [] }))
  return [...fromCatalog, ...unknown]
})

/** The entries in row order, so the payload does not depend on the order things were ticked. */
function ordered(entries: Map<string, VenueSport>): VenueSport[] {
  return rows.value.map((row) => entries.get(row.code)).filter((entry): entry is VenueSport => !!entry)
}

function current(): Map<string, VenueSport> {
  return new Map(props.modelValue.map((entry) => [entry.sportCode, { ...entry }]))
}

function toggle(code: string, checked: boolean) {
  const entries = current()
  if (checked) {
    entries.set(code, entries.get(code) ?? { sportCode: code, courtCount: null, setting: DEFAULT_COURT_SETTING, surface: null, hasLighting: false })
  } else {
    entries.delete(code)
  }
  emit('update:modelValue', ordered(entries))
}

function patch(code: string, change: Partial<Omit<VenueSport, 'sportCode'>>) {
  const entries = current()
  const entry = entries.get(code)
  if (!entry) return
  entries.set(code, { ...entry, ...change })
  emit('update:modelValue', ordered(entries))
}

/** Persian digits typed into a number input are read as ASCII. */
const parseNumber = (value: string) => toAsciiDigits(value).replace(/[^\d]/g, '')

function toCount(value: unknown): number | null {
  if (value === null || value === undefined || value === '') return null
  const count = Number(value)
  return Number.isFinite(count) ? Math.trunc(count) : null
}
</script>

<style scoped>
.sports-editor {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.sports-editor.invalid .sport-row {
  border-color: #ff4d4f;
}

.sport-row {
  border: 1px solid var(--ty-border, #f0f0f0);
  border-radius: 8px;
  padding: 8px 12px;
}

.sport-row.selected {
  background: var(--ty-bg-subtle, #fafafa);
}

.sport-name {
  font-weight: 500;
}

.inactive-tag {
  margin-inline-start: 8px;
}

.sport-details {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  gap: 12px;
  margin-top: 8px;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.field-label {
  font-size: 12px;
  color: var(--ty-text-secondary);
}

.field-courts {
  width: 100px;
}

.field-setting {
  width: 150px;
}

.field-surface {
  width: 140px;
}

.field-lighting {
  padding-bottom: 5px;
}

.muted {
  color: var(--ty-text-secondary);
}
</style>
