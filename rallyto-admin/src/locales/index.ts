import { createI18n } from 'vue-i18n'
import fa from './fa.json'
import en from './en.json'

export type MessageSchema = typeof fa

/** The panel's i18n: composition (non-legacy) mode, Persian by default, English as the fallback. */
export function createAppI18n() {
  return createI18n<[MessageSchema], 'fa' | 'en'>({
    legacy: false,
    locale: 'fa',
    fallbackLocale: 'en',
    messages: { fa, en },
    globalInjection: true,
  })
}
