import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import Antd from 'ant-design-vue'
import { createPinia, setActivePinia } from 'pinia'
import fa from '../../../locales/fa.json'
import { createAppI18n } from '../../../locales'
import { tokenStorage } from '../../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens, type FakeReply, type RecordedRequest } from '../../../utils/__tests__/fakeApi'
import { byTestId, choose, click, fieldOf, page$, type, wait } from '../../../utils/__tests__/dom'
import { CITIES, PROVINCES, SPORTS, paged, venue, venueSport } from '../../../api/__tests__/catalogFixtures'
import { SIMILAR_LOOKUP_DELAY_MS } from '../../../components/catalog/venueForm'
import type { Venue } from '../../../api/venues.api'
import VenuesView from '../VenuesView.vue'

vi.setConfig({ testTimeout: 20_000 })

const LIST = '/api/v1/admin/venues'
const SIMILAR = `${LIST}/similar`

const ROWS: Venue[] = [
  venue({ id: 'v-google', name: 'پدل کرج', googlePlaceId: 'ChIJ-9', sports: [venueSport({ sportCode: 'padel', courtCount: 3, surface: 'Glass' })] }),
  venue({ id: 'v-hidden', name: 'تنیس قدیمی', status: 'Hidden', sports: [venueSport({ courtCount: null })] }),
]

let api: ReturnType<typeof installFakeApi> | undefined
let wrapper: VueWrapper | undefined

interface Replies {
  similar?: (r: RecordedRequest) => FakeReply
  command?: (r: RecordedRequest) => FakeReply
}

function serve(replies: Replies = {}) {
  api = installFakeApi((r) => {
    if (r.method === 'GET') {
      if (r.url === LIST) return { status: 200, body: envelope(paged(ROWS)) }
      if (r.url === SIMILAR) return replies.similar?.(r) ?? { status: 200, body: envelope([]) }
      if (r.url === '/api/v1/admin/sports') return { status: 200, body: envelope(SPORTS) }
      if (r.url === '/api/v1/provinces') return { status: 200, body: envelope(PROVINCES) }
      const cities = /^\/api\/v1\/provinces\/(\d+)\/cities$/.exec(r.url)
      if (cities) return { status: 200, body: envelope(CITIES[Number(cities[1])] ?? []) }
    }
    return replies.command?.(r) ?? { status: 200, body: envelope(venue()) }
  })
}

async function mountVenues() {
  const pinia = createPinia()
  setActivePinia(pinia)
  wrapper = mount(VenuesView, { attachTo: document.body, global: { plugins: [pinia, createAppI18n(), Antd] } })
  await flushPromises()
  return wrapper
}

const row = (id: string) => page$().find(`tr[data-row-key="${id}"]`)
const commands = () => api!.requests.filter((r) => r.method !== 'GET')
const lists = () => api!.requests.filter((r) => r.method === 'GET' && r.url === LIST)
const similarLookups = () => api!.requests.filter((r) => r.url === SIMILAR)

