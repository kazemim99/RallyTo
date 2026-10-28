import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import Antd from 'ant-design-vue'
import { createPinia, setActivePinia } from 'pinia'
import fa from '../../../locales/fa.json'
import { createAppI18n } from '../../../locales'
import { tokenStorage } from '../../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens, type FakeReply, type RecordedRequest } from '../../../utils/__tests__/fakeApi'
import { byTestId, choose, click, fieldOf, page$, type } from '../../../utils/__tests__/dom'
import { SPORTS, sport } from '../../../api/__tests__/catalogFixtures'
import SportsView from '../SportsView.vue'

vi.setConfig({ testTimeout: 20_000 })

const LIST = '/api/v1/admin/sports'

let api: ReturnType<typeof installFakeApi> | undefined
let wrapper: VueWrapper | undefined

function serve(command: (r: RecordedRequest) => FakeReply = () => ({ status: 200, body: envelope(sport()) })) {
  api = installFakeApi((request) =>
    request.method === 'GET' && request.url === LIST ? { status: 200, body: envelope(SPORTS) } : command(request),
  )
}

async function mountSports() {
  const pinia = createPinia()
  setActivePinia(pinia)
  wrapper = mount(SportsView, { attachTo: document.body, global: { plugins: [pinia, createAppI18n(), Antd] } })
  await flushPromises()
  return wrapper
}

const row = (id: string) => page$().find(`tr[data-row-key="${id}"]`)
const commands = () => api!.requests.filter((r) => r.method !== 'GET')

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Player', 'Admin']), 'admin@rallyto.ir')
})

afterEach(() => {
  wrapper?.unmount()
  wrapper = undefined
  api?.restore()
  document.body.innerHTML = ''
})

describe('Sports: the table', () => {
  it('shows each sport with its code, status, formats and default session', async () => {
    serve()
    await mountSports()

    const tennis = row('s-tennis')
    expect(tennis.text()).toContain('تنیس')
    expect(tennis.find('[data-testid="cell-code"]').text()).toBe('tennis')
    expect(tennis.find('[data-testid="cell-status"]').text()).toBe(fa.sports.status.active)
    expect(tennis.findAll('[data-testid="cell-format"]').map((f) => f.text())).toEqual([
      `${fa.catalog.formats.Singles} (۱ نفر در هر طرف)`,
      `${fa.catalog.formats.Doubles} (۲ نفر در هر طرف)`,
    ])
    expect(tennis.text()).toContain('۹۰ دقیقه')
    expect(row('s-squash').find('[data-testid="cell-status"]').text()).toBe(fa.sports.status.inactive)
    expect(row('s-squash').find('[data-testid="action-activate"]').exists()).toBe(true)
    expect(byTestId('sports-total').text()).toContain('۳')
  })
})

