<template>
  <div class="page-container" data-testid="placeholder-page">
    <a-page-header :title="title" class="page-header" />
    <a-card>
      <a-empty :description="t('placeholder.comingSoon')" />
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'

/** A section whose real screen arrives in a later task: its title and a short note, nothing else. */
defineProps<{ title: string }>()

const { t } = useI18n()
</script>
