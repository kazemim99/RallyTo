<template>
  <section class="player-section" data-testid="player-section">
    <a-divider orientation="right">{{ t('users.player.title') }}</a-divider>

    <a-spin :spinning="store.loading">
      <a-alert v-if="store.error" type="error" show-icon :message="store.error" data-testid="player-error" />

      <a-empty v-else-if="store.notFound" :description="t('users.player.noProfile')" data-testid="player-no-profile" />

      <template v-else-if="profile">
        <div class="identity">
          <a-avatar :size="72" :src="photoSrc ?? undefined" :alt="t('users.player.photoAlt', { name: profile.displayName })" data-testid="player-photo">
            <template #icon><UserOutlined /></template>
          </a-avatar>
          <div class="identity-text">
            <div class="name" data-testid="player-name">{{ profile.displayName }}</div>
            <a-tag :color="STATUS_COLORS[profile.status] ?? 'default'" data-testid="player-status">
              {{ label('status', profile.status) }}
            </a-tag>
            <span v-if="!photoSrc" class="muted">{{ t('users.player.noPhoto') }}</span>
          </div>
        </div>

        <a-space v-if="profile.status !== 'Deleted'" class="actions" wrap>
          <a-button size="small" data-testid="action-correctGender" @click="genderOpen = true">
            {{ t('users.player.actions.correctGender') }}
          </a-button>
          <a-button v-if="profile.photoUrl" size="small" danger data-testid="action-removePhoto" @click="photoOpen = true">
            {{ t('users.player.actions.removePhoto') }}
          </a-button>
        </a-space>

        <a-descriptions :column="1" bordered size="small" data-testid="player-details">
          <a-descriptions-item :label="t('users.player.fields.gender')">
            <span data-testid="player-gender">{{ label('gender', profile.gender) }}</span>
          </a-descriptions-item>
          <a-descriptions-item :label="t('users.player.fields.birthDate')">
            <span dir="ltr" data-testid="player-birth-date">{{ birthDate || t('users.noValue') }}</span>
          </a-descriptions-item>
          <a-descriptions-item :label="t('users.player.fields.ageRange')">
            <span data-testid="player-age-range">{{ ageRange }}</span>
          </a-descriptions-item>
          <a-descriptions-item :label="t('users.player.fields.city')">
            <span data-testid="player-city">{{ profile.city?.name || t('users.noValue') }}</span>
          </a-descriptions-item>
          <a-descriptions-item :label="t('users.player.fields.bio')">
            <span class="bio" data-testid="player-bio">{{ profile.bio || t('users.noValue') }}</span>
          </a-descriptions-item>
          <a-descriptions-item :label="t('users.player.fields.visibility')">
            <span data-testid="player-visibility">{{ label('visibility', profile.visibility) }}</span>
          </a-descriptions-item>
          <a-descriptions-item :label="t('users.player.fields.homeVenues')">
            <span v-if="profile.homeVenues.length === 0" class="muted">{{ t('users.player.noVenues') }}</span>
            <a-tag v-for="venue in profile.homeVenues" v-else :key="venue.id" data-testid="player-venue">{{ venue.name }}</a-tag>
          </a-descriptions-item>
        </a-descriptions>

        <h4 class="sports-title">{{ t('users.player.fields.sports') }}</h4>
        <p v-if="profile.sports.length === 0" class="muted" data-testid="player-no-sports">{{ t('users.player.noSports') }}</p>
        <a-card
          v-for="sport in profile.sports"
          :key="sport.sportId"
          size="small"
          class="sport-card"
          :title="sportName(sport.sportCode)"
          :data-testid="`player-sport-${sport.sportCode}`"
        >
          <dl class="sport-facts">
            <dt>{{ t('users.player.level') }}</dt>
            <dd>
              <span data-testid="sport-level">{{ sport.levelName }}</span>
              <div v-if="sport.levelDescription" class="muted level-description">{{ sport.levelDescription }}</div>
            </dd>
            <dt>{{ t('users.player.experience') }}</dt>
            <dd data-testid="sport-experience">{{ label('experienceBands', sport.experience) }}</dd>
            <template v-if="sport.formats.length">
              <dt>{{ t('users.player.formats') }}</dt>
              <dd>{{ sport.formats.map(formatLabel).join('، ') }}</dd>
            </template>
            <template v-if="sport.goals.length">
              <dt>{{ t('users.player.goals') }}</dt>
              <dd>{{ sport.goals.map((goal) => label('goalNames', goal)).join('، ') }}</dd>
            </template>
          </dl>
        </a-card>
      </template>
    </a-spin>

    <GenderCorrectionModal v-model:open="genderOpen" :profile="profile" />
    <RemovePhotoModal v-model:open="photoOpen" :profile="profile" />
  </section>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { UserOutlined } from '@ant-design/icons-vue'
