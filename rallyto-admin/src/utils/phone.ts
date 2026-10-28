import { toAsciiDigits } from './digits'

// Direction marks, zero-width characters, spaces, dashes, dots and parentheses that people type or paste around
// a number. None of them is part of it.
const DECORATION = /[\s​-‏‪-‮⁦-⁩().\-]/g

/**
 * A phone number as typed, ready to send: ASCII digits, no spaces or separators, a leading `+` kept. The API
 * normalises the accepted forms to E.164 itself (identity-access › Iranian mobile number normalisation), so the
 * client does not rewrite the prefix.
 */
export function normalizePhoneInput(value: string | null | undefined): string {
  return toAsciiDigits(value).replace(DECORATION, '')
}

// Left-to-right isolate ... pop: keeps a number's digits and its "+" in reading order inside right-to-left text.
const LRI = '⁦'
const PDI = '⁩'

/** A phone number for display: the local form (`0912 345 6789`) for an Iranian mobile, direction-isolated. */
export function formatPhone(value: string | null | undefined): string {
  if (!value) return ''
  const normalized = normalizePhoneInput(value)
  const match = /^(?:0|98|\+98|0098)?(9\d{9})$/.exec(normalized)
  const shown = match ? `0${match[1]!.slice(0, 3)} ${match[1]!.slice(3, 6)} ${match[1]!.slice(6)}` : value.trim()
  return `${LRI}${shown}${PDI}`
}
