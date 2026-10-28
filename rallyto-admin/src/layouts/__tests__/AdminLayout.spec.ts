import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import Antd from 'ant-design-vue'
import { createPinia, setActivePinia } from 'pinia'
import fa from '../../locales/fa.json'
import { createAppI18n } from '../../locales'
import { tokenStorage } from '../../utils/token-storage'
import { tokens } from '../../utils/__tests__/fakeApi'

// The shell with Ant Design compiles on first mount; in a parallel run that alone can pass the default five seconds.
vi.setConfig({ testTimeout: 20_000 })

const push = vi.fn()
const replace = vi.fn()
const route = vi.hoisted(() => ({ path: '/venues' }))
vi.mock('vue-router', () => ({ useRoute: () => route, useRouter: () => ({ push, replace }) }))
vi.mock('../../api/auth.api', () => ({ authApi: { signOut: vi.fn(() => Promise.resolve()) } }))

import AdminLayout from '../AdminLayout.vue'
import { authApi } from '../../api/auth.api'

function mountShell() {
  const pinia = createPinia()
  setActivePinia(pinia)
  return mount(AdminLayout, {
    global: {
      plugins: [pinia, createAppI18n(), Antd],
      stubs: { 'router-view': { template: '<div data-testid="page" />' } },
    },
  })
}

beforeEach(() => {
  localStorage.clear()
  push.mockReset()
  replace.mockReset()
  route.path = '/venues'
  tokenStorage.save(tokens(['Player', 'Admin']), 'admin@rallyto.ir')
})

describe('AdminLayout', () => {
  it('shows the app name «پنل مدیریت رالیتو»', async () => {
    const wrapper = mountShell()
    await flushPromises()

    expect(wrapper.find('[data-testid="app-name"]').text()).toBe('پنل مدیریت رالیتو')
    wrapper.unmount()
  })

  it('lists the eight sections in Persian, in order', async () => {
    const wrapper = mountShell()
    await flushPromises()

    const labels = wrapper.findAll('.ant-menu-item').map((item) => item.text())
    expect(labels).toEqual([
      'داشبورد',
      'کاربران',
      'باشگاه‌ها',
      'صف ورود باشگاه‌ها',
      'ورزش‌ها',
      'گزارش‌های تخلف',
      'بازی‌های مورد اختلاف',
      'گزارش فعالیت ادمین‌ها',
    ])
    expect(labels).toEqual(Object.values(fa.navigation).slice(0, 8))
    wrapper.unmount()
  })

  it('marks the current section and opens another from the menu', async () => {
    const wrapper = mountShell()
    await flushPromises()

    expect(wrapper.find('.ant-menu-item-selected').text()).toBe('باشگاه‌ها')

    const reports = wrapper.findAll('.ant-menu-item').find((item) => item.text() === 'گزارش‌های تخلف')!
    await reports.trigger('click')

    expect(push).toHaveBeenCalledWith('/reports')
    wrapper.unmount()
  })

  it('keeps the reports section selected on a reported player’s file', async () => {
    route.path = '/reports/targets/11111111-1111-1111-1111-111111111111'
    const wrapper = mountShell()
    await flushPromises()

    expect(wrapper.find('.ant-menu-item-selected').text()).toBe('گزارش‌های تخلف')
    wrapper.unmount()
  })

  it('shows the signed-in admin email and signs out to the login page', async () => {
    const wrapper = mountShell()
    await flushPromises()

    expect(wrapper.find('[data-testid="shell-user"]').text()).toContain('admin@rallyto.ir')

    await wrapper.find('[data-testid="sign-out"]').trigger('click')
    await flushPromises()

    expect(authApi.signOut).toHaveBeenCalledWith('refresh-1')
    expect(tokenStorage.getAccessToken()).toBeNull()
    expect(replace).toHaveBeenCalledWith('/login')
    wrapper.unmount()
  })
})
