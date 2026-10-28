<template>
  <a-layout class="admin-layout">
    <a-layout-sider
      v-model:collapsed="collapsed"
      data-testid="shell-sider"
      class="shell-sider"
      theme="light"
      :width="240"
      :collapsed-width="72"
      :trigger="null"
      breakpoint="lg"
      collapsible
    >
      <div class="brand">
        <brand-mark :size="32" />
        <h1 v-if="!collapsed" class="brand-name" data-testid="app-name">{{ t('app.name') }}</h1>
      </div>

      <a-menu :selected-keys="selectedKeys" mode="inline" theme="light" @click="handleMenuClick">
        <a-menu-item v-for="item in MENU" :key="item.key">
          <template #icon><component :is="item.icon" /></template>
          <span>{{ t(item.label) }}</span>
        </a-menu-item>
      </a-menu>
    </a-layout-sider>

    <a-layout class="shell-main">
      <a-layout-header class="header">
        <button
          type="button"
          class="trigger"
          data-testid="shell-menu-button"
          :aria-label="t('navigation.toggleMenu')"
          :aria-expanded="!collapsed"
          @click="collapsed = !collapsed"
        >
          <menu-unfold-outlined v-if="collapsed" />
          <menu-fold-outlined v-else />
        </button>

        <div class="header-end">
          <span v-if="email" class="user-email" data-testid="shell-user">
            <user-outlined />
            <span dir="ltr">{{ email }}</span>
          </span>
          <a-button type="text" data-testid="sign-out" :loading="signingOut" @click="handleSignOut">
            <template #icon><logout-outlined /></template>
            {{ t('auth.signOut') }}
          </a-button>
        </div>
      </a-layout-header>

      <a-layout-content class="content">
        <router-view />
      </a-layout-content>
    </a-layout>
  </a-layout>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { LogoutOutlined, MenuFoldOutlined, MenuUnfoldOutlined, UserOutlined } from '@ant-design/icons-vue'
import { useAuthStore } from '../stores/auth.store'
import { MENU } from './menu'
import BrandMark from '../components/common/BrandMark.vue'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const collapsed = ref(false)
const signingOut = ref(false)

const selectedKeys = computed(() => [route.path.split('/')[1] || 'dashboard'])
const email = computed(() => authStore.user?.email ?? '')

function handleMenuClick({ key }: { key: string | number }) {
  void router.push(`/${key}`)
}

async function handleSignOut() {
  signingOut.value = true
  try {
    await authStore.signOut()
    await router.replace('/login')
  } finally {
    signingOut.value = false
  }
}
</script>

<style scoped>
.admin-layout {
  min-height: 100vh;
}

.shell-sider {
  border-inline-end: 1px solid var(--ty-border);
}

.shell-main {
  /* A flex child's minimum is its content: without this one wide table widens the whole page. */
  min-width: 0;
}

.brand {
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  padding: 0 16px;
  border-bottom: 1px solid var(--ty-border);
}


.brand-name {
  margin: 0;
  font-size: 15px;
  font-weight: 600;
  color: var(--ty-text);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 0 16px;
  background: #fff;
  box-shadow: 0 1px 4px rgba(0, 21, 41, 0.08);
}

.trigger {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  padding: 0;
  border: 0;
  border-radius: 8px;
  background: transparent;
  color: inherit;
  font-size: 18px;
  cursor: pointer;
}

.trigger:hover,
.trigger:focus-visible {
  color: var(--ty-primary);
}

.header-end {
  display: flex;
  align-items: center;
  gap: 16px;
  min-width: 0;
}

.user-email {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: var(--ty-text-secondary);
}

.content {
  margin: 24px;
  min-height: calc(100vh - 112px);
}
</style>

<style>
/* Not scoped: the sider draws the only edge; Ant's inline menu adds a second one that stops where the menu ends. */
.shell-sider .ant-menu-inline {
  border-inline-end: 0 !important;
}
</style>
