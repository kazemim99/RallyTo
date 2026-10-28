import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { DOMWrapper, flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import Antd from 'ant-design-vue'
import { createPinia, setActivePinia } from 'pinia'
import fa from '../../../locales/fa.json'
import { createAppI18n } from '../../../locales'
import { tokenStorage } from '../../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens, type FakeReply, type RecordedRequest } from '../../../utils/__tests__/fakeApi'
import { playerProfile, playerSport } from '../../../api/__tests__/playerFixtures'
import { SPORTS } from '../../../api/__tests__/catalogFixtures'
import PlayerProfileSection from '../components/PlayerProfileSection.vue'

// Ant Design's modals compile on first mount; in a parallel run that alone can pass five seconds.
vi.setConfig({ testTimeout: 20_000 })

const PLAYER = '/api/v1/admin/players/u-1'
const SPORTS_LIST = '/api/v1/admin/sports'

let api: ReturnType<typeof installFakeApi> | undefined
let wrapper: VueWrapper | undefined

/** Plays the server: the profile answers `read`, the sport catalog is served, commands answer `command`. */
function serve(options: { read?: (r: RecordedRequest) => FakeReply; command?: (r: RecordedRequest) => FakeReply } = {}) {
  const read = options.read ?? (() => ({ status: 200, body: envelope(playerProfile()) }))
  const command = options.command ?? (() => ({ status: 204 }))
  api = installFakeApi((request) => {
    if (request.method === 'GET' && request.url === SPORTS_LIST) return { status: 200, body: envelope(SPORTS) }
    if (request.method === 'GET') return read(request)
    return command(request)
  })
}

async function mountSection(userId = 'u-1') {
  const pinia = createPinia()
  setActivePinia(pinia)
  wrapper = mount(PlayerProfileSection, {
    props: { userId },
    attachTo: document.body,
    global: { plugins: [pinia, createAppI18n(), Antd] },
  })
  await flushPromises()
  return wrapper
}

/** Modals render into document.body, outside the component. */
const page$ = () => new DOMWrapper(document.body)
const byTestId = (id: string) => page$().find(`[data-testid="${id}"]`)
const textareaOf = (id: string) => {
  const found = byTestId(id)
  return found.element.tagName === 'TEXTAREA' ? found : found.find('textarea')
}
const commands = () => api!.requests.filter((r) => r.method !== 'GET')
const profileReads = () => api!.to(PLAYER).filter((r) => r.method === 'GET')

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
  document.body.innerHTML = ''
})

