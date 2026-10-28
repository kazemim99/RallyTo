import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { Direction, Language, LOCALE_CONFIG } from '../types/locale.types'

/**
 * The panel's language and direction. Persian (right-to-left, Jalali) is the only language staff use today; English
 * exists as the i18n fallback, and switching is a later task, so nothing is persisted yet.
 */
export const useLocaleStore = defineStore('locale', () => {
  const currentLocale = ref<Language>(Language.Persian)

  const direction = computed<Direction>(() => LOCALE_CONFIG[currentLocale.value].direction)
  const isRTL = computed(() => direction.value === Direction.RTL)

  function applyToDocument() {
    if (typeof document === 'undefined') return
    document.documentElement.dir = direction.value
    document.documentElement.lang = currentLocale.value
  }

  function setLocale(locale: Language) {
    currentLocale.value = locale
    applyToDocument()
  }

  return { currentLocale, direction, isRTL, setLocale, applyToDocument }
})
