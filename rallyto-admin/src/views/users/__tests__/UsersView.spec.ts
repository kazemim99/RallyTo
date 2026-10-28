import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { DOMWrapper, flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import Antd from 'ant-design-vue'
import { createPinia, setActivePinia } from 'pinia'
import fa from '../../../locales/fa.json'
import { createAppI18n } from '../../../locales'
import { tokenStorage } from '../../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens, type FakeReply, type RecordedRequest } from '../../../utils/__tests__/fakeApi'
import { account, page } from '../../../api/__tests__/userFixtures'
import { playerProfile } from '../../../api/__tests__/playerFixtures'
import type { AdminAccount } from '../../../api/users.api'
import UsersView from '../UsersView.vue'

// Ant Design's table and modals compile on first mount; in a parallel run that alone can pass five seconds.
vi.setConfig({ testTimeout: 20_000 })

const LIST = '/api/v1/admin/users'

const ROWS: AdminAccount[] = [
  account({ userId: 'u-active', phoneNumber: '+989121234567', roles: ['Player'], createdAt: '2026-10-23T08:00:00Z' }),
  account({
    userId: 'u-suspended',
    phoneNumber: '+989350000001',
    status: 'Suspended',
    suspendedUntil: '2026-10-30T10:30:00Z',
    statusReason: 'توهین در چت بازی',
  }),
  account({ userId: 'u-admin', phoneNumber: '+989120000002', roles: ['Player', 'Admin'] }),
  account({ userId: 'u-banned', phoneNumber: null, status: 'Banned', statusReason: 'کلاهبرداری' }),
]

let api: ReturnType<typeof installFakeApi> | undefined
let wrapper: VueWrapper | undefined

function serve(options: { list?: (r: RecordedRequest) => FakeReply; command?: (r: RecordedRequest) => FakeReply } = {}) {
  const list = options.list ?? (() => ({ status: 200, body: envelope(page(ROWS)) }))
  const command = options.command ?? (() => ({ status: 204 }))
  api = installFakeApi((request) => (request.method === 'GET' && request.url === LIST ? list(request) : command(request)))
}

async function mountUsers() {
  const pinia = createPinia()
  setActivePinia(pinia)
  wrapper = mount(UsersView, { attachTo: document.body, global: { plugins: [pinia, createAppI18n(), Antd] } })
  await flushPromises()
  return wrapper
}

/** Modals and dropdowns render into document.body, outside the component. */
const page$ = () => new DOMWrapper(document.body)
const byTestId = (id: string) => page$().find(`[data-testid="${id}"]`)
const row = (userId: string) => page$().find(`tr[data-row-key="${userId}"]`)
const fieldOf = (id: string, tag: 'input' | 'textarea') => {
  const found = byTestId(id)
  return found.element.tagName === tag.toUpperCase() ? found : found.find(tag)
}
const lists = () => api!.to(LIST).filter((r) => r.method === 'GET')
const lastList = () => lists()[lists().length - 1]!

async function click(target: DOMWrapper<Element>) {
  await target.trigger('click')
  await flushPromises()
}

beforeEach(() => {
  localStorage.clear()
  tokenStorage.save(tokens(['Player', 'Admin']), 'admin@rallyto.ir')
})

afterEach(() => {
  wrapper?.unmount()
  wrapper = undefined
  api?.restore()
  vi.useRealTimers()
  document.body.innerHTML = ''
})

describe('Users: the table', () => {
  it('loads the first page and shows each account', async () => {
    serve()
    await mountUsers()

    expect(lists()[0]!.params).toEqual({ page: 1, pageSize: 20 })

    const active = row('u-active')
    expect(active.find('[data-testid="cell-phone"]').text()).toContain('0912 123 4567')
    expect(active.find('[data-testid="cell-phone"]').attributes('dir')).toBe('ltr')
    expect(active.text()).toContain(fa.users.roles.Player)
    expect(active.find('[data-testid="cell-status"]').text()).toBe(fa.users.status.Active)
    expect(active.text()).toContain('۱۴۰۵/۰۸/۰۱') // created 2026-10-23

    const suspended = row('u-suspended')
    expect(suspended.find('[data-testid="cell-status"]').text()).toBe(fa.users.status.Suspended)
    expect(suspended.find('[data-testid="cell-status"]').classes()).toContain('ant-tag-orange')
    expect(suspended.text()).toContain('۱۴۰۵/۰۸/۰۸ ۱۴:۰۰') // 10:30 UTC is 14:00 in Tehran
    expect(suspended.text()).toContain('توهین در چت بازی')

    expect(row('u-admin').text()).toContain(fa.users.roles.Admin)
    expect(byTestId('users-total').text()).toContain('۴')
  })

  it('offers only the actions that apply to each status', async () => {
    serve()
    await mountUsers()

    const actionsOf = (userId: string) =>
      row(userId)
        .findAll('[data-testid^="action-"]')
        .map((button) => button.attributes('data-testid'))

    expect(actionsOf('u-active')).toEqual(['action-details', 'action-suspend', 'action-ban', 'action-grantAdmin'])
    expect(actionsOf('u-suspended')).toEqual(['action-details', 'action-liftSuspension', 'action-ban'])
    expect(actionsOf('u-admin')).toEqual(['action-details', 'action-suspend', 'action-ban', 'action-revokeAdmin'])
    expect(actionsOf('u-banned')).toEqual(['action-details'])
  })

  it('shows the Persian message when the list cannot be loaded', async () => {
    serve({ list: () => ({ status: 500, body: errorEnvelope(500, 'خطای داخلی سرور.') }) })
    await mountUsers()

    expect(byTestId('users-error').text()).toContain('خطای داخلی سرور.')
  })

  it('asks the server for the next page', async () => {
    serve({ list: () => ({ status: 200, body: envelope(page(ROWS, { totalCount: 45 })) }) })
    await mountUsers()

    await click(page$().find('.ant-pagination-item-2'))

    expect(lastList().params).toEqual({ page: 2, pageSize: 20 })
  })
})

describe('Users: filters', () => {
  it('searches by the digits typed in Persian, from page 1', async () => {
    serve()
    await mountUsers()

    await fieldOf('users-search', 'input').setValue('۰۹۱۲ ۱۲۳')
    await click(page$().find('.ant-input-search-button'))

    expect(lastList().params).toEqual({ search: '0912123', page: 1, pageSize: 20 })
  })

  it('filters by status', async () => {
    serve()
    await mountUsers()

    await page$().find('[data-testid="users-status"] .ant-select-selector').trigger('mousedown')
    await flushPromises()
    await click(page$().find(`.ant-select-item-option[title="${fa.users.status.Suspended}"]`))

    expect(lastList().params).toEqual({ status: 'Suspended', page: 1, pageSize: 20 })
  })
})

describe('Users: suspend', () => {
  beforeEach(() => {
    // Only the clock is faked; promises and Ant Design's own timers stay real.
    vi.useFakeTimers({ toFake: ['Date'] })
    vi.setSystemTime(new Date('2026-10-23T10:00:00Z'))
  })

  it('sends until = now + 7 days in UTC with the reason, then reloads the list', async () => {
    serve()
    await mountUsers()

    await click(row('u-active').find('[data-testid="action-suspend"]'))
    await click(byTestId('duration-7').find('input'))
    await fieldOf('suspend-reason', 'textarea').setValue('توهین به بازیکن دیگر')
    await click(byTestId('suspend-submit'))

    const command = api!.requests.find((r) => r.method === 'POST')!
    expect(command.url).toBe('/api/v1/admin/users/u-active/suspend')
    expect(command.body).toEqual({ until: '2026-10-30T10:00:00.000Z', reason: 'توهین به بازیکن دیگر' })
    expect(lists()).toHaveLength(2)
  })

  it('converts a custom Jalali date on Tehran’s clock to UTC', async () => {
    serve()
    await mountUsers()

    await click(row('u-active').find('[data-testid="action-suspend"]'))
    await click(byTestId('duration-custom').find('input'))
    // The picker starts a day ahead: 1405/08/02 13:30 in Tehran.
    expect(byTestId('suspend-preview').text()).toContain('۱۴۰۵/۰۸/۰۲ ۱۳:۳۰')
    await fieldOf('suspend-reason', 'textarea').setValue('تخلف')
    await click(byTestId('suspend-submit'))

    expect(api!.requests.find((r) => r.method === 'POST')!.body).toEqual({
      until: '2026-10-24T10:00:00.000Z',
      reason: 'تخلف',
    })
  })

  it('requires a reason before sending anything', async () => {
    serve()
    await mountUsers()

    await click(row('u-active').find('[data-testid="action-suspend"]'))
    await click(byTestId('suspend-submit'))

    expect(api!.requests.some((r) => r.method === 'POST')).toBe(false)
    expect(page$().text()).toContain(fa.users.reason.required)
  })

  it('shows the server’s Persian message and stays open when the suspension is refused', async () => {
    serve({ command: () => ({ status: 409, body: errorEnvelope(409, 'این حساب مسدود شده است.', 'ACCOUNT_BANNED') }) })
    await mountUsers()

    await click(row('u-active').find('[data-testid="action-suspend"]'))
    await fieldOf('suspend-reason', 'textarea').setValue('x')
    await click(byTestId('suspend-submit'))

    expect(byTestId('suspend-error').text()).toContain('این حساب مسدود شده است.')
  })
})

describe('Users: ban, lift, and the admin role', () => {
  it('arms the ban only after the permanence is acknowledged', async () => {
    serve()
    await mountUsers()

    await click(row('u-active').find('[data-testid="action-ban"]'))
    expect(byTestId('ban-warning').text()).toContain(fa.users.ban.warningTitle)
    await fieldOf('ban-reason', 'textarea').setValue('کلاهبرداری')
    expect(byTestId('ban-submit').attributes('disabled')).toBeDefined()

    await click(fieldOf('ban-acknowledge', 'input'))
    await click(byTestId('ban-submit'))

    expect(api!.requests.find((r) => r.method === 'POST')).toMatchObject({
      url: '/api/v1/admin/users/u-active/ban',
      body: { reason: 'کلاهبرداری' },
    })
  })

  it('lifts a suspension with a reason', async () => {
    serve()
    await mountUsers()

    await click(row('u-suspended').find('[data-testid="action-liftSuspension"]'))
    await fieldOf('liftSuspension-reason', 'textarea').setValue('اعتراض پذیرفته شد')
    await click(byTestId('liftSuspension-submit'))

    expect(api!.requests.find((r) => r.method === 'POST')).toMatchObject({
      url: '/api/v1/admin/users/u-suspended/lift-suspension',
      body: { reason: 'اعتراض پذیرفته شد' },
    })
  })

  it('grants the admin role after the confirmation', async () => {
    serve()
    await mountUsers()

    await click(row('u-active').find('[data-testid="action-grantAdmin"]'))
    await click(byTestId('grantAdmin-submit'))

    expect(api!.requests.find((r) => r.method === 'POST')!.url).toBe('/api/v1/admin/users/u-active/roles/admin')
  })

  it('shows the LAST_ADMIN message when the last admin’s role cannot be revoked', async () => {
    const lastAdmin = 'نقش مدیر آخرین مدیر سامانه را نمی‌توان گرفت.'
    serve({ command: () => ({ status: 409, body: errorEnvelope(409, lastAdmin, 'LAST_ADMIN') }) })
    await mountUsers()

    await click(row('u-admin').find('[data-testid="action-revokeAdmin"]'))
    await click(byTestId('revokeAdmin-submit'))

    expect(api!.requests.find((r) => r.method === 'DELETE')!.url).toBe('/api/v1/admin/users/u-admin/roles/admin')
    expect(byTestId('revokeAdmin-error').text()).toContain(lastAdmin)
  })
})

describe('Users: details', () => {
  it('opens a drawer with every field, read fresh from the server', async () => {
    serve({
      list: () => ({ status: 200, body: envelope(page(ROWS)) }),
      command: (request) =>
        request.url === '/api/v1/admin/users/u-suspended'
          ? { status: 200, body: envelope(ROWS[1]) }
          : { status: 404, body: errorEnvelope(404, 'یافت نشد') },
    })
    await mountUsers()

    await click(row('u-suspended').find('[data-testid="action-details"]'))

    const details = byTestId('user-details')
    expect(details.text()).toContain('u-suspended')
    expect(details.text()).toContain('0935 000 0001')
    expect(details.text()).toContain('توهین در چت بازی')
    expect(details.text()).toContain('۱۴۰۵/۰۸/۰۸ ۱۴:۰۰')
  })

  it('shows the account’s player profile below the account, or that it has none yet', async () => {
    serve({
      list: () => ({ status: 200, body: envelope(page(ROWS)) }),
      command: (request) => {
        if (request.url === '/api/v1/admin/users/u-active') return { status: 200, body: envelope(ROWS[0]) }
        if (request.url === '/api/v1/admin/users/u-admin') return { status: 200, body: envelope(ROWS[2]) }
        if (request.url === '/api/v1/admin/players/u-active') {
          return { status: 200, body: envelope(playerProfile({ userId: 'u-active', displayName: 'علی رضایی' })) }
        }
        return { status: 404, body: errorEnvelope(404, 'بازیکن پیدا نشد.', 'PLAYER_NOT_FOUND') }
      },
    })
    await mountUsers()

    await click(row('u-active').find('[data-testid="action-details"]'))
    expect(byTestId('player-name').text()).toBe('علی رضایی')

    await click(row('u-admin').find('[data-testid="action-details"]'))
    expect(byTestId('player-no-profile').text()).toContain(fa.users.player.noProfile)
    expect(byTestId('player-name').exists()).toBe(false)
  })
})
