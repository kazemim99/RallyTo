import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import Antd from 'ant-design-vue'
import { createPinia, setActivePinia } from 'pinia'
import { createMemoryHistory, createRouter, type Router } from 'vue-router'
import fa from '../../../locales/fa.json'
import { createAppI18n } from '../../../locales'
import { tokenStorage } from '../../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens, type FakeReply, type RecordedRequest } from '../../../utils/__tests__/fakeApi'
import { byTestId, click, page$, type } from '../../../utils/__tests__/dom'
import { MATCH_ID, MESSAGE_ID, TARGET_ID, report, reportGroup } from '../../../api/__tests__/safetyFixtures'
import ReportsView from '../ReportsView.vue'

vi.setConfig({ testTimeout: 20_000 })

const QUEUE = '/api/v1/admin/reports'
const OTHER = '99999999-9999-9999-9999-999999999999'

const GROUPS = [
  reportGroup({
    targetUserId: OTHER,
    targetName: 'رضا کریمی',
    highPriority: true,
    openReports: 3,
    distinctReporters: 3,
    oldestReportAt: '2026-10-20T07:00:00Z',
    reports: [
      report({ id: 'r-msg', targetType: 'Message', targetId: MESSAGE_ID, reason: 'Harassment', evidence: { text: 'پیام توهین‌آمیز', displayName: 'رضا کریمی', bio: null, photoUrl: null, sentAt: '2026-10-19T18:00:00Z' } }),
      report({ id: 'r-post', targetType: 'Post', targetId: MATCH_ID, reason: 'Spam', details: null, evidence: { text: 'تبلیغ کلاس خصوصی', displayName: 'رضا کریمی', bio: null, photoUrl: null, sentAt: null } }),
      report({ id: 'r-photo', targetType: 'Photo', reason: 'InappropriateContent', evidence: { text: null, displayName: 'رضا کریمی', bio: null, photoUrl: '/media/evidence/p.jpg', sentAt: null } }),
    ],
  }),
  reportGroup({ oldestReportAt: '2026-10-23T03:00:00Z' }),
]

let api: ReturnType<typeof installFakeApi> | undefined
let wrapper: VueWrapper | undefined
let router: Router

function serve(options: { queue?: (r: RecordedRequest) => FakeReply; command?: (r: RecordedRequest) => FakeReply } = {}) {
  const queue = options.queue ?? (() => ({ status: 200, body: envelope(GROUPS) }))
  const command = options.command ?? (() => ({ status: 204 }))
  api = installFakeApi((request) => (request.method === 'GET' && request.url === QUEUE ? queue(request) : command(request)))
}

async function mountQueue() {
  const pinia = createPinia()
  setActivePinia(pinia)
  const stub = { template: '<div />' }
  router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/reports', name: 'Reports', component: stub },
      { path: '/reports/targets/:userId', name: 'ReportTarget', component: stub },
    ],
  })
  await router.push('/reports')
  wrapper = mount(ReportsView, { attachTo: document.body, global: { plugins: [pinia, createAppI18n(), Antd, router] } })
  await flushPromises()
  return wrapper
}

const row = (userId: string) => page$().find(`tr[data-row-key="${userId}"]`)
const queueReads = () => api!.to(QUEUE).filter((r) => r.method === 'GET')

async function expand(userId: string) {
  await click(row(userId).find('.ant-table-row-expand-icon'))
}

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Player', 'Admin']), 'admin@rallyto.ir')
  vi.useFakeTimers({ toFake: ['Date'] })
  vi.setSystemTime(new Date('2026-10-23T08:00:00Z'))
})

afterEach(() => {
  wrapper?.unmount()
  wrapper = undefined
  api?.restore()
  vi.useRealTimers()
  document.body.innerHTML = ''
})

