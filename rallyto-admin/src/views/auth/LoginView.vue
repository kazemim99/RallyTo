<template>
  <div class="login-page">
    <a-card class="login-card" :bordered="false">
      <header class="login-header">
        <brand-mark class="login-mark" :size="56" />
        <h1 class="login-title" data-testid="app-name">{{ t('app.name') }}</h1>
        <p class="login-subtitle">{{ t('auth.adminOnly') }}</p>
      </header>

      <a-alert
        v-if="errorMessage"
        class="login-alert"
        type="error"
        show-icon
        :message="errorMessage"
        data-testid="login-error"
      />

      <a-form :model="form" layout="vertical" data-testid="login-form" @finish="submit">
        <a-form-item
          :label="t('auth.emailLabel')"
          :validate-status="emailError ? 'error' : undefined"
          :help="emailError || undefined"
        >
          <a-input
            v-model:value="form.email"
            type="email"
            size="large"
            dir="ltr"
            inputmode="email"
            autocomplete="username"
            :placeholder="t('auth.emailPlaceholder')"
            data-testid="email-input"
          />
        </a-form-item>
        <a-form-item
          :label="t('auth.passwordLabel')"
          :validate-status="passwordError ? 'error' : undefined"
          :help="passwordError || undefined"
        >
          <a-input-password
            v-model:value="form.password"
            size="large"
            dir="ltr"
            autocomplete="current-password"
            data-testid="password-input"
          />
        </a-form-item>
        <a-button type="primary" html-type="submit" size="large" block :loading="submitting" data-testid="sign-in">
          {{ t('auth.signIn') }}
        </a-button>
      </a-form>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { ADMIN_ROLE_REQUIRED_MESSAGE, useAuthStore } from '../../stores/auth.store'
import { getApiErrorMessage } from '../../utils/axios'
import { safeRedirect } from '../../router/redirect'
import BrandMark from '../../components/common/BrandMark.vue'

// Well-formed enough to be worth a round trip: something@something.tld, no spaces. The server stays the authority.
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const form = reactive({ email: '', password: '' })
const emailError = ref('')
const passwordError = ref('')
// The guard sends a session without the Admin role here with `denied`; say why.
const errorMessage = ref(route.query.denied ? ADMIN_ROLE_REQUIRED_MESSAGE : '')
const submitting = ref(false)

/** Checks the fields before sending. Returns whether both are fit to send. */
function validate(): boolean {
  const email = form.email.trim()
  emailError.value = !email ? t('auth.emailRequired') : EMAIL_PATTERN.test(email) ? '' : t('auth.emailInvalid')
  passwordError.value = form.password ? '' : t('auth.passwordRequired')
  return !emailError.value && !passwordError.value
}

async function submit() {
  if (!validate() || submitting.value) return

  errorMessage.value = ''
  submitting.value = true
  try {
    await authStore.signIn(form.email, form.password)
    await router.replace(safeRedirect(route.query.redirect))
  } catch (error) {
    // The server's own Persian message (wrong credentials, a locked sign-in, a suspended account, too many tries),
    // or the panel's own for an account without the Admin role. A failed attempt never leaves the password behind.
    errorMessage.value = getApiErrorMessage(error)
    form.password = ''
  } finally {
    submitting.value = false
  }
}
</script>

<style scoped>
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 16px;
  background: var(--ty-surface);
}

.login-card {
  width: 100%;
  max-width: 400px;
  box-shadow: 0 8px 24px rgba(15, 23, 42, 0.08);
}

.login-header {
  text-align: center;
  margin-bottom: 24px;
}

.login-mark {
  margin: 0 auto;
}

.login-title {
  margin: 12px 0 4px;
  font-size: 20px;
  font-weight: 600;
  color: var(--ty-text);
}

.login-subtitle {
  margin: 0;
  color: var(--ty-text-secondary);
  font-size: 13px;
}

.login-alert {
  margin-bottom: 16px;
}
</style>
