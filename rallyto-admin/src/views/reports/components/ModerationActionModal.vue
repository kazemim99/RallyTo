<template>
  <a-modal :open="open" :title="title" :mask-closable="false" :width="560" @cancel="close">
    <a-alert v-if="errorMessage" class="modal-alert" type="error" show-icon :message="errorMessage" data-testid="moderation-error" />

    <a-form layout="vertical">
      <a-form-item :label="t('reportTarget.actionsTitle')">
        <a-select v-model:value="action" :options="actionOptions" data-testid="moderation-action" />
      </a-form-item>

      <!-- A ban is final: say so plainly, and ask for two explicit confirmations before the button arms. -->
      <a-alert
        v-if="action === 'Ban'"
        class="modal-alert"
        type="error"
        show-icon
        :message="t('moderation.ban.warningTitle')"
        :description="t('moderation.ban.warning')"
        data-testid="moderation-ban-warning"
      />
      <p v-else-if="description" class="description" data-testid="moderation-description">{{ description }}</p>

      <a-form-item :label="t('moderation.fields.report')">
        <a-select v-model:value="form.reportId" :options="reportOptions" data-testid="moderation-report" />
      </a-form-item>

      <a-form-item
        v-if="action === 'Warn'"
        :label="t('moderation.fields.warningText')"
        required
        v-bind="status('warningText')"
      >
        <a-textarea
          v-model:value="form.warningText"
          :rows="3"
          :maxlength="500"
          :placeholder="t('moderation.fields.warningPlaceholder')"
          data-testid="moderation-warning-text"
        />
      </a-form-item>

      <a-form-item v-if="action === 'HidePost'" :label="t('moderation.fields.matchId')" required v-bind="status('matchId')">
        <a-input v-model:value="form.matchId" dir="ltr" data-testid="moderation-match-id" />
        <div v-if="postIds.length" class="suggestions">
          <span class="muted">{{ t('moderation.fields.fromReports') }}</span>
          <a-tag
            v-for="id in postIds"
            :key="id"
            class="suggestion"
            :color="form.matchId === id ? 'blue' : 'default'"
            :title="id"
            :data-testid="`moderation-match-suggestion-${id}`"
            @click="form.matchId = id"
          >
            <span dir="ltr">{{ shortId(id) }}</span>
          </a-tag>
        </div>
      </a-form-item>

      <a-form-item
        v-if="action === 'DeleteMessage'"
        :label="t('moderation.fields.messageId')"
        required
        v-bind="status('messageId')"
      >
        <a-input v-model:value="form.messageId" dir="ltr" data-testid="moderation-message-id" />
        <div v-if="messageIds.length" class="suggestions">
          <span class="muted">{{ t('moderation.fields.fromReports') }}</span>
          <a-tag
            v-for="id in messageIds"
            :key="id"
            class="suggestion"
            :color="form.messageId === id ? 'blue' : 'default'"
            :title="id"
            :data-testid="`moderation-message-suggestion-${id}`"
            @click="form.messageId = id"
          >
            <span dir="ltr">{{ shortId(id) }}</span>
          </a-tag>
        </div>
      </a-form-item>

      <template v-if="action === 'Suspend'">
        <a-form-item :label="t('moderation.fields.until')" required v-bind="status('until')">
          <a-radio-group :value="preset" button-style="solid" class="presets" data-testid="moderation-presets" @change="applyPreset">
            <a-radio-button v-for="days in PRESETS" :key="days" :value="days" :data-testid="`moderation-preset-${days}`">
              {{ t('moderation.fields.preset', { count: toPersianDigits(days) }) }}
            </a-radio-button>
          </a-radio-group>
          <JalaliDateInput v-model="form.until" test-id="moderation-until" :years="untilYears" />
        </a-form-item>
        <p v-if="form.until" class="muted" data-testid="moderation-until-preview">
          {{ t('moderation.untilPreview', { date: toPersianDigits(form.until) }) }}
        </p>
      </template>

      <a-form-item v-if="action === 'CorrectGender'" :label="t('moderation.fields.gender')" required v-bind="status('gender')">
        <a-radio-group v-model:value="form.gender" button-style="solid" data-testid="moderation-gender">
          <a-radio-button v-for="option in GENDERS" :key="option" :value="option" :data-testid="`moderation-gender-${option}`">
            {{ t(`users.player.gender.${option}`) }}
          </a-radio-button>
        </a-radio-group>
      </a-form-item>

      <a-form-item :label="t('safety.reason.label')" required v-bind="status('reason')">
        <a-textarea
          v-model:value="form.reason"
          :rows="3"
          :maxlength="500"
          :placeholder="t('safety.reason.placeholder')"
          data-testid="moderation-reason"
        />
      </a-form-item>

      <template v-if="action === 'Ban'">
        <a-form-item :validate-status="errors.confirm ? 'error' : undefined" :help="errors.confirm ? t(errors.confirm) : undefined">
          <a-checkbox v-model:checked="form.acknowledged" data-testid="moderation-ban-acknowledge">
            {{ t('moderation.ban.acknowledge') }}
          </a-checkbox>
        </a-form-item>
        <a-form-item :label="t('moderation.ban.confirmName', { name: target?.displayName ?? '' })">
          <a-input v-model:value="form.confirmName" data-testid="moderation-ban-name" />
        </a-form-item>
      </template>
    </a-form>

    <template #footer>
      <a-button data-testid="moderation-cancel" @click="close">{{ t('safety.cancel') }}</a-button>
      <a-button
        type="primary"
        :danger="DANGEROUS_ACTIONS.has(action)"
        :disabled="action === 'Ban' && !banArmed"
        :loading="submitting"
        data-testid="moderation-submit"
        @click="submit"
      >
        {{ action === 'Ban' ? t('moderation.actions.Ban') : t('moderation.submit') }}
      </a-button>
    </template>
  </a-modal>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { message } from 'ant-design-vue'
