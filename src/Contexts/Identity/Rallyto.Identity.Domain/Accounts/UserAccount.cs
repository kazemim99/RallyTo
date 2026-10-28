using Rallyto.Core.Domain.Base;
using Rallyto.Core.Domain.Exceptions;

namespace Rallyto.Identity.Domain.Accounts;

[Flags]
public enum AccountRoles
{
    None = 0,
    Player = 1,
    Admin = 2,
}

public enum AccountStatus
{
    Active = 1,
    Suspended = 2,
    Banned = 3,
    Deleted = 4,
}

/// <summary>A person's account: phone number, roles and status (spec identity-access).</summary>
public sealed class UserAccount : AggregateRoot<Guid>
{
    private UserAccount() { }

    public PhoneNumber? Phone { get; private set; }
    public AccountRoles Roles { get; private set; }
    public AccountStatus Status { get; private set; }
    public DateTime? SuspendedUntil { get; private set; }
    public string? StatusReason { get; private set; }
    public bool ProfileCompleted { get; private set; }
    public DateTime RegisteredAt { get; private set; }
    public DateTime? DeletedAt { get; private set; }

    public bool IsAdmin => Roles.HasFlag(AccountRoles.Admin);

    public const int MaxPasswordFailures = 5;
    public static readonly TimeSpan PasswordLockout = TimeSpan.FromMinutes(15);

    /// <summary>Lower-case sign-in email of an admin account; players have none and sign in with an SMS code.</summary>
    public string? Email { get; private set; }

    public string? PasswordHash { get; private set; }
    public int FailedPasswordAttempts { get; private set; }
    public DateTime? PasswordLockedUntil { get; private set; }

    /// <summary>The admin panel's account, created from configuration (design D10).</summary>
    public static UserAccount RegisterAdmin(string email, string passwordHash, DateTime now) => new()
    {
        Id = Guid.NewGuid(),
        Email = NormaliseEmail(email),
        PasswordHash = passwordHash,
        Roles = AccountRoles.Admin,
        Status = AccountStatus.Active,
        RegisteredAt = now,
    };

    public static string NormaliseEmail(string email) => email.Trim().ToLowerInvariant();

    public bool IsPasswordLocked(DateTime now) => PasswordLockedUntil > now;

    public void SetPassword(string passwordHash)
    {
        PasswordHash = passwordHash;
        FailedPasswordAttempts = 0;
        PasswordLockedUntil = null;
    }

    /// <summary>Five wrong passwords in a row lock password sign-in for 15 minutes.</summary>
    public void RecordPasswordFailure(DateTime now)
    {
        FailedPasswordAttempts++;
        if (FailedPasswordAttempts < MaxPasswordFailures)
            return;
        PasswordLockedUntil = now + PasswordLockout;
        FailedPasswordAttempts = 0;
    }

    public void RecordPasswordSuccess()
    {
        FailedPasswordAttempts = 0;
        PasswordLockedUntil = null;
    }

    public static UserAccount Register(PhoneNumber phone, bool isInitialAdmin, DateTime now) => new()
    {
        Id = Guid.NewGuid(),
        Phone = phone,
        Roles = AccountRoles.Player | (isInitialAdmin ? AccountRoles.Admin : AccountRoles.None),
        Status = AccountStatus.Active,
        RegisteredAt = now,
    };

    /// <summary>Status as it stands at <paramref name="now"/>: a suspension past its end date counts as Active.</summary>
    public AccountStatus StatusAt(DateTime now) =>
        Status == AccountStatus.Suspended && SuspendedUntil <= now ? AccountStatus.Active : Status;

    /// <summary>Ends a suspension whose end date has passed. Returns true when the account became Active.</summary>
    public bool ExpireSuspensionIfDue(DateTime now)
    {
        if (Status != AccountStatus.Suspended || SuspendedUntil > now)
            return false;
        Reactivate();
        return true;
    }

    public void Suspend(DateTime until, string reason, DateTime now)
    {
        EnsureNotDeleted();
        if (Status == AccountStatus.Banned)
            throw new InvalidAggregateStateException("ACCOUNT_BANNED", "حساب مسدود دائمی است.");
        if (until <= now)
            throw new BusinessRuleViolationException("SUSPENSION_END_IN_PAST", "تاریخ پایان تعلیق باید در آینده باشد.");
        Status = AccountStatus.Suspended;
        SuspendedUntil = until;
        StatusReason = reason;
    }

    public void LiftSuspension()
    {
        if (Status != AccountStatus.Suspended)
            throw new InvalidAggregateStateException("ACCOUNT_NOT_SUSPENDED", "حساب در حالت تعلیق نیست.");
        Reactivate();
    }

    public void Ban(string reason)
    {
        EnsureNotDeleted();
        Status = AccountStatus.Banned;
        SuspendedUntil = null;
        StatusReason = reason;
    }

    /// <summary>Deletes the account and forgets its phone number, so the number can register again unless it was banned.</summary>
    public void Delete(DateTime now)
    {
        EnsureNotDeleted();
        Status = AccountStatus.Deleted;
        DeletedAt = now;
        Phone = null;
        Roles = AccountRoles.None;
    }

    public void GrantAdmin()
    {
        EnsureNotDeleted();
        Roles |= AccountRoles.Admin;
    }

    public void RevokeAdmin() => Roles &= ~AccountRoles.Admin;

    public void MarkProfileCompleted() => ProfileCompleted = true;

    private void Reactivate()
    {
        Status = AccountStatus.Active;
        SuspendedUntil = null;
        StatusReason = null;
    }

    private void EnsureNotDeleted()
    {
        if (Status == AccountStatus.Deleted)
            throw new InvalidAggregateStateException("ACCOUNT_DELETED", "حساب حذف شده است.");
    }
}

/// <summary>Who changed an account's status, when and why (admin actions and automatic expiry).</summary>
public sealed class AccountStatusChange : Entity<Guid>
{
    private AccountStatusChange() { }

    public Guid AccountId { get; private set; }
    public AccountStatus FromStatus { get; private set; }
    public AccountStatus ToStatus { get; private set; }
    public string? Reason { get; private set; }
    public Guid? ActorId { get; private set; }
    public DateTime ChangedAt { get; private set; }

    public static AccountStatusChange Record(Guid accountId, AccountStatus from, AccountStatus to, string? reason, Guid? actorId, DateTime now) => new()
    {
        Id = Guid.NewGuid(),
        AccountId = accountId,
        FromStatus = from,
        ToStatus = to,
        Reason = reason,
        ActorId = actorId,
        ChangedAt = now,
    };
}

/// <summary>A banned number, stored only as a peppered hash, checked when a new account would be created.</summary>
public sealed class BannedPhone : Entity<Guid>
{
    private BannedPhone() { }

    public string PhoneHash { get; private set; } = string.Empty;
    public Guid AccountId { get; private set; }
    public DateTime BannedAt { get; private set; }

    public static BannedPhone Record(string phoneHash, Guid accountId, DateTime now) =>
        new() { Id = Guid.NewGuid(), PhoneHash = phoneHash, AccountId = accountId, BannedAt = now };
}
