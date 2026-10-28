import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import Antd from 'ant-design-vue'
import { AxiosError, AxiosHeaders } from 'axios'
import { createPinia, setActivePinia } from 'pinia'
import fa from '../../../locales/fa.json'
import { createAppI18n } from '../../../locales'
import { deferred, errorEnvelope, tokens } from '../../../utils/__tests__/fakeApi'

vi.setConfig({ testTimeout: 20_000 })

const replace = vi.fn()
const route = vi.hoisted(() => ({ query: {} as Record<string, string> }))
vi.mock('vue-router', () => ({ useRoute: () => route, useRouter: () => ({ replace, push: vi.fn() }) }))
vi.mock('../../../api/auth.api', () => ({
  authApi: { signIn: vi.fn(), signOut: vi.fn() },
}))

import LoginView from '../LoginView.vue'
import { authApi } from '../../../api/auth.api'
import { ADMIN_ROLE_REQUIRED_MESSAGE } from '../../../stores/auth.store'

const api = vi.mocked(authApi)

/** An HTTP failure carrying an error envelope, as the client hands it to the store. */
const httpError = (status: number, message: string, code?: string) => {
  const config = { headers: new AxiosHeaders() }
  return new AxiosError('Request failed', AxiosError.ERR_BAD_REQUEST, config, {}, {
    status,
    statusText: String(status),
    data: errorEnvelope(status, message, code),
    headers: {},
    config,
  })
}

const INVALID_CREDENTIALS = 'ایمیل یا رمز عبور درست نیست.'
// vue-i18n reads a bare `@` as a linked message, so the locale writes it as {'@'}; the screen shows a plain one.
const EMAIL_INVALID = fa.auth.emailInvalid.replace("{'@'}", '@')

let wrapper: VueWrapper | undefined

function mountLogin() {
  const pinia = createPinia()
  setActivePinia(pinia)
  wrapper = mount(LoginView, { attachTo: document.body, global: { plugins: [pinia, createAppI18n(), Antd] } })
  return wrapper
}

const byTestId = (id: string) => wrapper!.find(`[data-testid="${id}"]`)
const inputOf = (id: string) => {
  const found = byTestId(id)
  return found.element.tagName === 'INPUT' ? found : found.find('input')
}
const valueOf = (id: string) => (inputOf(id).element as HTMLInputElement).value

async function signInWith(email: string, password: string) {
  await inputOf('email-input').setValue(email)
  await inputOf('password-input').setValue(password)
  await byTestId('login-form').trigger('submit')
  await flushPromises()
}

beforeEach(() => {
  localStorage.clear()
  vi.resetAllMocks()
  route.query = {}
  api.signOut.mockResolvedValue(undefined)
})

afterEach(() => {
  wrapper?.unmount()
  wrapper = undefined
  document.body.innerHTML = ''
})

describe('login form', () => {
  it('shows the app name', () => {
    mountLogin()

    expect(byTestId('app-name').text()).toBe('پنل مدیریت رالیتو')
  })

  it('has an email field and a password field that password managers recognise', () => {
    mountLogin()

    const email = inputOf('email-input')
    expect(email.attributes('type')).toBe('email')
    expect(email.attributes('dir')).toBe('ltr')
    expect(email.attributes('autocomplete')).toBe('username')
    expect(email.attributes('placeholder')).toBe('admin@rallyto.ir')

    const password = inputOf('password-input')
    expect(password.attributes('type')).toBe('password')
    expect(password.attributes('autocomplete')).toBe('current-password')
  })

  it('explains why when the guard turned a non-admin session away', () => {
    route.query = { denied: '1' }
    mountLogin()

    expect(byTestId('login-error').text()).toContain(ADMIN_ROLE_REQUIRED_MESSAGE)
  })
})

describe('client validation', () => {
  it('asks for the email and the password when both are empty, and sends nothing', async () => {
    mountLogin()

    await signInWith('   ', '')

    expect(api.signIn).not.toHaveBeenCalled()
    expect(wrapper!.text()).toContain(fa.auth.emailRequired)
    expect(wrapper!.text()).toContain(fa.auth.passwordRequired)
  })

  it.each(['admin', 'admin@', 'admin@rallyto', 'ad min@rallyto.ir'])('refuses the malformed email %s', async (email) => {
    mountLogin()

    await signInWith(email, 'pass-1')

    expect(api.signIn).not.toHaveBeenCalled()
    expect(wrapper!.text()).toContain(EMAIL_INVALID)
  })

  it('asks for the password when only the email is given', async () => {
    mountLogin()

    await signInWith('admin@rallyto.ir', '')

    expect(api.signIn).not.toHaveBeenCalled()
    expect(wrapper!.text()).toContain(fa.auth.passwordRequired)
    expect(wrapper!.text()).not.toContain(fa.auth.emailRequired)
    expect(wrapper!.text()).not.toContain(EMAIL_INVALID)
  })
})