describe('Sports: create and edit', () => {
  it('creates a sport with all five level descriptions, in tier order', async () => {
    serve(() => ({ status: 201, body: envelope(sport({ code: 'badminton' }), 201) }))
    await mountSports()

    await click(byTestId('sports-add'))
    await type('sport-code', 'badminton')
    await type('sport-name-fa', 'بدمینتون')
    await type('sport-name-en', 'Badminton')
    await click(fieldOf('sport-format-Doubles', 'input'))
    await choose('sport-surfaces', fa.catalog.surfaces.Wood)
    const descriptions = ['تازه‌کار', 'رالی کوتاه', 'رالی پایدار', 'تاکتیکی', 'مسابقه‌ای']
    const tiers = ['Beginner', 'LowerIntermediate', 'Intermediate', 'Advanced', 'Professional']
    for (const [index, tier] of tiers.entries()) {
      // Each textarea is labelled with the tier's Persian name.
      expect(page$().find(`label[title="${fa.catalog.tiers[tier as keyof typeof fa.catalog.tiers]}"]`).exists()).toBe(true)
      await type(`sport-level-${tier}`, descriptions[index]!, 'textarea')
    }
    await click(byTestId('sport-submit'))

    expect(commands()).toHaveLength(1)
    expect(commands()[0]).toMatchObject({ method: 'POST', url: LIST })
    expect(commands()[0]!.body).toEqual({
      code: 'badminton',
      nameFa: 'بدمینتون',
      nameEn: 'Badminton',
      sortOrder: 4,
      defaultSessionMinutes: 60,
      formats: [
        { format: 'Singles', playersPerSide: 1 },
        { format: 'Doubles', playersPerSide: 2 },
      ],
      levels: tiers.map((tier, index) => ({ tier, description: descriptions[index] })),
      surfaces: ['Wood'],
    })
    // The list is read again after the create.
    expect(api!.requests.filter((r) => r.method === 'GET')).toHaveLength(2)
  })

  it('sends nothing until the code is valid and every level is described', async () => {
    serve()
    await mountSports()

    await click(byTestId('sports-add'))
    await type('sport-code', 'Bad Minton')
    await type('sport-name-fa', 'بدمینتون')
    await type('sport-name-en', 'Badminton')
    await type('sport-level-Beginner', 'فقط یکی', 'textarea')
    await click(byTestId('sport-submit'))

    expect(commands()).toHaveLength(0)
    expect(page$().text()).toContain(fa.sports.form.codeInvalid)
    expect(page$().findAll('.ant-form-item-explain-error').filter((e) => e.text() === fa.sports.form.levelRequired)).toHaveLength(4)
  })

  it('edits with PUT, the code locked and the levels prefilled', async () => {
    serve()
    await mountSports()

    await click(row('s-padel').find('[data-testid="action-edit"]'))
    expect(fieldOf('sport-code', 'input').attributes('disabled')).toBeDefined()
    expect((fieldOf('sport-level-Advanced', 'textarea').element as HTMLTextAreaElement).value).toBe('بازی تاکتیکی')
    await type('sport-name-fa', 'پدل (پادل)')
    await click(byTestId('sport-submit'))

    expect(commands()[0]).toMatchObject({ method: 'PUT', url: `${LIST}/s-padel` })
    expect(commands()[0]!.body).toMatchObject({
      code: 'padel',
      nameFa: 'پدل (پادل)',
      formats: [{ format: 'Doubles', playersPerSide: 2 }],
      surfaces: ['ArtificialGrass', 'Glass'],
    })
    expect((commands()[0]!.body as { levels: unknown[] }).levels).toHaveLength(5)
  })

  it('shows the server’s Persian message and stays open when the create is refused', async () => {
    serve(() => ({ status: 409, body: errorEnvelope(409, 'این کد قبلاً ثبت شده است.', 'SPORT_CODE_TAKEN') }))
    await mountSports()

    await click(byTestId('sports-add'))
    await type('sport-code', 'tennis')
    await type('sport-name-fa', 'تنیس')
    await type('sport-name-en', 'Tennis')
    for (const tier of ['Beginner', 'LowerIntermediate', 'Intermediate', 'Advanced', 'Professional']) {
      await type(`sport-level-${tier}`, 'توضیح', 'textarea')
    }
    await click(byTestId('sport-submit'))

    expect(byTestId('sport-error').text()).toContain('این کد قبلاً ثبت شده است.')
  })
})

describe('Sports: activate and deactivate', () => {
  it('deactivates after the confirmation, then reloads', async () => {
    serve(() => ({ status: 204 }))
    await mountSports()

    await click(row('s-tennis').find('[data-testid="action-deactivate"]'))
    expect(commands()).toHaveLength(0)
    expect(page$().text()).toContain(fa.sports.deactivate.confirm)
    await click(byTestId('deactivate-submit'))

    expect(commands().map((r) => `${r.method} ${r.url}`)).toEqual([`POST ${LIST}/s-tennis/deactivate`])
    expect(api!.requests.filter((r) => r.method === 'GET')).toHaveLength(2)
  })

  it('activates an inactive sport after the confirmation', async () => {
    serve(() => ({ status: 204 }))
    await mountSports()

    await click(row('s-squash').find('[data-testid="action-activate"]'))
    await click(byTestId('activate-submit'))

    expect(commands().map((r) => r.url)).toEqual([`${LIST}/s-squash/activate`])
  })
})
