import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { createMemoryHistory } from 'vue-router'

vi.mock('../../api/auth.api', () => ({
  authApi: { signIn: vi.fn(), signOut: vi.fn(() => Promise.resolve()) },
}))

import { authApi } from '../../api/auth.api'
import { createAppRouter, routes } from '../index'
import { safeRedirect } from '../redirect'
import { MENU } from '../../layouts/menu'
import { tokenStorage } from '../../utils/token-storage'
import { tokens } from '../../utils/__tests__/fakeApi'

const shell = routes.find((r) => r.path === '/')
const pages = (shell?.children ?? []).filter((c) => c.component)

const signInAs = (roles: string[]) => tokenStorage.save(tokens(roles), 'admin@rallyto.ir')
const newRouter = () => createAppRouter(createMemoryHistory())

beforeEach(() => {
  localStorage.clear()
  setActivePinia(createPinia())
  vi.mocked(authApi.signOut).mockClear()
})

describe('router guard', () => {
  it('sends a visitor without a session to the login page, remembering where they were going', async () => {
    const router = newRouter()

    await router.push('/users?page=2')

    expect(router.currentRoute.value.name).toBe('Login')
    expect(router.currentRoute.value.query.redirect).toBe('/users?page=2')
  })

  it.each(pages.map((p) => p.path))('protects /%s', async (path) => {
    const router = newRouter()

    await router.push(`/${path}`)

    expect(router.currentRoute.value.name).toBe('Login')
  })

  it('lets an admin open a panel page', async () => {
    signInAs(['Player', 'Admin'])
    const router = newRouter()

    await router.push('/venues')

    expect(router.currentRoute.value.name).toBe('Venues')
  })

  it('signs out a session without the Admin role and sends it to the login page with the reason', async () => {
    signInAs(['Player'])
    const router = newRouter()

    await router.push('/users')

    expect(router.currentRoute.value.name).toBe('Login')
    expect(router.currentRoute.value.query.denied).toBe('1')
    expect(authApi.signOut).toHaveBeenCalledWith('refresh-1')
    expect(tokenStorage.getAccessToken()).toBeNull()
  })

  it('lets a visitor open the login page', async () => {
    const router = newRouter()

    await router.push('/login')

    expect(router.currentRoute.value.name).toBe('Login')
  })

  it('sends a signed-in admin from the login page to the dashboard', async () => {
    signInAs(['Admin'])
    const router = newRouter()

    await router.push('/login')

    expect(router.currentRoute.value.name).toBe('Dashboard')
  })

  it('opens the dashboard at the root', async () => {
    signInAs(['Admin'])
    const router = newRouter()

    await router.push('/')

    expect(router.currentRoute.value.fullPath).toBe('/dashboard')
  })

  it('opens a reported player’s file under the reports section, and the disputed matches', async () => {
    signInAs(['Admin'])
    const router = newRouter()
    const userId = '11111111-1111-1111-1111-111111111111'

    await router.push(`/reports/targets/${userId}`)
    expect(router.currentRoute.value.name).toBe('ReportTarget')
    expect(router.currentRoute.value.params.userId).toBe(userId)
    expect(router.currentRoute.value.meta.title).toBe('navigation.reports')

    await router.push('/disputed-matches?match=m-1')
    expect(router.currentRoute.value.name).toBe('DisputedMatches')
    expect(router.currentRoute.value.query.match).toBe('m-1')
    expect(router.currentRoute.value.meta.title).toBe('navigation.disputedMatches')
  })

  it('shows the not-found page for an unknown address without asking for a session', async () => {
    const router = newRouter()

    await router.push('/no-such-page')

    expect(router.currentRoute.value.name).toBe('NotFound')
  })
})

describe('admin menu', () => {
  it('has the eight sections, in order', () => {
    expect(MENU.map((m) => m.key)).toEqual([
      'dashboard',
      'users',
      'venues',
      'venue-candidates',
      'sports',
      'reports',
      'disputed-matches',
      'audit-log',
    ])
  })

  it('links only to pages that exist', () => {
    const paths = pages.map((p) => p.path)
    for (const item of MENU) expect(paths).toContain(item.key)
  })
})

describe('safeRedirect', () => {
  it('returns a path inside the panel', () => {
    expect(safeRedirect('/users?page=2')).toBe('/users?page=2')
    expect(safeRedirect(['/sports'])).toBe('/sports')
  })

  it.each([undefined, '', 'https://evil.example', '//evil.example', '/\\evil.example', '/login', 42])(
    'falls back to the dashboard for %s',
    (value) => {
      expect(safeRedirect(value)).toBe('/dashboard')
    },
  )
})
