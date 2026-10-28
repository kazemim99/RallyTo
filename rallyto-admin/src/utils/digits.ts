/**
 * Digit normalisation. Iranian keyboards type Persian digits (۰–۹, U+06F0–U+06F9) and some phones and pasted text
 * carry Arabic-Indic digits (٠–٩, U+0660–U+0669). The API only understands ASCII digits, so every value a person
 * types (a phone number, a sign-in code) goes through {@link toAsciiDigits} before it is sent.
 */

const PERSIAN_ZERO = 0x06f0
const ARABIC_INDIC_ZERO = 0x0660
const PERSIAN_DIGITS = '۰۱۲۳۴۵۶۷۸۹'

const NON_ASCII_DIGIT = /[۰-۹٠-٩]/g

/** Persian and Arabic-Indic digits become ASCII `0`–`9`; every other character is kept as it is. */
export function toAsciiDigits(value: string | null | undefined): string {
  if (!value) return ''
  return value.replace(NON_ASCII_DIGIT, (digit) => {
    const code = digit.charCodeAt(0)
    const zero = code >= PERSIAN_ZERO ? PERSIAN_ZERO : ARABIC_INDIC_ZERO
    return String(code - zero)
  })
}

/** ASCII (and Arabic-Indic) digits become Persian digits, for display. */
export function toPersianDigits(value: string | number | null | undefined): string {
  if (value === null || value === undefined) return ''
  return toAsciiDigits(String(value)).replace(/[0-9]/g, (digit) => PERSIAN_DIGITS[Number(digit)]!)
}

/** Only the digits of a value, normalised to ASCII: `«۱۲ ۳-۴»` becomes `1234`. */
export function digitsOnly(value: string | null | undefined): string {
  return toAsciiDigits(value).replace(/\D/g, '')
}
