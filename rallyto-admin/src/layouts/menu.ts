import type { Component } from 'vue'
import {
  AuditOutlined,
  DashboardOutlined,
  EnvironmentOutlined,
  FlagOutlined,
  InboxOutlined,
  TeamOutlined,
  TrophyOutlined,
  WarningOutlined,
} from '@ant-design/icons-vue'

export interface MenuItem {
  /** The route path segment, and the menu's selection key. */
  key: string
  /** i18n key of the label. */
  label: string
  icon: Component
}

/** The side menu, in order. Each entry is a route under the admin layout (router/index.ts). */
export const MENU: MenuItem[] = [
  { key: 'dashboard', label: 'navigation.dashboard', icon: DashboardOutlined },
  { key: 'users', label: 'navigation.users', icon: TeamOutlined },
  { key: 'venues', label: 'navigation.venues', icon: EnvironmentOutlined },
  { key: 'venue-candidates', label: 'navigation.venueCandidates', icon: InboxOutlined },
  { key: 'sports', label: 'navigation.sports', icon: TrophyOutlined },
  { key: 'reports', label: 'navigation.reports', icon: FlagOutlined },
  { key: 'disputed-matches', label: 'navigation.disputedMatches', icon: WarningOutlined },
  { key: 'audit-log', label: 'navigation.auditLog', icon: AuditOutlined },
]