/** Opens the create drawer, picks Karaj, names the club and ticks padel. */
async function fillNewVenue(name: string) {
  await click(byTestId('venues-add'))
  await choose('venue-location-province', 'البرز')
  await choose('venue-location-city', 'کرج')
  await type('venue-name', name)
  await click(fieldOf('sport-toggle-padel', 'input'))
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

describe('Venues: the table and filters', () => {
  it('shows each club with its city, sports and court counts, status, and a Google badge for imported ones', async () => {
    serve()
    await mountVenues()

    const google = row('v-google')
    expect(google.find('[data-testid="cell-google"]').text()).toContain(fa.venues.google)
    expect(google.text()).toContain('کرج')
    expect(google.find('[data-testid="cell-sport"]').text()).toContain('پدل')
    expect(google.find('[data-testid="cell-sport"]').text()).toContain('۳ زمین')
    expect(google.find('[data-testid="cell-status"]').text()).toBe(fa.venues.status.Active)
    expect(google.find('[data-testid="action-hide"]').exists()).toBe(true)

    const hidden = row('v-hidden')
    expect(hidden.find('[data-testid="cell-google"]').exists()).toBe(false)
    expect(hidden.find('[data-testid="cell-sport"]').text()).toBe('تنیس')
    expect(hidden.find('[data-testid="cell-status"]').text()).toBe(fa.venues.status.Hidden)
    expect(hidden.find('[data-testid="action-unhide"]').exists()).toBe(true)
  })

  it('filters by the city chosen under its province, and by status', async () => {
    serve()
    await mountVenues()

    await choose('venues-location-province', 'البرز')
    await choose('venues-location-city', 'کرج')
    expect(lists().slice(-1)[0]!.params).toEqual({ cityId: 51, page: 1, pageSize: 20 })

    await choose('venues-status', fa.venues.status.Hidden)
    expect(lists().slice(-1)[0]!.params).toEqual({ cityId: 51, status: 'Hidden', page: 1, pageSize: 20 })
  })
})

describe('Venues: duplicate names', () => {
  it('looks up similar names once the typing pauses, and lists the matches as a warning', async () => {
    serve({ similar: () => ({ status: 200, body: envelope([venue({ id: 'v-old', name: 'باشگاه پدل آزادی کرج' })]) }) })
    await mountVenues()
    await click(byTestId('venues-add'))
    await choose('venue-location-province', 'البرز')
    await choose('venue-location-city', 'کرج')

    await type('venue-name', 'پ')
    await type('venue-name', 'پدل')
    await type('venue-name', 'پدل آزادی')
    expect(similarLookups()).toHaveLength(0)

    await wait(SIMILAR_LOOKUP_DELAY_MS + 150)
    await flushPromises()

    expect(similarLookups()).toHaveLength(1)
    expect(similarLookups()[0]!.params).toEqual({ cityId: 51, name: 'پدل آزادی' })
    expect(byTestId('venue-similar').text()).toContain('باشگاه پدل آزادی کرج')
  })

  it('on SIMILAR_VENUE_EXISTS shows the matches, and "save anyway" resends with allowSimilar', async () => {
    const refusal = 'باشگاهی با نام مشابه در این شهر وجود دارد. اگر باشگاه دیگری است، دوباره تأیید کنید.'
    serve({
      similar: () => ({ status: 200, body: envelope([venue({ id: 'v-old', name: 'پدل آزادی', address: 'کرج، عظیمیه' })]) }),
      command: (r) =>
        (r.body as { allowSimilar?: boolean }).allowSimilar
          ? { status: 200, body: envelope(venue({ id: 'v-new' })) }
          : { status: 409, body: errorEnvelope(409, refusal, 'SIMILAR_VENUE_EXISTS') },
    })
    await mountVenues()
    await fillNewVenue('پدل آزادی ۲')
    await type('venue-phone', '۰۲۶۳۲۱۱۱۲۲۲')

    await click(byTestId('venue-submit'))

    expect(commands()).toHaveLength(1)
    expect(commands()[0]!.body).toEqual({
      cityId: 51,
      name: 'پدل آزادی ۲',
      address: null,
      phone: '02632111222',
      latitude: null,
      longitude: null,
      sports: [{ sportCode: 'padel', courtCount: null, setting: 'Outdoor', surface: null, hasLighting: false }],
      allowSimilar: false,
    })
    const conflict = byTestId('venue-similar-conflict')
    expect(conflict.text()).toContain(refusal)
    expect(conflict.text()).toContain('پدل آزادی')
    expect(conflict.text()).toContain('کرج، عظیمیه')

    await click(byTestId('venue-save-anyway'))

    expect(commands()).toHaveLength(2)
    expect(commands()[1]!.body).toMatchObject({ name: 'پدل آزادی ۲', allowSimilar: true })
    expect(page$().find('[data-testid="venue-similar-conflict"]').exists()).toBe(false)
  })

  it('requires the city, the name and a sport before sending', async () => {
    serve()
    await mountVenues()

    await click(byTestId('venues-add'))
    await click(byTestId('venue-submit'))

    expect(commands()).toHaveLength(0)
    const text = page$().text()
    expect(text).toContain(fa.venues.form.cityRequired)
    expect(text).toContain(fa.venues.form.nameRequired)
    expect(text).toContain(fa.catalog.sportsEditor.required)
  })
})

describe('Venues: edit, hide and unhide', () => {
  it('edits with PUT, keeping the city fixed', async () => {
    serve()
    await mountVenues()

    await click(row('v-google').find('[data-testid="action-edit"]'))
    expect((fieldOf('venue-city-fixed', 'input').element as HTMLInputElement).value).toBe('کرج')
    await type('venue-name', 'پدل کرج (شعبه ۱)')
    await click(byTestId('venue-submit'))

    expect(commands()[0]).toMatchObject({ method: 'PUT', url: `${LIST}/v-google` })
    expect(commands()[0]!.body).toMatchObject({
      cityId: 51,
      name: 'پدل کرج (شعبه ۱)',
      sports: [{ sportCode: 'padel', courtCount: 3, setting: 'Outdoor', surface: 'Glass', hasLighting: true }],
    })
    expect(commands()[0]!.body).not.toHaveProperty('allowSimilar')
  })

  it('hides after the confirmation, then reloads', async () => {
    serve({ command: () => ({ status: 204 }) })
    await mountVenues()

    await click(row('v-google').find('[data-testid="action-hide"]'))
    expect(commands()).toHaveLength(0)
    await click(byTestId('hide-submit'))

    expect(commands().map((r) => `${r.method} ${r.url}`)).toEqual([`POST ${LIST}/v-google/hide`])
    expect(lists()).toHaveLength(2)
  })

  it('unhides after the confirmation', async () => {
    serve({ command: () => ({ status: 204 }) })
    await mountVenues()

    await click(row('v-hidden').find('[data-testid="action-unhide"]'))
    await click(byTestId('unhide-submit'))

    expect(commands().map((r) => r.url)).toEqual([`${LIST}/v-hidden/unhide`])
  })
})
