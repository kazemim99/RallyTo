import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import Antd from 'ant-design-vue'
import { createPinia, setActivePinia } from 'pinia'
import fa from '../../../locales/fa.json'
import { createAppI18n } from '../../../locales'
import { tokenStorage } from '../../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens, type FakeReply, type RecordedRequest } from '../../../utils/__tests__/fakeApi'
import { byTestId, choose, click, fieldOf, page$, type } from '../../../utils/__tests__/dom'
import { CITIES, PROVINCES, SPORTS, candidate, paged, venue } from '../../../api/__tests__/catalogFixtures'
import type { VenueCandidate } from '../../../api/venueCandidates.api'
import VenueCandidatesView from '../VenueCandidatesView.vue'

vi.setConfig({ testTimeout: 20_000 })

const LIST = '/api/v1/admin/venue-candidates'
const VENUES = '/api/v1/admin/venues'

const ROWS: VenueCandidate[] = [
  candidate({ id: 'c-1', name: 'پدل کرج', keyword: 'padel' }),
  candidate({ id: 'c-2', name: 'تنیس گوهردشت', address: null, keyword: 'tennis club', importedAt: '2026-10-20T21:00:00Z' }),
  candidate({ id: 'c-3', name: 'باشگاه بدنسازی', keyword: null }),
  candidate({ id: 'c-done', name: 'قبلاً تأییدشده', status: 'Approved', resolvedVenueId: 'v-1' }),
]

let api: ReturnType<typeof installFakeApi> | undefined
let wrapper: VueWrapper | undefined

function serve(command: (r: RecordedRequest) => FakeReply = () => ({ status: 204 })) {
  api = installFakeApi((r) => {
    if (r.method === 'GET') {
      if (r.url === LIST) return { status: 200, body: envelope(paged(ROWS)) }
      if (r.url === VENUES) {
        return {
          status: 200,
          body: envelope(paged([venue({ id: 'v-1', name: 'باشگاه انقلاب' }), venue({ id: 'v-2', name: 'پدل مهرشهر', address: null })])),
        }
      }
      if (r.url === '/api/v1/admin/sports') return { status: 200, body: envelope(SPORTS) }
      if (r.url === '/api/v1/provinces') return { status: 200, body: envelope(PROVINCES) }
      const cities = /^\/api\/v1\/provinces\/(\d+)\/cities$/.exec(r.url)
      if (cities) return { status: 200, body: envelope(CITIES[Number(cities[1])] ?? []) }
    }
    return command(r)
  })
}

async function mountCandidates() {
  const pinia = createPinia()
  setActivePinia(pinia)
  wrapper = mount(VenueCandidatesView, { attachTo: document.body, global: { plugins: [pinia, createAppI18n(), Antd] } })
  await flushPromises()
  return wrapper
}

const row = (id: string) => page$().find(`tr[data-row-key="${id}"]`)
const commands = () => api!.requests.filter((r) => r.method !== 'GET')
const lists = () => api!.requests.filter((r) => r.method === 'GET' && r.url === LIST)

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

describe('Candidates: the queue', () => {
  it('opens on the Pending queue and shows name, address, keyword, Jalali import date and status', async () => {
    serve()
    await mountCandidates()

    expect(lists()[0]!.params).toEqual({ status: 'Pending', page: 1, pageSize: 20 })
    const first = row('c-1')
    expect(first.text()).toContain('پدل کرج')
    expect(first.text()).toContain('کرج، گوهردشت')
    expect(first.text()).toContain('padel')
    expect(first.find('[data-testid="cell-imported"]').text()).toContain('۱۴۰۵/۰۸/۰۱')
    expect(first.find('[data-testid="cell-status"]').text()).toBe(fa.candidates.status.Pending)
    // 21:00 UTC on the 20th is past midnight in Tehran.
    expect(row('c-2').find('[data-testid="cell-imported"]').text()).toContain('۱۴۰۵/۰۷/۲۹')
    expect(row('c-done').find('[data-testid="action-approve"]').exists()).toBe(false)
    expect(byTestId('candidates-hint').text()).toContain(fa.catalog.sportsEditor.laterHint)
  })

  it('filters by province, city, status and keyword', async () => {
    serve()
    await mountCandidates()

    await choose('candidates-location-province', 'البرز')
    await choose('candidates-location-city', 'کرج')
    await choose('candidates-status', fa.candidates.status.Rejected)
    await type('candidates-keyword', 'padel')
    await click(page$().find('.ant-input-search-button'))

    expect(lists().slice(-1)[0]!.params).toEqual({ provinceId: 5, cityId: 51, status: 'Rejected', keyword: 'padel', page: 1, pageSize: 20 })
  })
})

