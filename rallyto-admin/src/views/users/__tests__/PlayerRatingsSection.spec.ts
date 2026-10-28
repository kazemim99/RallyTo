import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import Antd from 'ant-design-vue'
import { createPinia, setActivePinia } from 'pinia'
import fa from '../../../locales/fa.json'
import { createAppI18n } from '../../../locales'
import { tokenStorage } from '../../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens, type FakeReply, type RecordedRequest } from '../../../utils/__tests__/fakeApi'
import { byTestId, click, page$, type } from '../../../utils/__tests__/dom'
import { account } from '../../../api/__tests__/userFixtures'
import { playerProfile } from '../../../api/__tests__/playerFixtures'
import { SPORTS } from '../../../api/__tests__/catalogFixtures'
import { TARGET_ID, adminRating } from '../../../api/__tests__/safetyFixtures'
import PlayerRatingsSection from '../components/PlayerRatingsSection.vue'
import UserDetailDrawer from '../components/UserDetailDrawer.vue'

vi.setConfig({ testTimeout: 20_000 })

const RATINGS = `/api/v1/admin/players/${TARGET_ID}/ratings`

const LIST = [
  adminRating({ id: 'rt-1', stars: 1, tags: ['OnTime', 'FairCalls'], levelAccuracy: 'Higher', privateNote: 'بعد از اختلاف امتیاز بد داد.' }),
  adminRating({ id: 'rt-2', stars: 5, tags: [], levelAccuracy: 'AboutRight', privateNote: null, revealed: false, raterName: 'سارا محمدی' }),
  adminRating({ id: 'rt-3', stars: 2, removedAt: '2026-10-22T10:00:00Z', removalReason: 'انتقام بعد از اختلاف' }),
]

let api: ReturnType<typeof installFakeApi> | undefined
let wrapper: VueWrapper | undefined

function serve(options: { list?: (r: RecordedRequest) => FakeReply; command?: (r: RecordedRequest) => FakeReply } = {}) {
  const list = options.list ?? (() => ({ status: 200, body: envelope(LIST) }))
  const command = options.command ?? (() => ({ status: 204 }))
  api = installFakeApi((request) => {
    if (request.method === 'GET' && request.url === RATINGS) return list(request)
    if (request.method === 'GET' && request.url === `/api/v1/admin/users/${TARGET_ID}`) return { status: 200, body: envelope(account({ userId: TARGET_ID })) }
    if (request.method === 'GET' && request.url === `/api/v1/admin/players/${TARGET_ID}`) return { status: 200, body: envelope(playerProfile({ userId: TARGET_ID })) }
    if (request.method === 'GET' && request.url === '/api/v1/admin/sports') return { status: 200, body: envelope(SPORTS) }
    return command(request)
  })
}

async function mountSection() {
  const pinia = createPinia()
  setActivePinia(pinia)
  wrapper = mount(PlayerRatingsSection, {
    props: { userId: TARGET_ID },
    attachTo: document.body,
    global: { plugins: [pinia, createAppI18n(), Antd] },
  })
  await flushPromises()
  return wrapper
}

const reads = () => api!.to(RATINGS).filter((r) => r.method === 'GET')

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

