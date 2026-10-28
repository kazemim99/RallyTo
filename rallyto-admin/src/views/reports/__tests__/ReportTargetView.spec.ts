import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import Antd from 'ant-design-vue'
import { createPinia, setActivePinia } from 'pinia'
import { createMemoryHistory, createRouter, type Router } from 'vue-router'
import fa from '../../../locales/fa.json'
import { createAppI18n } from '../../../locales'
import { tokenStorage } from '../../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens, type FakeReply, type RecordedRequest } from '../../../utils/__tests__/fakeApi'
import { byTestId, choose, click, fieldOf, page$, type } from '../../../utils/__tests__/dom'
import { account } from '../../../api/__tests__/userFixtures'
import { formatDate } from '../../../utils/date'
import {
  MATCH_ID,
  MESSAGE_ID,
  TARGET_ID,
  moderationAction,
  report,
  targetDetail,
} from '../../../api/__tests__/safetyFixtures'
import type { AdminAccount } from '../../../api/users.api'
import ReportTargetView from '../ReportTargetView.vue'

vi.setConfig({ testTimeout: 30_000 })

const FILE = `/api/v1/admin/reports/targets/${TARGET_ID}`
const ACCOUNT = `/api/v1/admin/users/${TARGET_ID}`
const ACTIONS = '/api/v1/admin/moderation/actions'

const DETAIL = targetDetail({
  reports: [
    report({ id: 'r-post', targetType: 'Post', targetId: MATCH_ID, reason: 'Spam' }),
    report({ id: 'r-msg', targetType: 'Message', targetId: MESSAGE_ID, reason: 'Harassment' }),
    report({ id: 'r-old', status: 'Resolved', reason: 'FakeProfile' }),
  ],
  actions: [
    moderationAction({ action: 'Warn', reason: 'توهین در چت' }),
    moderationAction({ id: 'a-2', action: 'Suspend', reason: 'تکرار توهین', subject: '1405/07/10', reportId: null }),
  ],
})

let api: ReturnType<typeof installFakeApi> | undefined
let wrapper: VueWrapper | undefined
let router: Router

interface ServeOptions {
  file?: (r: RecordedRequest) => FakeReply
  owner?: Partial<AdminAccount> | null
  command?: (r: RecordedRequest) => FakeReply
}

function serve(options: ServeOptions = {}) {
  const file = options.file ?? (() => ({ status: 200, body: envelope(DETAIL) }))
  const owner = options.owner === undefined ? {} : options.owner
  const command = options.command ?? ((r) => (r.url === ACTIONS ? { status: 200, body: envelope(moderationAction()) } : { status: 204 }))
  api = installFakeApi((request) => {
    if (request.method === 'GET' && request.url === FILE) return file(request)
    if (request.method === 'GET' && request.url === ACCOUNT) {
      return owner ? { status: 200, body: envelope(account({ userId: TARGET_ID, ...owner })) } : { status: 500, body: errorEnvelope(500, 'خطا') }
    }
    return command(request)
  })
}

async function mountFile() {
  const pinia = createPinia()
  setActivePinia(pinia)
  const stub = { template: '<div />' }
  router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/reports', name: 'Reports', component: stub },
      { path: '/reports/targets/:userId', name: 'ReportTarget', component: stub },
      { path: '/disputed-matches', name: 'DisputedMatches', component: stub },
    ],
  })
  await router.push(`/reports/targets/${TARGET_ID}`)
  wrapper = mount(ReportTargetView, { attachTo: document.body, global: { plugins: [pinia, createAppI18n(), Antd, router] } })
  await flushPromises()
  return wrapper
}

const commands = () => api!.requests.filter((r) => r.method !== 'GET')
const fileReads = () => api!.to(FILE).filter((r) => r.method === 'GET')
const offered = () => page$().findAll('[data-testid^="target-action-"]').map((b) => b.attributes('data-testid')!.replace('target-action-', ''))

async function openAction(action: string) {
  await click(byTestId(`target-action-${action}`))
}

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

