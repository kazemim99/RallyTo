import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import Antd from 'ant-design-vue'
import { createPinia, setActivePinia } from 'pinia'
import { createAppI18n } from '../../../locales'
import { tokenStorage } from '../../../utils/token-storage'
import { envelope, errorEnvelope, installFakeApi, tokens } from '../../../utils/__tests__/fakeApi'
import { byTestId, click, page$, type } from '../../../utils/__tests__/dom'
import { paged, venue } from '../../../api/__tests__/catalogFixtures'
import VenueProfileDrawer from '../components/VenueProfileDrawer.vue'

const LIST = '/api/v1/admin/venues'

const CLUB = venue({
  id: 'v-1',
  name: 'باشگاه انقلاب',
  tagline: 'شعار قدیمی',
  website: 'https://old.example.ir',
  amenities: ['پارکینگ'],
  images: ['/media/venues/a.jpg', '/media/venues/b.jpg'],
  coverImage: '/media/venues/a.jpg',
})

let api: ReturnType<typeof installFakeApi> | undefined
let wrapper: VueWrapper | undefined

async function mountDrawer(reply?: Parameters<typeof installFakeApi>[0]) {
  api = installFakeApi(reply ?? ((r) => (r.method === 'GET' ? { status: 200, body: envelope(paged([CLUB])) } : { status: 200, body: envelope(CLUB) })))
  const pinia = createPinia()
  setActivePinia(pinia)
  wrapper = mount(VenueProfileDrawer, {
    attachTo: document.body,
    props: { open: true, venue: CLUB },
    global: { plugins: [pinia, createAppI18n(), Antd] },
  })
  await flushPromises()
}

const commands = () => api!.requests.filter((r) => r.method !== 'GET')

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

describe('Venue profile drawer', () => {
  it('shows the current profile and photos, the first photo marked as the cover', async () => {
    await mountDrawer()

    expect((byTestId('profile-tagline').element as HTMLInputElement).value).toBe('شعار قدیمی')
    expect((byTestId('profile-website').element as HTMLInputElement).value).toBe('https://old.example.ir')
    expect(page$().findAll('[data-testid="profile-photo"]')).toHaveLength(2)
    expect(page$().findAll('[data-testid="profile-photo"]')[0]!.text()).toContain('عکس اصلی')
    expect(page$().findAll('[data-testid="profile-photo"]')[1]!.text()).not.toContain('عکس اصلی')
  })

  it('saves edited text, sending blank fields as null', async () => {
    await mountDrawer()

    await type('profile-tagline', 'شعار تازه')
    await type('profile-website', '  ')
    await click(byTestId('profile-submit'))

    expect(commands()).toHaveLength(1)
    expect(commands()[0]).toMatchObject({
      method: 'PUT',
      url: `${LIST}/v-1/profile`,
      body: { tagline: 'شعار تازه', website: null, amenities: ['پارکینگ'] },
    })
  })

  it('shows the server message and stays open when a link is refused', async () => {
    await mountDrawer((r) =>
      r.method === 'PUT'
        ? { status: 400, body: errorEnvelope(400, 'نشانی لینک باید با http یا https شروع شود.', 'INVALID_VENUE_LINK') }
        : { status: 200, body: envelope(paged([CLUB])) },
    )

    await type('profile-website', 'javascript:alert(1)')
    await click(byTestId('profile-submit'))

    expect(byTestId('profile-error').text()).toContain('نشانی لینک باید با http یا https شروع شود.')
    expect(wrapper!.emitted('update:open')).toBeUndefined()
  })

  it('removes a photo at once and shows the remaining ones', async () => {
    await mountDrawer((r) =>
      r.method === 'DELETE'
        ? { status: 200, body: envelope(venue({ id: 'v-1', images: ['/media/venues/b.jpg'], coverImage: '/media/venues/b.jpg' })) }
        : { status: 200, body: envelope(paged([CLUB])) },
    )

    await click(page$().findAll('[data-testid="profile-photo-remove"]')[0]!)

    expect(commands()[0]).toMatchObject({ method: 'DELETE', url: `${LIST}/v-1/images`, params: { path: '/media/venues/a.jpg' } })
    expect(page$().findAll('[data-testid="profile-photo"]')).toHaveLength(1)
    expect(page$().find('[data-testid="profile-photo"]').text()).toContain('عکس اصلی')
  })
})
