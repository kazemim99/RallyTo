import { ROLE_ADMIN, type AccountStatus, type AdminAccount } from '../../api/users.api'

export type UserAction = 'suspend' | 'liftSuspension' | 'ban' | 'grantAdmin' | 'revokeAdmin'

/**
 * The actions that make sense for an account in its current state; the others are not offered at all.
 * - Active: suspend, ban, and grant or revoke the admin role.
 * - Suspended: lift the suspension, ban, and revoke the admin role (a suspended account is not promoted).
 * - Banned: final; only a leftover admin role can still be revoked.
 * - Deleted: nothing.
 * The server stays the authority (a self-action or the last admin is refused there, with a Persian message).
 */
export function availableActions(account: Pick<AdminAccount, 'status' | 'roles'>): UserAction[] {
  const isAdmin = account.roles?.includes(ROLE_ADMIN) ?? false
  switch (account.status) {
    case 'Active':
      return ['suspend', 'ban', isAdmin ? 'revokeAdmin' : 'grantAdmin']
    case 'Suspended':
      return isAdmin ? ['liftSuspension', 'ban', 'revokeAdmin'] : ['liftSuspension', 'ban']
    case 'Banned':
      return isAdmin ? ['revokeAdmin'] : []
    default:
      return []
  }
}

/** Ant Design tag colours for each status. */
export const STATUS_COLORS: Record<AccountStatus, string> = {
  Active: 'green',
  Suspended: 'orange',
  Banned: 'red',
  Deleted: 'default',
}

export const ROLE_COLORS: Record<string, string> = {
  Admin: 'geekblue',
  Player: 'default',
}