import { playerPhotoSrc, type ProfileStatus } from '../../../api/players.api'
import { usePlayersStore } from '../../../stores/players.store'
import { useSportsStore } from '../../../stores/sports.store'
import { toPersianDigits } from '../../../utils/digits'
import GenderCorrectionModal from './GenderCorrectionModal.vue'
import RemovePhotoModal from './RemovePhotoModal.vue'

/**
 * The player profile of one account (`GET /admin/players/{id}`), read fresh whenever the user changes, with the
 * admin corrections. An account that never finished onboarding has no profile: that is a state, not an error.
 */
const props = defineProps<{ userId: string }>()

const STATUS_COLORS: Record<ProfileStatus, string> = { Active: 'green', Hidden: 'orange', Deleted: 'default' }

const { t, te } = useI18n()
const store = usePlayersStore()
const sportsStore = useSportsStore()

const genderOpen = ref(false)
const photoOpen = ref(false)

const profile = computed(() => (store.userId === props.userId ? store.profile : null))
const photoSrc = computed(() => playerPhotoSrc(profile.value?.photoUrl))
const birthDate = computed(() => toPersianDigits(profile.value?.birthDate))
/** `25-34` reads «۲۵ تا ۳۴ سال», `55+` «۵۵ سال به بالا»; anything else is shown as sent, in Persian digits. */
const ageRange = computed(() => {
  const range = profile.value?.ageRange?.trim()
  if (!range) return t('users.noValue')
  const between = /^(\d+)\s*-\s*(\d+)$/.exec(range)
  if (between) return t('users.player.ageRangeBetween', { from: toPersianDigits(between[1]), to: toPersianDigits(between[2]) })
  const from = /^(\d+)\s*\+$/.exec(range)
  if (from) return t('users.player.ageRangeFrom', { from: toPersianDigits(from[1]) })
  return toPersianDigits(range)
})

/** A Persian label for an enum member; an unknown member is shown as the server sent it. */
const label = (group: string, value: string) =>
  te(`users.player.${group}.${value}`) ? t(`users.player.${group}.${value}`) : value
const formatLabel = (format: string) => (te(`catalog.formats.${format}`) ? t(`catalog.formats.${format}`) : format)
const sportName = (code: string) => sportsStore.byCode.get(code)?.nameFa ?? code

watch(
  () => props.userId,
  (userId) => {
    genderOpen.value = false
    photoOpen.value = false
    void store.load(userId)
  },
  { immediate: true },
)

// The sport names come from the catalog; until it arrives (or if it cannot be read) the code stands in.
void sportsStore.ensureLoaded()

onBeforeUnmount(() => store.reset())
</script>

<style scoped>
.player-section {
  margin-top: 8px;
}

.identity {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 12px;
}

.identity-text {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 4px;
}

.name {
  font-size: 16px;
  font-weight: 600;
}

.actions {
  margin-bottom: 12px;
}

.bio {
  white-space: pre-line;
}

.sports-title {
  margin: 16px 0 8px;
}

.sport-card {
  margin-bottom: 8px;
}

.sport-facts {
  display: grid;
  grid-template-columns: max-content 1fr;
  gap: 4px 12px;
  margin: 0;
}

.sport-facts dt {
  color: var(--ty-text-secondary);
}

.sport-facts dd {
  margin: 0;
}

.level-description {
  font-size: 12px;
}

.muted {
  color: var(--ty-text-secondary);
}
</style>
