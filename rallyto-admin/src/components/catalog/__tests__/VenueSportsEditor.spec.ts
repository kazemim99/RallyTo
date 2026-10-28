import { afterEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import Antd from 'ant-design-vue'
import fa from '../../../locales/fa.json'
import { createAppI18n } from '../../../locales'
import type { VenueSport } from '../../../api/venues.api'
import { SPORTS, venueSport } from '../../../api/__tests__/catalogFixtures'
import { byTestId, choose, click, fieldOf, page$, type } from '../../../utils/__tests__/dom'
import VenueSportsEditor from '../VenueSportsEditor.vue'

vi.setConfig({ testTimeout: 20_000 })

let wrapper: VueWrapper | undefined

/** Mounts the editor with a working v-model, so each change builds on the last emitted list. */
async function mountEditor(initial: VenueSport[] = []) {
  wrapper = mount(VenueSportsEditor, {
    attachTo: document.body,
    props: {
      modelValue: initial,
      sports: SPORTS,
      'onUpdate:modelValue': (value: VenueSport[]) => wrapper!.setProps({ modelValue: value }),
    },
    global: { plugins: [createAppI18n(), Antd] },
  })
  await flushPromises()
  return wrapper
}

const emitted = () => (wrapper!.emitted('update:modelValue') ?? []).map((args) => args[0] as VenueSport[])
const last = () => emitted()[emitted().length - 1]!

afterEach(() => {
  wrapper?.unmount()
  wrapper = undefined
  document.body.innerHTML = ''
})

describe('VenueSportsEditor', () => {
  it('lists the active sports only, plus an inactive one the club already has', async () => {
    await mountEditor()
    expect(page$().find('[data-testid="sport-row-tennis"]').exists()).toBe(true)
    expect(page$().find('[data-testid="sport-row-padel"]').exists()).toBe(true)
    expect(page$().find('[data-testid="sport-row-squash"]').exists()).toBe(false)
    wrapper!.unmount()
    document.body.innerHTML = ''

    await mountEditor([venueSport({ sportCode: 'squash', surface: 'Wood' })])
    expect(byTestId('sport-row-squash').text()).toContain(fa.catalog.sportsEditor.inactive)
  })

  it('ticking a sport emits it with nothing known but the default setting', async () => {
    await mountEditor()

    await click(fieldOf('sport-toggle-padel', 'input'))

    expect(last()).toEqual([{ sportCode: 'padel', courtCount: null, setting: 'Outdoor', surface: null, hasLighting: false }])
  })

  it('emits the full court details, in catalog order whatever the order of ticking', async () => {
    await mountEditor()

    await click(fieldOf('sport-toggle-padel', 'input'))
    await click(fieldOf('sport-toggle-tennis', 'input'))
    await type('sport-courts-tennis', '۴')
    await choose('sport-setting-tennis', fa.catalog.settings.Indoor)
    await choose('sport-surface-tennis', fa.catalog.surfaces.Clay)
    await click(fieldOf('sport-lighting-tennis', 'input'))

    expect(last()).toEqual([
      { sportCode: 'tennis', courtCount: 4, setting: 'Indoor', surface: 'Clay', hasLighting: true },
      { sportCode: 'padel', courtCount: null, setting: 'Outdoor', surface: null, hasLighting: false },
    ])
  })

  it('offers only the surfaces of that sport', async () => {
    await mountEditor([venueSport({ sportCode: 'padel', surface: null })])

    await page$().find('[data-testid="sport-surface-padel"] .ant-select-selector').trigger('mousedown')
    await flushPromises()

    const titles = page$()
      .findAll('.ant-select-item-option')
      .map((option) => option.attributes('title'))
    expect(titles).toEqual([fa.catalog.surfaces.ArtificialGrass, fa.catalog.surfaces.Glass])
  })

  it('unticking a sport removes it', async () => {
    await mountEditor([venueSport(), venueSport({ sportCode: 'padel', surface: 'Glass' })])

    await click(fieldOf('sport-toggle-tennis', 'input'))

    expect(last().map((s) => s.sportCode)).toEqual(['padel'])
    expect(page$().find('[data-testid="sport-courts-tennis"]').exists()).toBe(false)
  })
})
