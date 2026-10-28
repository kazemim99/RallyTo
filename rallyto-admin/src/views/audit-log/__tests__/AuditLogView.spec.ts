import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import Antd from 'ant-design-vue'
import { createPinia, setActivePinia } from 'pinia'
import { createMemoryHistory, createRouter } from 'vue-router'
import fa from '../../../locales/fa.json'
import { createAppI18n } from '../../../locales'
import { tokenStorage } from '../../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens, type FakeReply, type RecordedRequest } from '../../../utils/__tests__/fakeApi'
import { byTestId, choose, click, page$, type } from '../../../utils/__tests__/dom'
import { ADMIN_ID, TARGET_ID, auditEntry } from '../../../api/__tests__/safetyFixtures'
import AuditLogView from '../AuditLogView.vue'

vi.setConfig({ testTimeout: 30_000 })

const AUDIT = '/api/v1/admin/audit'

const ENTRIES = [
  auditEntry({ id: 'e-1', action: 'player.correct-gender', reason: 'اشتباه در ثبت' }),
  auditEntry({ id: 'e-2', action: 'venue.update', targetType: 'Venue', targetId: 'v-1', targetUserId: null, reason: null }),
  auditEntry({ id: 'e-3', action: 'something.brand-new', targetType: 'Widget', targetId: 'w-1', targetUserId: null }),
]

let api: ReturnType<typeof installFakeApi> | undefined
let wrapper: VueWrapper | undefined

function serve(reply?: (r: RecordedRequest) => FakeReply) {
  api = installFakeApi(
    reply ?? (() => ({ status: 200, body: envelope({ items: ENTRIES, page: 1, pageSize: 20, totalCount: ENTRIES.length }) })),
  )
}

async function mountAudit() {
  const pinia = createPinia()
  setActivePinia(pinia)
  const stub = { template: '<div />' }
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/audit-log', name: 'AuditLog', component: stub },
      { path: '/reports/targets/:userId', name: 'ReportTarget', component: stub },
    ],
  })
  await router.push('/audit-log')
  wrapper = mount(AuditLogView, { attachTo: document.body, global: { plugins: [pinia, createAppI18n(), Antd, router] } })
  await flushPromises()
  return wrapper
}

const reads = () => api!.to(AUDIT)
const lastParams = () => reads()[reads().length - 1]!.params
const row = (id: string) => page$().find(`tr[data-row-key="${id}"]`)

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

describe('Audit log: the table', () => {
  it('loads the first page unfiltered, naming known actions in Persian and showing unknown ones as sent', async () => {
    serve()
    await mountAudit()

    expect(reads()).toHaveLength(1)
    expect(lastParams()).toEqual({ page: 1, pageSize: 20 })
    expect(byTestId('audit-total').text()).toBe('۳ رویداد')

    expect(row('e-1').find('[data-testid="cell-action"]').text()).toBe(fa.audit.actionNames.player_correct_gender)
    expect(row('e-1').text()).toContain('player.correct-gender')
    expect(row('e-1').text()).toContain('اشتباه در ثبت')
    expect(row('e-1').find('[data-testid="cell-target-link"]').attributes('href')).toBe(`/reports/targets/${TARGET_ID}`)

    expect(row('e-2').find('[data-testid="cell-action"]').text()).toBe(fa.audit.actionNames.venue_update)
    expect(row('e-2').text()).toContain(fa.audit.targetTypes.Venue)
    expect(row('e-2').find('[data-testid="cell-target-link"]').exists()).toBe(false)

    expect(row('e-3').find('[data-testid="cell-action"]').text()).toBe('something.brand-new')
    expect(row('e-3').text()).toContain('Widget')
  })

  it('shows a failed read', async () => {
    serve(() => ({ status: 500, body: errorEnvelope(500, 'خطای سرور.') }))
    await mountAudit()

    expect(byTestId('audit-error').text()).toContain('خطای سرور.')
  })
})

describe('Audit log: filters', () => {
  it('filters by admin, target, a typed action and Jalali days, sent as ASCII yyyy/MM/dd', async () => {
    serve()
    await mountAudit()

    await type('audit-admin', ADMIN_ID)
    await type('audit-target', TARGET_ID)
    await type('audit-action', 'player.correct-gender')
    await choose('audit-from-year', '۱۴۰۵')
    await choose('audit-from-month', 'مهر')
    await choose('audit-from-day', '۲۵')
    await choose('audit-to-year', '۱۴۰۵')
    await choose('audit-to-month', 'آبان')
    await choose('audit-to-day', '۱')
    await click(byTestId('audit-apply'))

    expect(lastParams()).toEqual({
      adminId: ADMIN_ID,
      targetUserId: TARGET_ID,
      action: 'player.correct-gender',
      from: '1405/07/25',
      to: '1405/08/01',
      page: 1,
      pageSize: 20,
    })
  })

  it('offers the known actions to pick from', async () => {
    serve()
    await mountAudit()

    await page$().find('[data-testid="audit-action"] input').trigger('focus')
    await type('audit-action', 'تعلیق')
    const options = page$().findAll('.ant-select-item-option')
    expect(options.map((o) => o.text())).toContain(`${fa.audit.actionNames.account_suspend} (account.suspend)`)

    await click(options.find((o) => o.text().includes('(account.suspend)'))!)
    await click(byTestId('audit-apply'))

    expect(lastParams()).toMatchObject({ action: 'account.suspend' })
  })

  it('refuses an id that is not a GUID and a range that ends before it starts, without asking the server', async () => {
    serve()
    await mountAudit()

    await type('audit-admin', '09121234567')
    await choose('audit-from-year', '۱۴۰۵')
    await choose('audit-from-month', 'آبان')
    await choose('audit-from-day', '۲')
    await choose('audit-to-year', '۱۴۰۵')
    await choose('audit-to-month', 'آبان')
    await choose('audit-to-day', '۱')
    await click(byTestId('audit-apply'))

    expect(page$().text()).toContain(fa.audit.errors.invalidId)
    expect(page$().text()).toContain(fa.audit.errors.range)
    expect(reads()).toHaveLength(1)
  })

  it('sets the last seven days in one click, and clears everything', async () => {
    serve()
    await mountAudit()

    await type('audit-admin', ADMIN_ID)
    await click(byTestId('audit-last7'))
    expect(lastParams()).toEqual({ adminId: ADMIN_ID, from: '1405/07/25', to: '1405/08/01', page: 1, pageSize: 20 })

    await click(byTestId('audit-reset'))
    expect(lastParams()).toEqual({ page: 1, pageSize: 20 })
  })
})
