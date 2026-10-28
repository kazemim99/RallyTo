import {
  createRouter,
  createWebHistory,
  type RouteLocationNormalized,
  type RouteLocationRaw,
  type RouteRecordRaw,
  type RouterHistory,
} from 'vue-router'
import { useAuthStore } from '../stores/auth.store'

declare module 'vue-router' {
  interface RouteMeta {
    /** Only a signed-in account with the Admin role may open the route (and its children). */
    requiresAuth?: boolean
    /** The login page: a signed-in admin is sent on to the dashboard instead. */
    guestOnly?: boolean
    /** i18n key of the page title. */
    title?: string
  }
}

export const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('../views/auth/LoginView.vue'),
    meta: { guestOnly: true, title: 'auth.title' },
  },
  {
    path: '/',
    component: () => import('../layouts/AdminLayout.vue'),
    meta: { requiresAuth: true },
    children: [
      { path: '', redirect: '/dashboard' },
      {
        path: 'dashboard',
        name: 'Dashboard',
        component: () => import('../views/dashboard/DashboardView.vue'),
        meta: { title: 'navigation.dashboard' },
      },
      {
        path: 'users',
        name: 'Users',
        component: () => import('../views/users/UsersView.vue'),
        meta: { title: 'navigation.users' },
      },
      {
        path: 'venues',
        name: 'Venues',
        component: () => import('../views/venues/VenuesView.vue'),
        meta: { title: 'navigation.venues' },
      },
      {
        // Clubs found by the Google Places import, waiting for an admin to approve them into the catalog.
        path: 'venue-candidates',
        name: 'VenueCandidates',
        component: () => import('../views/venue-candidates/VenueCandidatesView.vue'),
        meta: { title: 'navigation.venueCandidates' },
      },
      {
        path: 'sports',
        name: 'Sports',
        component: () => import('../views/sports/SportsView.vue'),
        meta: { title: 'navigation.sports' },
      },
      {
        path: 'reports',
        name: 'Reports',
        component: () => import('../views/reports/ReportsView.vue'),
        meta: { title: 'navigation.reports' },
      },
      {
        // One reported player's file: every report with its evidence, earlier actions, and the action dialogs.
        path: 'reports/targets/:userId',
        name: 'ReportTarget',
        component: () => import('../views/reports/ReportTargetView.vue'),
        meta: { title: 'navigation.reports' },
      },
      {
        path: 'disputed-matches',
        name: 'DisputedMatches',
        component: () => import('../views/disputed-matches/DisputedMatchesView.vue'),
        meta: { title: 'navigation.disputedMatches' },
      },
      {
        path: 'audit-log',
        name: 'AuditLog',
        component: () => import('../views/audit-log/AuditLogView.vue'),
        meta: { title: 'navigation.auditLog' },
      },
    ],
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'NotFound',
    component: () => import('../views/NotFound.vue'),
  },
]

/**
 * The panel is for admins only (identity-access › Admin panel sign-in):
 * - a route under `requiresAuth` needs a session, else the login page opens with `redirect` back to it;
 * - and the session must carry the Admin role. A session without it (the role was revoked and a refresh brought
 *   the new roles) is signed out and sent to the login page with `denied`, which explains why;
 * - a signed-in admin who opens the login page goes to the dashboard.
 */
export async function authGuard(to: RouteLocationNormalized): Promise<true | RouteLocationRaw> {
  const auth = useAuthStore()

  if (to.matched.some((record) => record.meta.requiresAuth)) {
    if (!auth.isAuthenticated) {
      return { name: 'Login', query: { redirect: to.fullPath } }
    }
    if (!auth.isAdmin) {
      await auth.signOut()
      return { name: 'Login', query: { denied: '1' } }
    }
    return true
  }

  if (to.meta.guestOnly && auth.isAuthenticated && auth.isAdmin) {
    return { name: 'Dashboard' }
  }

  return true
}

export function createAppRouter(history: RouterHistory = createWebHistory()) {
  const router = createRouter({ history, routes })
  router.beforeEach(authGuard)
  return router
}

const router = createAppRouter()

export default router