describe('Player profile section: the profile', () => {
  it('shows every field in Persian, with each sport’s level and experience', async () => {
    serve({
      read: () => ({
        status: 200,
        body: envelope(
          playerProfile({
            sports: [
              playerSport(),
              playerSport({
                sportId: 's-padel',
                sportCode: 'padel',
                level: 'Beginner',
                levelName: 'مبتدی',
                experience: 'UnderSixMonths',
                goals: ['RallyPractice'],
              }),
            ],
          }),
        ),
      }),
    })
    await mountSection()

    expect(profileReads()).toHaveLength(1)
    expect(byTestId('player-name').text()).toBe('سارا محمدی')
    expect(byTestId('player-photo').find('img').attributes('src')).toMatch(/\/media\/avatars\/u-1\.jpg$/)
    expect(byTestId('player-gender').text()).toBe(fa.users.player.gender.Female)
    expect(byTestId('player-birth-date').text()).toBe('۱۳۷۵/۰۵/۱۰')
    expect(byTestId('player-age-range').text()).toBe('۲۵ تا ۳۴ سال')
    expect(byTestId('player-city').text()).toBe('تهران')
    expect(byTestId('player-bio').text()).toBe('عصرها در باشگاه انقلاب بازی می‌کنم.')
    expect(byTestId('player-visibility').text()).toBe(fa.users.player.visibility.SameGender)
    expect(byTestId('player-status').text()).toBe(fa.users.player.status.Active)
    expect(byTestId('player-venue').text()).toBe('باشگاه انقلاب')

    const tennis = byTestId('player-sport-tennis')
    expect(tennis.text()).toContain('تنیس') // the catalog's Persian name
    expect(tennis.find('[data-testid="sport-level"]').text()).toBe('متوسط')
    expect(tennis.find('[data-testid="sport-experience"]').text()).toBe(fa.users.player.experienceBands.OneToThreeYears)
    expect(tennis.text()).toContain(fa.catalog.formats.Doubles)
    expect(tennis.text()).toContain(fa.users.player.goalNames.Fitness)

    const padel = byTestId('player-sport-padel')
    expect(padel.text()).toContain('پدل')
    expect(padel.find('[data-testid="sport-level"]').text()).toBe('مبتدی')
    expect(padel.find('[data-testid="sport-experience"]').text()).toBe(fa.users.player.experienceBands.UnderSixMonths)
  })

  it('says the user has no profile yet on 404 PLAYER_NOT_FOUND, and offers no actions', async () => {
    serve({ read: () => ({ status: 404, body: errorEnvelope(404, 'بازیکن پیدا نشد.', 'PLAYER_NOT_FOUND') }) })
    await mountSection()

    expect(byTestId('player-no-profile').text()).toContain('این کاربر هنوز پروفایل نساخته است')
    expect(byTestId('player-error').exists()).toBe(false)
    expect(byTestId('action-correctGender').exists()).toBe(false)
  })

  it('shows the server’s Persian message when the profile cannot be read', async () => {
    serve({ read: () => ({ status: 500, body: errorEnvelope(500, 'خطای داخلی سرور.') }) })
    await mountSection()

    expect(byTestId('player-error').text()).toContain('خطای داخلی سرور.')
  })

  it('offers photo removal only when there is a photo', async () => {
    serve({ read: () => ({ status: 200, body: envelope(playerProfile({ photoUrl: null })) }) })
    await mountSection()

    expect(byTestId('action-correctGender').exists()).toBe(true)
    expect(byTestId('action-removePhoto').exists()).toBe(false)
  })
})

describe('Player profile section: correcting the gender', () => {
  it('warns that the player is notified and requires a reason before sending anything', async () => {
    serve()
    await mountSection()

    await click(byTestId('action-correctGender'))
    expect(byTestId('gender-warning').text()).toContain(fa.users.player.correctGender.warning)
    await click(byTestId('gender-submit'))

    expect(commands()).toHaveLength(0)
    expect(page$().text()).toContain(fa.users.reason.required)
  })

  it('sends { gender, reason } with the other gender, then reads the profile again', async () => {
    serve()
    await mountSection()

    await click(byTestId('action-correctGender'))
    expect(byTestId('gender-Female').find('input').attributes('disabled')).toBeDefined()
    await textareaOf('gender-reason').setValue('در ثبت‌نام اشتباه انتخاب شده بود')
    await click(byTestId('gender-submit'))

    expect(commands()).toEqual([
      expect.objectContaining({
        method: 'POST',
        url: '/api/v1/admin/players/u-1/gender',
        body: { gender: 'Male', reason: 'در ثبت‌نام اشتباه انتخاب شده بود' },
      }),
    ])
    expect(profileReads()).toHaveLength(2)
  })

  it('shows the server’s Persian message and stays open when the correction is refused', async () => {
    serve({ command: () => ({ status: 400, body: errorEnvelope(400, 'دلیل را بنویسید.', 'REASON_REQUIRED') }) })
    await mountSection()

    await click(byTestId('action-correctGender'))
    await textareaOf('gender-reason').setValue('x')
    await click(byTestId('gender-submit'))

    expect(byTestId('gender-error').text()).toContain('دلیل را بنویسید.')
  })
})

describe('Player profile section: removing the photo', () => {
  it('requires a reason, then sends it in the DELETE body and reads the profile again', async () => {
    serve()
    await mountSection()

    await click(byTestId('action-removePhoto'))
    await click(byTestId('photo-submit'))
    expect(commands()).toHaveLength(0)

    await textareaOf('photo-reason').setValue('عکس نامناسب')
    await click(byTestId('photo-submit'))

    expect(commands()).toEqual([
      expect.objectContaining({ method: 'DELETE', url: '/api/v1/admin/players/u-1/photo', body: { reason: 'عکس نامناسب' } }),
    ])
    expect(profileReads()).toHaveLength(2)
  })
})