import { GENDERS } from '../../../api/players.api'
import type { AdminReport, ModerationActionRequest, ModerationActionType } from '../../../api/safety.api'
import JalaliDateInput from '../../../components/common/JalaliDateInput.vue'
import { getApiErrorMessage } from '../../../utils/axios'
import { formatDate, formatJalaliDay, tehranJalaliDay } from '../../../utils/date'
import { toPersianDigits } from '../../../utils/digits'
import {
  DANGEROUS_ACTIONS,
  buildModerationRequest,
  emptyModerationForm,
  reportedMessageIds,
  reportedPostIds,
  sameName,
  shortId,
  type ModerationErrors,
  type ModerationField,
  type ModerationForm,
} from '../moderation'

/**
 * One dialog for every admin action on a reported player. Each needs a reason and can be linked to one of the
 * player's reports (resolving it if open); the fields the chosen action needs appear with it. The rules live in
 * `buildModerationRequest`; a refusal stays in the dialog with the server's Persian message.
 */
const props = defineProps<{
  open: boolean
  /** The action the dialog opens on; the admin can switch to any of `actions`. */
  initialAction: ModerationActionType | null
  actions: ModerationActionType[]
  target: { userId: string; displayName: string } | null
  reports: AdminReport[]
  /** Pre-filled members, such as the report and the match id when acting on a reported post. */
  initial?: Partial<ModerationForm>
  submit: (request: ModerationActionRequest) => Promise<unknown>
}>()
const emit = defineEmits<{ 'update:open': [open: boolean] }>()

const PRESETS = [1, 3, 7, 30] as const
const DEFAULT_PRESET = 7

const { t, te } = useI18n()

const action = ref<ModerationActionType>('Warn')
const form = reactive<ModerationForm>(emptyModerationForm())
const errors = ref<ModerationErrors>({})
const errorMessage = ref('')
const submitting = ref(false)

const label = (group: string, value: string) => (te(`safety.${group}.${value}`) ? t(`safety.${group}.${value}`) : value)

const title = computed(() =>
  t('moderation.title', { action: t(`moderation.actions.${action.value}`), name: props.target?.displayName ?? '' }),
)
const description = computed(() =>
  te(`moderation.descriptions.${action.value}`) ? t(`moderation.descriptions.${action.value}`) : '',
)
const actionOptions = computed(() =>
  props.actions.map((value) => ({ value, label: t(`moderation.actions.${value}`) })),
)
const reportOptions = computed(() => [
  { value: '', label: t('moderation.fields.reportNone') },
  ...props.reports.map((report) => ({
    value: report.id,
    label: [
      label('reasons', report.reason),
      label('targetTypes', report.targetType),
      report.reporterName,
      formatDate(report.createdAt),
      label('reportStatus', report.status),
    ].join(' · '),
  })),
])
const postIds = computed(() => reportedPostIds(props.reports))
const messageIds = computed(() => reportedMessageIds(props.reports))
const untilYears = computed(() => {
  const year = tehranJalaliDay().year
  return [year, year + 1]
})

const banArmed = computed(() => form.acknowledged && sameName(form.confirmName, props.target?.displayName ?? ''))

/** The preset whose day is chosen, if any. */
const preset = computed(() => PRESETS.find((days) => formatJalaliDay(tehranJalaliDay(days)) === form.until))

function applyPreset(event: { target: { value?: unknown } }) {
  const days = Number(event.target.value)
  if (days) form.until = formatJalaliDay(tehranJalaliDay(days))
}

function status(field: ModerationField) {
  const key = errors.value[field]
  return { validateStatus: key ? ('error' as const) : undefined, help: key ? t(key) : undefined }
}

watch(
  () => props.open,
  (open) => {
    if (!open) return
    Object.assign(form, emptyModerationForm(), props.initial ?? {})
    action.value = props.initialAction ?? props.actions[0] ?? 'Warn'
    if (!form.until) form.until = formatJalaliDay(tehranJalaliDay(DEFAULT_PRESET))
    errors.value = {}
    errorMessage.value = ''
    submitting.value = false
  },
  { immediate: true },
)

// Switching the action drops the previous one's problems.
watch(action, () => {
  errors.value = {}
  errorMessage.value = ''
})

function close() {
  if (!submitting.value) emit('update:open', false)
}

async function submit() {
  if (!props.target || submitting.value) return
  errorMessage.value = ''
  const result = buildModerationRequest(action.value, props.target, form, tehranJalaliDay())
  errors.value = result.errors ?? {}
  if (!result.request) return

  submitting.value = true
  try {
    await props.submit(result.request)
    void message.success(t('moderation.success'))
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

.description {
  color: var(--ty-text-secondary);
}

.suggestions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 4px;
  margin-top: 8px;
}

.suggestion {
  cursor: pointer;
}

.presets {
  display: block;
  margin-bottom: 8px;
}

.muted {
  color: var(--ty-text-secondary);
}
</style>
