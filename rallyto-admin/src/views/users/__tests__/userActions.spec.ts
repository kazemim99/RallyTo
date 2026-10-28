import { describe, expect, it } from 'vitest'
import { availableActions } from '../userActions'

describe('actions offered for an account', () => {
  it.each([
    ['Active', ['Player'], ['suspend', 'ban', 'grantAdmin']],
    ['Active', ['Player', 'Admin'], ['suspend', 'ban', 'revokeAdmin']],
    ['Suspended', ['Player'], ['liftSuspension', 'ban']],
    ['Suspended', ['Player', 'Admin'], ['liftSuspension', 'ban', 'revokeAdmin']],
    ['Banned', ['Player'], []],
    ['Banned', ['Admin'], ['revokeAdmin']],
    ['Deleted', ['Player', 'Admin'], []],
  ] as const)('%s with roles %j offers %j', (status, roles, expected) => {
    expect(availableActions({ status, roles: [...roles] })).toEqual(expected)
  })
})
