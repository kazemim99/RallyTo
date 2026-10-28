export const Language = {
  Persian: 'fa',
  English: 'en',
} as const

export type Language = (typeof Language)[keyof typeof Language]

export const Direction = {
  RTL: 'rtl',
  LTR: 'ltr',
} as const

export type Direction = (typeof Direction)[keyof typeof Direction]

export interface LocaleConfig {
  name: string
  direction: Direction
}

export const LOCALE_CONFIG: Record<Language, LocaleConfig> = {
  [Language.Persian]: { name: 'فارسی', direction: Direction.RTL },
  [Language.English]: { name: 'English', direction: Direction.LTR },
}