describe('signing in', () => {
  it('sends the trimmed email and the password, then opens the page the admin came from', async () => {
    route.query = { redirect: '/venues' }
    api.signIn.mockResolvedValue(tokens(['Player', 'Admin']))
    mountLogin()

    await signInWith('  admin@rallyto.ir ', 'S3cret pass!')

    expect(api.signIn).toHaveBeenCalledTimes(1)
    expect(api.signIn).toHaveBeenCalledWith('admin@rallyto.ir', 'S3cret pass!')
    expect(localStorage.getItem('ty_admin_token')).toBe('access-1')
    expect(JSON.parse(localStorage.getItem('ty_admin_user')!)).toMatchObject({ email: 'admin@rallyto.ir' })
    expect(replace).toHaveBeenCalledWith('/venues')
  })

  it('opens the dashboard when the redirect points outside the panel', async () => {
    route.query = { redirect: '//evil.example' }
    api.signIn.mockResolvedValue(tokens(['Admin']))
    mountLogin()

    await signInWith('admin@rallyto.ir', 'pass-1')

    expect(replace).toHaveBeenCalledWith('/dashboard')
  })

  it('shows the button as loading while the server answers, and sends one request for repeated submits', async () => {
    const reply = deferred<ReturnType<typeof tokens>>()
    api.signIn.mockReturnValue(reply.promise)
    mountLogin()

    await signInWith('admin@rallyto.ir', 'pass-1')
    expect(byTestId('sign-in').classes()).toContain('ant-btn-loading')
    await byTestId('login-form').trigger('submit')
    await flushPromises()
    expect(api.signIn).toHaveBeenCalledTimes(1)

    reply.resolve(tokens(['Admin']))
    await flushPromises()
    expect(byTestId('sign-in').classes()).not.toContain('ant-btn-loading')
  })

  it('shows the server’s Persian message for wrong credentials, clears the password, and stays on the page', async () => {
    api.signIn.mockRejectedValue(httpError(401, INVALID_CREDENTIALS, 'INVALID_CREDENTIALS'))
    mountLogin()

    await signInWith('admin@rallyto.ir', 'wrong')

    expect(byTestId('login-error').text()).toContain(INVALID_CREDENTIALS)
    expect(valueOf('password-input')).toBe('')
    expect(valueOf('email-input')).toBe('admin@rallyto.ir')
    expect(localStorage.getItem('ty_admin_token')).toBeNull()
    expect(replace).not.toHaveBeenCalled()
  })

  it('shows the server’s Persian message when sign-in is locked after repeated failures', async () => {
    const locked = 'ورود به این حساب به دلیل تلاش‌های ناموفق پی‌درپی موقتاً قفل شده است.'
    api.signIn.mockRejectedValue(httpError(429, locked, 'ADMIN_SIGN_IN_LOCKED'))
    mountLogin()

    await signInWith('admin@rallyto.ir', 'wrong')

    expect(byTestId('login-error').text()).toContain(locked)
    expect(replace).not.toHaveBeenCalled()
  })

  it('turns a non-admin away with the Persian message, stores nothing, and revokes the session', async () => {
    api.signIn.mockResolvedValue(tokens(['Player']))
    mountLogin()

    await signInWith('player@rallyto.ir', 'pass-1')

    expect(byTestId('login-error').text()).toContain(ADMIN_ROLE_REQUIRED_MESSAGE)
    expect(localStorage.getItem('ty_admin_token')).toBeNull()
    expect(localStorage.getItem('ty_admin_user')).toBeNull()
    expect(api.signOut).toHaveBeenCalledWith('refresh-1', 'access-1')
    expect(replace).not.toHaveBeenCalled()
  })

  it('clears the previous error when the admin tries again', async () => {
    api.signIn.mockRejectedValueOnce(httpError(401, INVALID_CREDENTIALS, 'INVALID_CREDENTIALS'))
    api.signIn.mockResolvedValueOnce(tokens(['Admin']))
    mountLogin()

    await signInWith('admin@rallyto.ir', 'wrong')
    await signInWith('admin@rallyto.ir', 'right')

    expect(byTestId('login-error').exists()).toBe(false)
    expect(replace).toHaveBeenCalledWith('/dashboard')
  })
})