describe('Candidates: bulk approve', () => {
  it('sends the selected ids with the same sports for all, then reloads', async () => {
    serve()
    await mountCandidates()
    expect(byTestId('candidates-bulk').attributes('disabled')).toBeDefined()
    // A reviewed candidate cannot be selected.
    expect(row('c-done').find('.ant-checkbox-input').attributes('disabled')).toBeDefined()

    await click(row('c-1').find('.ant-checkbox-input'))
    await click(row('c-3').find('.ant-checkbox-input'))
    await click(byTestId('candidates-bulk'))

    expect(byTestId('bulk-names').text()).toContain('پدل کرج')
    expect(byTestId('bulk-hint').text()).toContain(fa.catalog.sportsEditor.laterHint)
    await click(fieldOf('sport-toggle-padel', 'input'))
    await type('sport-courts-padel', '2')
    await click(byTestId('bulk-submit'))

    expect(commands()).toHaveLength(1)
    expect(commands()[0]).toMatchObject({ method: 'POST', url: `${LIST}/bulk-approve` })
    expect(commands()[0]!.body).toEqual({
      candidateIds: ['c-1', 'c-3'],
      sports: [{ sportCode: 'padel', courtCount: 2, setting: 'Outdoor', surface: null, hasLighting: false }],
    })
    expect(lists()).toHaveLength(2)
  })

  it('asks for at least one sport before sending', async () => {
    serve()
    await mountCandidates()

    await click(row('c-1').find('.ant-checkbox-input'))
    await click(byTestId('candidates-bulk'))
    await click(byTestId('bulk-submit'))

    expect(commands()).toHaveLength(0)
    expect(page$().text()).toContain(fa.catalog.sportsEditor.required)
  })
})

describe('Candidates: approve, merge, reject', () => {
  it('approves from a drawer prefilled with the candidate, with the chosen sports', async () => {
    serve(() => ({ status: 200, body: envelope(venue({ id: 'v-new' })) }))
    await mountCandidates()

    await click(row('c-1').find('[data-testid="action-approve"]'))
    expect((fieldOf('venue-name', 'input').element as HTMLInputElement).value).toBe('پدل کرج')
    expect(byTestId('approve-hint').text()).toContain(fa.catalog.sportsEditor.laterHint)
    await click(fieldOf('sport-toggle-padel', 'input'))
    await click(byTestId('approve-submit'))

    expect(commands()[0]).toMatchObject({ method: 'POST', url: `${LIST}/c-1/approve` })
    expect(commands()[0]!.body).toEqual({
      name: 'پدل کرج',
      address: 'کرج، گوهردشت',
      phone: null,
      latitude: 35.8,
      longitude: 50.95,
      sports: [{ sportCode: 'padel', courtCount: null, setting: 'Outdoor', surface: null, hasLighting: false }],
    })
  })

  it('merges into a club picked among the clubs of the same city', async () => {
    serve()
    await mountCandidates()

    await click(row('c-1').find('[data-testid="action-merge"]'))
    const lookup = api!.requests.find((r) => r.url === VENUES)!
    expect(lookup.params).toEqual({ cityId: 51, page: 1, pageSize: 100 })

    await click(byTestId('merge-submit'))
    expect(commands()).toHaveLength(0)
    expect(page$().text()).toContain(fa.candidates.merge.venueRequired)

    await choose('merge-venue', 'پدل مهرشهر')
    await click(byTestId('merge-submit'))

    expect(commands()[0]).toMatchObject({ method: 'POST', url: `${LIST}/c-1/merge`, body: { venueId: 'v-2' } })
  })

  it('rejects only with a reason', async () => {
    serve()
    await mountCandidates()

    await click(row('c-3').find('[data-testid="action-reject"]'))
    await click(byTestId('reject-submit'))
    expect(commands()).toHaveLength(0)
    expect(page$().text()).toContain(fa.candidates.reject.reasonRequired)

    await type('reject-reason', '  باشگاه بدنسازی است  ', 'textarea')
    await click(byTestId('reject-submit'))

    expect(commands()[0]).toMatchObject({
      method: 'POST',
      url: `${LIST}/c-3/reject`,
      body: { reason: 'باشگاه بدنسازی است' },
    })
  })

  it('shows CANDIDATE_ALREADY_REVIEWED in the dialog and reloads the queue', async () => {
    const text = 'این مورد قبلاً بررسی شده است.'
    serve(() => ({ status: 409, body: errorEnvelope(409, text, 'CANDIDATE_ALREADY_REVIEWED') }))
    await mountCandidates()

    await click(row('c-3').find('[data-testid="action-reject"]'))
    await type('reject-reason', 'تکراری', 'textarea')
    await click(byTestId('reject-submit'))

    expect(byTestId('reject-error').text()).toContain(text)
    expect(lists()).toHaveLength(2)
  })
})
