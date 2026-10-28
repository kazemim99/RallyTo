<template>
  <section class="ratings-section" data-testid="ratings-section">
    <a-spin :spinning="store.loading">
      <a-alert v-if="store.error" type="error" show-icon :message="store.error" data-testid="ratings-error" />

      <a-empty v-else-if="!store.loading && ratings.length === 0" :description="t('ratings.empty')" data-testid="ratings-empty" />

      <template v-else>
        <p class="muted" data-testid="ratings-summary">
          {{ t('ratings.summary', { total: toPersianDigits(ratings.length), removed: toPersianDigits(removedCount) }) }}
        </p>

        <a-card
          v-for="rating in ratings"
          :key="rating.id"
          size="small"
          class="rating-card"
          :class="{ removed: rating.removedAt }"
          :data-testid="`rating-${rating.id}`"
        >
          <template #title>
            <a-space :size="4" wrap>
              <a-rate :value="rating.stars" disabled :count="5" class="stars" />
              <span class="stars-text" data-testid="rating-stars">{{ t('ratings.stars', { count: toPersianDigits(rating.stars) }) }}</span>
            </a-space>
          </template>
          <template #extra>
            <a-space :size="4">
              <a-tag v-if="rating.removedAt" color="red" data-testid="rating-removed">{{ t('ratings.removed') }}</a-tag>
              <a-tag v-if="rating.revealed" color="green" data-testid="rating-revealed">{{ t('ratings.revealed') }}</a-tag>
              <a-tag v-else data-testid="rating-revealed">{{ t('ratings.hidden') }}</a-tag>
            </a-space>
          </template>

          <dl class="facts">
            <dt>{{ t('ratings.fields.rater') }}</dt>
            <dd data-testid="rating-rater">{{ rating.raterName }}</dd>
            <dt>{{ t('ratings.fields.tags') }}</dt>
            <dd data-testid="rating-tags">
              <template v-if="rating.tags.length">
                <a-tag v-for="tag in rating.tags" :key="tag">{{ label('tags', tag) }}</a-tag>
              </template>
              <span v-else class="muted">{{ t('ratings.noTags') }}</span>
            </dd>
            <dt>{{ t('ratings.fields.levelAccuracy') }}</dt>
            <dd data-testid="rating-level">{{ label('levels', rating.levelAccuracy) }}</dd>
            <dt>{{ t('ratings.fields.privateNote') }}</dt>
            <dd class="multiline" data-testid="rating-note">
              <span v-if="rating.privateNote">{{ rating.privateNote }}</span>
              <span v-else class="muted">{{ t('ratings.noNote') }}</span>
            </dd>
            <dt>{{ t('ratings.fields.match') }}</dt>
            <dd><span dir="ltr" class="mono" :title="rating.matchId">{{ rating.matchId }}</span></dd>
            <dt>{{ t('ratings.fields.submittedAt') }}</dt>
            <dd>{{ formatDateTime(rating.submittedAt) }}</dd>
            <template v-if="rating.removedAt">
              <dt>{{ t('ratings.fields.removedAt') }}</dt>
              <dd>{{ formatDateTime(rating.removedAt) }}</dd>
              <dt>{{ t('ratings.fields.removalReason') }}</dt>
              <dd data-testid="rating-removal-reason">{{ rating.removalReason || t('safety.noValue') }}</dd>
            </template>
          </dl>

          <div v-if="!rating.removedAt" class="actions">
            <a-button size="small" danger :data-testid="`rating-remove-${rating.id}`" @click="openRemove(rating)">
              {{ t('ratings.remove') }}
            </a-button>
          </div>
        </a-card>
      </template>
    </a-spin>

    <RemoveRatingModal v-model:open="removeOpen" :rating="removing" :remove="store.remove" />
  </section>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import type { AdminRating } from '../../../api/ratings.api'
import { usePlayerRatingsStore } from '../../../stores/playerRatings.store'
import { formatDateTime } from '../../../utils/date'
import { toPersianDigits } from '../../../utils/digits'
import RemoveRatingModal from './RemoveRatingModal.vue'

/**
 * Every rating the player received (player-ratings › Admin oversight of ratings): rater, stars, tags, level
 * accuracy, the private note, whether it is revealed yet, and its removal. Removing one asks for a reason; the
 * public aggregates are computed on read, so it stops counting at once.
 */
const props = defineProps<{ userId: string }>()

const { t, te } = useI18n()
const store = usePlayerRatingsStore()

const removeOpen = ref(false)
const removing = ref<AdminRating | null>(null)

const ratings = computed(() => (store.userId === props.userId ? store.items : []))
const removedCount = computed(() => ratings.value.filter((rating) => rating.removedAt).length)

const label = (group: string, value: string) => (te(`ratings.${group}.${value}`) ? t(`ratings.${group}.${value}`) : value)

function openRemove(rating: AdminRating) {
  removing.value = rating
  removeOpen.value = true
}

watch(
  () => props.userId,
  (userId) => {
    removeOpen.value = false
    void store.load(userId)
  },
  { immediate: true },
)

onBeforeUnmount(() => store.reset())
</script>

<style scoped>
.rating-card {
  margin-bottom: 8px;
}

.rating-card.removed {
  opacity: 0.7;
}

.stars {
  font-size: 14px;
}

.stars-text {
  font-size: 12px;
  color: var(--ty-text-secondary);
}

.facts {
  display: grid;
  grid-template-columns: max-content 1fr;
  gap: 4px 12px;
  margin: 0;
}

.facts dt {
  color: var(--ty-text-secondary);
}

.facts dd {
  margin: 0;
}

.multiline {
  white-space: pre-line;
}

.actions {
  margin-top: 8px;
}

.mono {
  font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
  font-size: 12px;
  word-break: break-all;
}

.muted {
  color: var(--ty-text-secondary);
}
</style>
