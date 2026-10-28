import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import Antd from 'ant-design-vue'
import { createPinia, setActivePinia } from 'pinia'
import fa from '../../../locales/fa.json'
import { createAppI18n } from '../../../locales'
import { tokenStorage } from '../../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens, type FakeReply, type RecordedRequest } from '../../../utils/__tests__/fakeApi'
import { byTestId, choose, click, page$ } from '../../../utils/__tests__/dom'
import { usageStats } from '../../../api/__tests__/statsFixtures'
import DashboardView from '../DashboardView.vue'

vi.setConfig({ testTimeout: 30_000 })

const STATS = '/api/v1/admin/stats'

let api: ReturnType<typeof installFakeApi> | undefined
let wrapper: VueWrapper | undefined

function serve(reply?: (r: RecordedRequest) => FakeReply) {
  api = installFakeApi(
    reply ??
      ((request) => {
        const params = (request.params ?? {}) as { from?: string; to?: string }
        return { status: 200, body: envelope(usageStats({ from: params.from ?? '1405/07/02', to: params.to ?? '1405/08/01' })) }
      }),
  )
}

async function mountDashboard() {
  const pinia = createPinia()
  setActivePinia(pinia)
  wrapper = mount(DashboardView, { attachTo: document.body, global: { plugins: [pinia, createAppI18n(), Antd] } })
  await flushPromises()
  return wrapper
}

const reads = () => api!.to(STATS)
const lastParams = () => reads()[reads().length - 1]!.params
const tile = (metric: string) => byTestId(`tile-${metric}`).find('[data-testid="tile-value"]').text()

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Player', 'Admin']), 'admin@rallyto.ir')
  vi.useFakeTimers({ toFake: ['Date'] })
  vi.setSystemTime(new Date('2026-10-23T08:00:00Z')) // 1405/08/01 in Tehran
})

afterEach(() => {
  wrapper?.unmount()
  wrapper = undefined
  api?.restore()
  vi.useRealTimers()
  document.body.innerHTML = ''
})

describe('Usage dashboard', () => {
  it('opens on the server’s default period and shows every figure as a tile', async () => {
    serve()
    await mountDashboard()

    expect(reads()).toHaveLength(1)
    expect(lastParams()).toEqual({})
    expect(byTestId('dashboard-period').text()).toBe('از ۱۴۰۵/۰۷/۰۲ تا ۱۴۰۵/۰۸/۰۱')

    expect(tile('signUps')).toBe('۱٬۲۳۴')
    expect(tile('activePlayers')).toBe('۵۶۰')
    expect(tile('posts')).toBe('۸۷')
    expect(tile('invitations')).toBe('۱۲')
    expect(tile('confirmedMatches')).toBe('۴۰')
    expect(tile('completedMatches')).toBe('۲۰')
    expect(tile('resolvedMatches')).toBe('۳۰')
    expect(tile('completionRate')).toBe('۶۶٫۷٪')
    expect(tile('reports')).toBe('۹')
    expect(tile('openReports')).toBe('۴')
    expect(byTestId('tile-completionRate').text()).toContain(fa.dashboard.metrics.completionRate)
  })

  it('shows "—" for the completion rate when no match was resolved', async () => {
    serve(() => ({ status: 200, body: envelope(usageStats({ completedMatches: 0, resolvedMatches: 0, completionRate: null })) }))
    await mountDashboard()

    expect(tile('completionRate')).toBe('—')
  })

  it('reads another period picked as Jalali days, sent as ASCII yyyy/MM/dd', async () => {
    serve()
    await mountDashboard()

    await choose('dashboard-from-month', 'آبان')
    await choose('dashboard-from-day', '۱')
    await choose('dashboard-to-day', '۲')
    await click(byTestId('dashboard-apply'))

    expect(lastParams()).toEqual({ from: '1405/08/01', to: '1405/08/02' })
    expect(byTestId('dashboard-period').text()).toBe('از ۱۴۰۵/۰۸/۰۱ تا ۱۴۰۵/۰۸/۰۲')
  })

  it('sets the last 7 days in one click', async () => {
    serve()
    await mountDashboard()

    await click(byTestId('dashboard-last-7'))

    expect(lastParams()).toEqual({ from: '1405/07/25', to: '1405/08/01' })
  })

  it('refuses an end before the start without asking the server', async () => {
    serve()
    await mountDashboard()

    await choose('dashboard-from-month', 'آبان')
    await choose('dashboard-from-day', '۱')
    await choose('dashboard-to-month', 'مهر')
    await click(byTestId('dashboard-apply'))

    expect(page$().text()).toContain(fa.dashboard.errors.range)
    expect(reads()).toHaveLength(1)
  })

  it('shows a failed read', async () => {
    serve(() => ({ status: 500, body: errorEnvelope(500, 'خطای سرور.') }))
    await mountDashboard()

    expect(byTestId('dashboard-error').text()).toContain('خطای سرور.')
  })
})
