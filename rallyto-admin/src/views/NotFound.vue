<template>
  <a-result status="404" title="۴۰۴" :sub-title="t('notFound.subtitle')">
    <template #extra>
      <a-button type="primary" @click="router.push('/dashboard')">
        {{ t('notFound.backHome') }}
      </a-button>
    </template>
  </a-result>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'

const router = useRouter()
const { t } = useI18n()
</script>