describe('Target file: what the admin sees', () => {
  it('shows the account status, reliability, every report with evidence, earlier actions, disputes and private notes', async () => {
    serve({ owner: { status: 'Active' } })
    await mountFile()

    expect(page$().text()).toContain('پرونده علی رضایی')
    expect(byTestId('target-account-status').text()).toBe(fa.users.status.Active)
    expect(byTestId('target-reliability').text()).toBe(fa.safety.reliability.Low)
    expect(byTestId('target-dispute-count').text()).toBe('۲ بازی مورد اختلاف')

    expect(byTestId('report-r-post').find('[data-testid="report-status"]').text()).toBe(fa.safety.reportStatus.Open)
    expect(byTestId('report-r-old').find('[data-testid="report-status"]').text()).toBe(fa.safety.reportStatus.Resolved)
    expect(byTestId('report-r-post').find('[data-testid="evidence-name"]').text()).toBe('علی رضایی')
    // Only an open report can be acted on or dismissed.
    expect(byTestId('report-act-r-post').exists()).toBe(true)
    expect(byTestId('report-act-r-old').exists()).toBe(false)
    expect(byTestId('report-dismiss-r-old').exists()).toBe(false)

    const history = byTestId('target-history')
    expect(history.findAll('[data-testid="history-action"]').map((c) => c.text())).toEqual([
      fa.moderation.actions.Warn,
      fa.moderation.actions.Suspend,
    ])
    expect(history.text()).toContain('تکرار توهین')
    expect(history.text()).toContain('۱۴۰۵/۰۷/۱۰')

    const link = byTestId(`dispute-link-${MATCH_ID}`)
    expect(link.attributes('href')).toBe(`/disputed-matches?match=${MATCH_ID}`)

    const notes = byTestId('target-notes')
    expect(notes.text()).toContain('بهار احمدی')
    expect(notes.find('[data-testid="note-stars"]').text()).toBe('۲ از ۵')
    expect(notes.find('[data-testid="note-text"]').text()).toBe('سر امتیازها بحث کرد.')
  })

  it('shows a suspended account with its end, and offers lifting rather than suspending', async () => {
    serve({ owner: { status: 'Suspended', suspendedUntil: '2026-10-30T20:30:00Z' } })
    await mountFile()

    expect(byTestId('target-account').text()).toContain(fa.users.status.Suspended)
    expect(byTestId('target-account').text()).toContain('۱۴۰۵/۰۸/۰۹ ۰۰:۰۰')
    expect(offered()).toContain('LiftSuspension')
    expect(offered()).not.toContain('Suspend')
  })

  it('still shows the file when the account cannot be read, offering every action', async () => {
    serve({ owner: null })
    await mountFile()

    expect(byTestId('target-account').text()).toBe(fa.reportTarget.accountUnknown)
    expect(offered()).toHaveLength(8)
  })

  it('offers only clean-up for a banned account', async () => {
    serve({ owner: { status: 'Banned' } })
    await mountFile()

    expect(offered()).toEqual(['RemovePhoto', 'HidePost', 'DeleteMessage'])
  })

  it('says so when the player has no profile', async () => {
    serve({ file: () => ({ status: 404, body: errorEnvelope(404, 'بازیکن پیدا نشد.', 'PLAYER_NOT_FOUND') }) })
    await mountFile()

    expect(byTestId('target-not-found').text()).toContain(fa.reportTarget.notFound)
  })

  it('goes back to the queue', async () => {
    serve()
    await mountFile()

    await click(byTestId('target-back'))

    expect(router.currentRoute.value.name).toBe('Reports')
  })
})

