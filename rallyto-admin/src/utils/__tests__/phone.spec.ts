import { describe, expect, it } from 'vitest'
import { formatPhone, normalizePhoneInput } from '../phone'

describe('normalizePhoneInput', () => {
  it('sends ASCII digits without the spaces, dashes and direction marks people type or paste', () => {
    expect(normalizePhoneInput('۰۹۱۲ ۱۲۳-۴۵۶۷')).toBe('09121234567')
    expect(normalizePhoneInput('‏٠٩١٢١٢٣٤٥٦٧‎')).toBe('09121234567')
    expect(normalizePhoneInput(' (0912) 123 4567 ')).toBe('09121234567')
  })

  it('keeps a leading plus, because the server normalises the prefix itself', () => {
    expect(normalizePhoneInput('+۹۸ ۹۱۲ ۱۲۳ ۴۵۶۷')).toBe('+989121234567')
  })
})

describe('formatPhone', () => {
  it('shows an Iranian mobile in its local form, isolated left-to-right', () => {
    expect(formatPhone('+989121234567')).toBe('⁦0912 123 4567⁩')
    expect(formatPhone('۰۹۱۲۱۲۳۴۵۶۷')).toBe('⁦0912 123 4567⁩')
  })

  it('shows anything else as given', () => {
    expect(formatPhone('12345')).toBe('⁦12345⁩')
    expect(formatPhone(undefined)).toBe('')
  })
})
