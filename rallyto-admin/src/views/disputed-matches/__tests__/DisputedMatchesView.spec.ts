import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import Antd from 'ant-design-vue'
import { createPinia, setActivePinia } from 'pinia'
import { createMemoryHistory, createRouter } from 'vue-router'
import fa from '../../../locales/fa.json'
import { createAppI18n } from '../../../locales'
import { tokenStorage } from '../../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens, type FakeReply } from '../../../utils/__tests__/fakeApi'
import { byTestId, page$ } from '../../../utils/__tests__/dom'
import { SPORTS } from '../../../api/__tests__/catalogFixtures'
import { MATCH_ID, REPORTER_ID, TARGET_ID, disputedMatch } from '../../../api/__tests__/safetyFixtures'
import DisputedMatchesView from '../DisputedMatchesView.vue'

vi.setConfig({ testTimeout: 20_000 })

const DISPUTED = '/api/v1/admin/matches/disputed'
const SPORTS_LIST = '/api/v1/admin/sports'
const COMPLETED = '77777777-7777-7777-7777-777777777777'

const MATCHES = [
  disputedMatch(),
  disputedMatch({
    matchId: COMPLETED,
    status: 'Completed',
    sportId: 's-padel',
    date: '1405/07/20',
    players: [
      { userId: TARGET_ID, displayName: 'علی رضایی', answer: 'Played', outcome: 'Contested' },
      { userId: REPORTER_ID, displayName: 'بهار احمدی', answer: null, outcome: 'Played' },
    ],
  }),
]

let api: ReturnType<typeof installFakeApi> | undefined
let wrapper: VueWrapper | undefined

function serve(disputed: () => FakeReply = () => ({ status: 200, body: envelope(MATCHES) })) {
  api = installFakeApi((request) => (request.url === SPORTS_LIST ? { status: 200, body: envelope(SPORTS) } : disputed()))
}

async function mountList(query = '') {
  const pinia = createPinia()
  setActivePinia(pinia)
  const stub = { template: '<div />' }
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/disputed-matches', name: 'DisputedMatches', component: stub },
      { path: '/reports/targets/:userId', name: 'ReportTarget', component: stub },
    ],
  })
  await router.push(`/disputed-matches${query}`)
  wrapper = mount(DisputedMatchesView, { attachTo: document.body, global: { plugins: [pinia, createAppI18n(), Antd, router] } })
  await flushPromises()
  return wrapper
}

const row = (id: string) => page$().find(`tr[data-row-key="${id}"]`)

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

describe('Disputed matches', () => {
  it('lists each match with its day, sport, status, and every player’s answer and outcome', async () => {
    serve()
    await mountList()

    expect(api!.to(DISPUTED)).toHaveLength(1)
    expect(byTestId('disputes-total').text()).toBe('۲ بازی')

    const disputed = row(MATCH_ID)
    expect(disputed.find('[data-testid="cell-date"]').text()).toBe('۱۴۰۵/۰۷/۲۸')
    expect(disputed.text()).toContain('تنیس')
    expect(disputed.find('[data-testid="cell-status"]').text()).toBe(fa.safety.matchStatus.Disputed)
    const ali = disputed.find(`[data-testid="player-${TARGET_ID}"]`)
    expect(ali.text()).toContain('علی رضایی')
    expect(ali.find('[data-testid="player-answer"]').text()).toBe(fa.safety.answers.Played)
    expect(ali.find('[data-testid="player-outcome"]').exists()).toBe(false)
    expect(ali.find('a').attributes('href')).toBe(`/reports/targets/${TARGET_ID}`)
    expect(disputed.find(`[data-testid="player-${REPORTER_ID}"] [data-testid="player-answer"]`).text()).toBe(fa.safety.answers.DidNotHappen)

    const contested = row(COMPLETED)
    expect(contested.text()).toContain('پدل')
    expect(contested.find('[data-testid="cell-status"]').text()).toBe(fa.safety.matchStatus.Completed)
    expect(contested.find(`[data-testid="player-${TARGET_ID}"] [data-testid="player-outcome"]`).text()).toBe(fa.safety.outcomes.Contested)
    expect(contested.find(`[data-testid="player-${REPORTER_ID}"] [data-testid="player-answer"]`).text()).toBe(fa.disputes.noAnswer)
  })

  it('highlights the match a dispute link points to', async () => {
    serve()
    await mountList(`?match=${COMPLETED}`)

    expect(row(COMPLETED).classes()).toContain('highlighted')
    expect(row(MATCH_ID).classes()).not.toContain('highlighted')
  })

  it('says so when there are none, and shows a failed read', async () => {
    serve(() => ({ status: 200, body: envelope([]) }))
    await mountList()
    expect(page$().text()).toContain(fa.disputes.empty)

    wrapper!.unmount()
    serve(() => ({ status: 500, body: errorEnvelope(500, 'خطای سرور.') }))
    await mountList()
    expect(byTestId('disputes-error').text()).toContain('خطای سرور.')
  })
})
