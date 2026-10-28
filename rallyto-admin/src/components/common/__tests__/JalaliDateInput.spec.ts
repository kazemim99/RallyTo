import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import Antd from 'ant-design-vue'
import { createAppI18n } from '../../../locales'
import { choose } from '../../../utils/__tests__/dom'
import JalaliDateInput from '../JalaliDateInput.vue'

vi.setConfig({ testTimeout: 20_000 })

let wrapper: VueWrapper | undefined

function mountInput(modelValue = '') {
  wrapper = mount(JalaliDateInput, {
    props: {
      modelValue,
      testId: 'day',
      years: [1404, 1405],
      'onUpdate:modelValue': (value: string) => wrapper!.setProps({ modelValue: value }),
    },
    attachTo: document.body,
    global: { plugins: [createAppI18n(), Antd] },
  })
  return wrapper
}

const emitted = () => (wrapper!.emitted('update:modelValue') ?? []).map((args) => args[0])

beforeEach(() => {
  vi.useFakeTimers({ toFake: ['Date'] })
  vi.setSystemTime(new Date('2026-10-23T08:00:00Z'))
})

afterEach(() => {
  wrapper?.unmount()
  wrapper = undefined
  vi.useRealTimers()
  document.body.innerHTML = ''
})

describe('Jalali date input', () => {
  it('emits yyyy/MM/dd with ASCII digits only once day, month and year are all chosen', async () => {
    mountInput()
    await flushPromises()

    await choose('day-day', '۸')
    await choose('day-month', 'آبان')
    expect(emitted()).toEqual([])

    await choose('day-year', '۱۴۰۵')
    expect(emitted()).toEqual(['1405/08/08'])
  })

  it('shows a value set from outside, and clears when it is emptied', async () => {
    mountInput('1405/08/01')
    await flushPromises()
    expect(wrapper!.find('[data-testid="day-month"]').text()).toContain('آبان')

    await wrapper!.setProps({ modelValue: '' })
    await flushPromises()
    expect(wrapper!.find('[data-testid="day-month"]').text()).not.toContain('آبان')
  })

  it('moves day 31 back to 30 when the month is Mehr', async () => {
    mountInput('1405/06/31')
    await flushPromises()

    await choose('day-month', 'مهر')

    expect(emitted()).toEqual(['1405/07/30'])
  })
})
