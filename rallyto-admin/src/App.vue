<template>
  <a-config-provider :direction="direction" :locale="antdLocale" :theme="antdTheme">
    <router-view />
  </a-config-provider>
</template>

<script setup lang="ts">
import { computed, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import faIR from 'ant-design-vue/es/locale/fa_IR'
import enUS from 'ant-design-vue/es/locale/en_US'
import { useLocaleStore } from './stores/locale.store'
import { useRTL } from './composables/useRTL'
import { antdTheme } from './config/antd-theme'
import { Language } from './types/locale.types'

const localeStore = useLocaleStore()
const { direction } = useRTL()
const { locale } = useI18n()

const antdLocale = computed(() => (localeStore.currentLocale === Language.Persian ? faIR : enUS))

watch(
  () => localeStore.currentLocale,
  (current) => {
    locale.value = current
    localeStore.applyToDocument()
  },
  { immediate: true },
)
</script>