describe('Report queue: the groups', () => {
  it('lists each reported player in the server’s order, with priority, open count, reporters and the oldest report’s age', async () => {
    serve()
    await mountQueue()

    expect(queueReads()).toHaveLength(1)
    const rows = page$().findAll('tr[data-row-key]')
    expect(rows.map((r) => r.attributes('data-row-key'))).toEqual([OTHER, TARGET_ID])
    expect(byTestId('reports-total').text()).toBe('۲ بازیکن گزارش‌شده')

    const high = row(OTHER)
    expect(high.find('[data-testid="group-target"]').text()).toBe('رضا کریمی')
    expect(high.find('[data-testid="group-priority"]').text()).toBe(fa.reports.priority.high)
    expect(high.find('[data-testid="group-priority"]').classes()).toContain('ant-tag-red')
    expect(high.find('[data-testid="group-open"]').text()).toBe('۳')
    expect(high.find('[data-testid="group-reporters"]').text()).toBe('۳')
    expect(high.find('[data-testid="group-oldest"]').text()).toBe('۳ روز پیش')

    const normal = row(TARGET_ID)
    expect(normal.find('[data-testid="group-priority"]').text()).toBe(fa.reports.priority.normal)
    expect(normal.find('[data-testid="group-oldest"]').text()).toBe('۵ ساعت پیش')
  })

  it('says so when the queue is empty, and shows a failed read', async () => {
    serve({ queue: () => ({ status: 200, body: envelope([]) }) })
    await mountQueue()
    expect(page$().text()).toContain(fa.reports.empty)

    wrapper!.unmount()
    serve({ queue: () => ({ status: 500, body: errorEnvelope(500, 'خطای سرور.') }) })
    await mountQueue()
    expect(byTestId('reports-error').text()).toContain('خطای سرور.')
  })

  it('opens the player’s file', async () => {
    serve()
    await mountQueue()

    await click(row(OTHER).find('[data-testid="group-open-detail"]'))

    expect(router.currentRoute.value.name).toBe('ReportTarget')
    expect(router.currentRoute.value.params.userId).toBe(OTHER)
  })
})

describe('Report queue: a group’s reports', () => {
  it('expands to each report with its reporter, reason, details, date and evidence snapshot', async () => {
    serve()
    await mountQueue()

    await expand(OTHER)

    const message = byTestId('report-r-msg')
    expect(message.find('[data-testid="report-reason"]').text()).toBe(fa.safety.reasons.Harassment)
    expect(message.find('[data-testid="report-target-type"]').text()).toBe(fa.safety.targetTypes.Message)
    expect(message.find('[data-testid="report-reporter"]').text()).toBe('بهار احمدی')
    expect(message.find('[data-testid="report-details"]').text()).toBe('در چت بازی توهین کرد.')
    expect(message.find('[data-testid="report-target-id"]').text()).toBe(MESSAGE_ID)
    expect(message.find('[data-testid="report-date"]').text()).toContain('۱۴۰۵/۰۷/۲۸ ۱۱:۳۰')
    expect(message.find('[data-testid="evidence-text"]').text()).toBe('پیام توهین‌آمیز')
    expect(message.find('[data-testid="evidence-sent-at"]').text()).toContain('۱۴۰۵/۰۷/۲۷ ۲۱:۳۰')

    expect(byTestId('report-r-post').find('[data-testid="report-details"]').text()).toBe(fa.reports.report.noDetails)

    const photo = byTestId('report-r-photo').find('img')
    expect(photo.attributes('src')).toMatch(/\/media\/evidence\/p\.jpg$/)
  })
})

describe('Report queue: dismissing a report', () => {
  it('requires a reason, then posts it and re-reads the queue', async () => {
    serve()
    await mountQueue()
    await expand(OTHER)

    await click(byTestId('report-dismiss-r-post'))
    await click(byTestId('dismiss-submit'))

    expect(page$().text()).toContain(fa.moderation.errors.reasonRequired)
    expect(api!.requests.filter((r) => r.method === 'POST')).toHaveLength(0)

    await type('dismiss-reason', ' آگهی عادی است ', 'textarea')
    await click(byTestId('dismiss-submit'))

    expect(api!.requests.filter((r) => r.method === 'POST')).toEqual([
      expect.objectContaining({ url: '/api/v1/admin/reports/r-post/dismiss', body: { reason: 'آگهی عادی است' } }),
    ])
    expect(queueReads()).toHaveLength(2)
  })

  it('keeps the dialog open with the server’s message when refused', async () => {
    serve({ command: () => ({ status: 409, body: errorEnvelope(409, 'این گزارش قبلاً بررسی شده است.', 'REPORT_CLOSED') }) })
    await mountQueue()
    await expand(OTHER)

    await click(byTestId('report-dismiss-r-msg'))
    await type('dismiss-reason', 'بی‌پایه', 'textarea')
    await click(byTestId('dismiss-submit'))

    expect(byTestId('dismiss-error').text()).toContain('این گزارش قبلاً بررسی شده است.')
    expect(queueReads()).toHaveLength(2) // a 409 re-reads the queue
  })
})