describe('Player ratings: the list', () => {
  it('shows each rating with rater, stars, tags, level accuracy, private note, revealed flag and removal', async () => {
    serve()
    await mountSection()

    expect(reads()).toHaveLength(1)
    expect(byTestId('ratings-summary').text()).toBe('۳ امتیاز، ۱ حذف‌شده')

    const abusive = byTestId('rating-rt-1')
    expect(abusive.find('[data-testid="rating-rater"]').text()).toBe('بهار احمدی')
    expect(abusive.find('[data-testid="rating-stars"]').text()).toBe('۱ از ۵')
    expect(abusive.find('[data-testid="rating-tags"]').text()).toContain(fa.ratings.tags.OnTime)
    expect(abusive.find('[data-testid="rating-tags"]').text()).toContain(fa.ratings.tags.FairCalls)
    expect(abusive.find('[data-testid="rating-level"]').text()).toBe(fa.ratings.levels.Higher)
    expect(abusive.find('[data-testid="rating-note"]').text()).toBe('بعد از اختلاف امتیاز بد داد.')
    expect(abusive.find('[data-testid="rating-revealed"]').text()).toBe(fa.ratings.revealed)
    expect(abusive.find('[data-testid="rating-remove-rt-1"]').exists()).toBe(true)

    const hidden = byTestId('rating-rt-2')
    expect(hidden.find('[data-testid="rating-revealed"]').text()).toBe(fa.ratings.hidden)
    expect(hidden.find('[data-testid="rating-tags"]').text()).toBe(fa.ratings.noTags)
    expect(hidden.find('[data-testid="rating-note"]').text()).toBe(fa.ratings.noNote)

    const removed = byTestId('rating-rt-3')
    expect(removed.find('[data-testid="rating-removed"]').text()).toBe(fa.ratings.removed)
    expect(removed.find('[data-testid="rating-removal-reason"]').text()).toBe('انتقام بعد از اختلاف')
    expect(removed.find('[data-testid="rating-remove-rt-3"]').exists()).toBe(false)
  })

  it('says so when there are none, and shows a failed read', async () => {
    serve({ list: () => ({ status: 200, body: envelope([]) }) })
    await mountSection()
    expect(byTestId('ratings-empty').text()).toContain(fa.ratings.empty)

    wrapper!.unmount()
    serve({ list: () => ({ status: 500, body: errorEnvelope(500, 'خطای سرور.') }) })
    await mountSection()
    expect(byTestId('ratings-error').text()).toContain('خطای سرور.')
  })
})

describe('Player ratings: removing one', () => {
  it('requires a reason, then sends a DELETE with { reason } and re-reads the list', async () => {
    serve()
    await mountSection()

    await click(byTestId('rating-remove-rt-1'))
    await click(byTestId('rating-remove-submit'))
    expect(page$().text()).toContain(fa.moderation.errors.reasonRequired)
    expect(api!.requests.filter((r) => r.method === 'DELETE')).toHaveLength(0)

    await type('rating-remove-reason', ' انتقام بعد از اختلاف ', 'textarea')
    await click(byTestId('rating-remove-submit'))

    expect(api!.requests.filter((r) => r.method === 'DELETE')).toEqual([
      expect.objectContaining({ url: '/api/v1/admin/ratings/rt-1', body: { reason: 'انتقام بعد از اختلاف' } }),
    ])
    expect(reads()).toHaveLength(2)
  })

  it('keeps the dialog open with the server’s message when refused', async () => {
    serve({ command: () => ({ status: 404, body: errorEnvelope(404, 'امتیاز پیدا نشد.', 'RATING_NOT_FOUND') }) })
    await mountSection()

    await click(byTestId('rating-remove-rt-1'))
    await type('rating-remove-reason', 'x', 'textarea')
    await click(byTestId('rating-remove-submit'))

    expect(byTestId('rating-remove-error').text()).toContain('امتیاز پیدا نشد.')
  })
})

describe('User detail drawer: the ratings tab', () => {
  it('reads the ratings only when the tab is opened', async () => {
    serve()
    const pinia = createPinia()
    setActivePinia(pinia)
    wrapper = mount(UserDetailDrawer, {
      props: { open: true, userId: TARGET_ID },
      attachTo: document.body,
      global: { plugins: [pinia, createAppI18n(), Antd] },
    })
    await flushPromises()

    expect(byTestId('user-details').exists()).toBe(true)
    expect(reads()).toHaveLength(0)

    await click(byTestId('user-tab-ratings'))

    expect(reads()).toHaveLength(1)
    expect(byTestId('rating-rt-1').exists()).toBe(true)
  })
})
