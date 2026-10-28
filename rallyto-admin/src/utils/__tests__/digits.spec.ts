import { describe, expect, it } from 'vitest'
import { digitsOnly, toAsciiDigits, toPersianDigits } from '../digits'

describe('toAsciiDigits', () => {
  it('turns Persian digits into ASCII', () => {
    expect(toAsciiDigits('۰۱۲۳۴۵۶۷۸۹')).toBe('0123456789')
  })

  it('turns Arabic-Indic digits into ASCII', () => {
    expect(toAsciiDigits('٠١٢٣٤٥٦٧٨٩')).toBe('0123456789')
  })

  it('handles a mix of Persian, Arabic-Indic and ASCII digits in one value', () => {
    // identity-access › Persian digits are normalised: ۰۹۱۲۳۴۵۶۷۸۹ is the same number as 09123456789.
    expect(toAsciiDigits('۰٩1۲٣4۵٦7۸٩')).toBe('09123456789')
  })

  it('keeps every other character as it is', () => {
    expect(toAsciiDigits('+۹۸ (۹۱۲) کد: ۱۲۳۴')).toBe('+98 (912) کد: 1234')
  })

  it('returns an empty string for a missing value', () => {
    expect(toAsciiDigits(undefined)).toBe('')
    expect(toAsciiDigits(null)).toBe('')
    expect(toAsciiDigits('')).toBe('')
  })
})

describe('toPersianDigits', () => {
  it('turns ASCII and Arabic-Indic digits into Persian digits for display', () => {
    expect(toPersianDigits('1405/08/01')).toBe('۱۴۰۵/۰۸/۰۱')
    expect(toPersianDigits('٤٥')).toBe('۴۵')
    expect(toPersianDigits(60)).toBe('۶۰')
  })

  it('returns an empty string for a missing value, but shows zero', () => {
    expect(toPersianDigits(null)).toBe('')
    expect(toPersianDigits(undefined)).toBe('')
    expect(toPersianDigits(0)).toBe('۰')
  })
})

describe('digitsOnly', () => {
  it('keeps only the digits, normalised to ASCII', () => {
    expect(digitsOnly('۱ ۲-۳ ۴')).toBe('1234')
    expect(digitsOnly('٠٩١٢')).toBe('0912')
    expect(digitsOnly(undefined)).toBe('')
  })
})