describe('Target file: action dialogs', () => {
  it('warns only with a reason and the warning text, then re-reads the file', async () => {
    serve()
    await mountFile()

    await openAction('Warn')
    await click(byTestId('moderation-submit'))

    expect(page$().text()).toContain(fa.moderation.errors.reasonRequired)
    expect(page$().text()).toContain(fa.moderation.errors.warningTextRequired)
    expect(commands()).toHaveLength(0)

    await type('moderation-warning-text', 'لطفاً در چت محترمانه رفتار کنید.', 'textarea')
    await type('moderation-reason', 'توهین در چت', 'textarea')
    await click(byTestId('moderation-submit'))

    expect(commands()).toEqual([
      expect.objectContaining({
        method: 'POST',
        url: ACTIONS,
        body: { targetUserId: TARGET_ID, action: 'Warn', reason: 'توهین در چت', warningText: 'لطفاً در چت محترمانه رفتار کنید.' },
      }),
    ])
    expect(fileReads()).toHaveLength(2)
    expect(byTestId('moderation-reason').exists() && byTestId('moderation-reason').isVisible()).toBe(false)
  })

  it('suspends until a Jalali last day: seven days by default, a preset, or a day picked', async () => {
    serve()
    await mountFile()

    await openAction('Suspend')
    expect(byTestId('moderation-until-preview').text()).toContain('۱۴۰۵/۰۸/۰۸')

    await click(byTestId('moderation-preset-30').find('input'))
    expect(byTestId('moderation-until-preview').text()).toContain('۱۴۰۵/۰۹/۰۱')

    await choose('moderation-until-day', '۸')
    await choose('moderation-until-month', 'آبان')
    expect(byTestId('moderation-until-preview').text()).toContain('۱۴۰۵/۰۸/۰۸')

    await type('moderation-reason', 'harassment in chat', 'textarea')
    await click(byTestId('moderation-submit'))

    expect(commands()[0]!.body).toEqual({ targetUserId: TARGET_ID, action: 'Suspend', reason: 'harassment in chat', until: '1405/08/08' })
  })

  it('refuses a last day before today', async () => {
    serve()
    await mountFile()

    await openAction('Suspend')
    await choose('moderation-until-month', 'مهر')
    await type('moderation-reason', 'x', 'textarea')
    await click(byTestId('moderation-submit'))

    expect(page$().text()).toContain(fa.moderation.errors.untilPast)
    expect(commands()).toHaveLength(0)
  })

  it('acts on a reported post: hide-post is suggested with its match id and the report linked', async () => {
    serve()
    await mountFile()

    await click(byTestId('report-act-r-post'))

    expect(byTestId('moderation-action').text()).toContain(fa.moderation.actions.HidePost)
    expect((fieldOf('moderation-match-id', 'input').element as HTMLInputElement).value).toBe(MATCH_ID)

    await type('moderation-reason', 'تبلیغ', 'textarea')
    await click(byTestId('moderation-submit'))

    expect(commands()[0]!.body).toEqual({
      targetUserId: TARGET_ID,
      action: 'HidePost',
      reason: 'تبلیغ',
      reportId: 'r-post',
      matchId: MATCH_ID,
    })
  })

  it('deletes a message picked from the reported ones, after refusing an invalid id', async () => {
    serve()
    await mountFile()

    await openAction('DeleteMessage')
    await type('moderation-message-id', 'not-an-id')
    await type('moderation-reason', 'توهین', 'textarea')
    await click(byTestId('moderation-submit'))
    expect(page$().text()).toContain(fa.moderation.errors.messageIdInvalid)

    await click(byTestId(`moderation-message-suggestion-${MESSAGE_ID}`))
    const day = formatDate('2026-10-20T08:00:00Z')
    await choose('moderation-report', `${fa.safety.reasons.Harassment} · ${fa.safety.targetTypes.Message} · بهار احمدی · ${day} · ${fa.safety.reportStatus.Open}`)
    await click(byTestId('moderation-submit'))

    expect(commands()[0]!.body).toEqual({
      targetUserId: TARGET_ID,
      action: 'DeleteMessage',
      reason: 'توهین',
      reportId: 'r-msg',
      messageId: MESSAGE_ID,
    })
  })

  it('switches the dialog to another action', async () => {
    serve()
    await mountFile()

    await openAction('Warn')
    await choose('moderation-action', fa.moderation.actions.RemovePhoto)
    await type('moderation-reason', 'عکس نامناسب', 'textarea')
    await click(byTestId('moderation-submit'))

    expect(commands()[0]!.body).toEqual({ targetUserId: TARGET_ID, action: 'RemovePhoto', reason: 'عکس نامناسب' })
  })

  it('corrects the gender only once one is chosen', async () => {
    serve()
    await mountFile()

    await openAction('CorrectGender')
    await type('moderation-reason', 'اشتباه در ثبت', 'textarea')
    await click(byTestId('moderation-submit'))
    expect(page$().text()).toContain(fa.moderation.errors.genderRequired)

    await click(byTestId('moderation-gender-Female').find('input'))
    await click(byTestId('moderation-submit'))

    expect(commands()[0]!.body).toEqual({ targetUserId: TARGET_ID, action: 'CorrectGender', reason: 'اشتباه در ثبت', gender: 'Female' })
  })

  it('arms the ban only after the acknowledgement and the player’s name typed again', async () => {
    serve()
    await mountFile()

    await openAction('Ban')
    expect(byTestId('moderation-ban-warning').text()).toContain(fa.moderation.ban.warningTitle)
    await type('moderation-reason', 'تهدید مکرر', 'textarea')
    expect(byTestId('moderation-submit').attributes('disabled')).toBeDefined()

    await click(fieldOf('moderation-ban-acknowledge', 'input'))
    await type('moderation-ban-name', 'علی')
    expect(byTestId('moderation-submit').attributes('disabled')).toBeDefined()

    await type('moderation-ban-name', 'علی رضایی')
    expect(byTestId('moderation-submit').attributes('disabled')).toBeUndefined()
    await click(byTestId('moderation-submit'))

    expect(commands()[0]!.body).toEqual({ targetUserId: TARGET_ID, action: 'Ban', reason: 'تهدید مکرر' })
  })

  it('lifts a suspension with a reason', async () => {
    serve({ owner: { status: 'Suspended', suspendedUntil: '2026-10-30T20:30:00Z' } })
    await mountFile()

    await openAction('LiftSuspension')
    await type('moderation-reason', 'اشتباه شد', 'textarea')
    await click(byTestId('moderation-submit'))

    expect(commands()[0]!.body).toEqual({ targetUserId: TARGET_ID, action: 'LiftSuspension', reason: 'اشتباه شد' })
  })

  it('keeps the dialog open with the server’s message when refused', async () => {
    serve({ command: () => ({ status: 404, body: errorEnvelope(404, 'پیام پیدا نشد.', 'MESSAGE_NOT_FOUND') }) })
    await mountFile()

    await click(byTestId('report-act-r-msg'))
    await type('moderation-reason', 'توهین', 'textarea')
    await click(byTestId('moderation-submit'))

    expect(byTestId('moderation-error').text()).toContain('پیام پیدا نشد.')
  })

  it('dismisses an open report with a reason', async () => {
    serve()
    await mountFile()

    await click(byTestId('report-dismiss-r-msg'))
    await type('dismiss-reason', 'شوخی بین دوستان', 'textarea')
    await click(byTestId('dismiss-submit'))

    expect(commands()).toEqual([
      expect.objectContaining({ url: '/api/v1/admin/reports/r-msg/dismiss', body: { reason: 'شوخی بین دوستان' } }),
    ])
    expect(fileReads()).toHaveLength(2)
  })
})
