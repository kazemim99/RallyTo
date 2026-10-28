using Rallyto.Core.Application.Results;
using Rallyto.Identity.Domain;
using Rallyto.Identity.Domain.Accounts;
using Rallyto.Identity.Domain.Verification;

namespace Rallyto.Identity.Application.Abstractions;

public interface IAccountRepository
{
    Task<UserAccount?> GetByIdAsync(Guid id, CancellationToken cancellationToken);

    /// <summary>The account currently holding this number (deleted accounts no longer hold one).</summary>
    Task<UserAccount?> GetByPhoneAsync(PhoneNumber phone, CancellationToken cancellationToken);

    /// <summary>An admin account by its lower-case email.</summary>
    Task<UserAccount?> GetByEmailAsync(string email, CancellationToken cancellationToken);

    Task<int> CountActiveAdminsAsync(CancellationToken cancellationToken);

    Task<PagedResult<UserAccount>> ListAsync(string? phoneDigits, AccountStatus? status, int page, int pageSize, CancellationToken cancellationToken);

    void Add(UserAccount account);

    void AddStatusChange(AccountStatusChange change);

    Task<bool> IsPhoneBannedAsync(string phoneHash, CancellationToken cancellationToken);

    void AddBannedPhone(BannedPhone bannedPhone);
}

public interface IRefreshTokenRepository
{
    Task<RefreshToken?> GetByHashAsync(string tokenHash, CancellationToken cancellationToken);

    void Add(RefreshToken token);

    Task RevokeFamilyAsync(Guid familyId, DateTime now, CancellationToken cancellationToken);

    Task RevokeAllForAccountAsync(Guid accountId, DateTime now, CancellationToken cancellationToken);
}

public interface IPhoneVerificationRepository
{
    void Add(PhoneVerification verification);

    Task<PhoneVerification?> GetLatestPendingAsync(PhoneNumber phone, VerificationPurpose purpose, CancellationToken cancellationToken);

    Task<IReadOnlyList<PhoneVerification>> GetPendingAsync(PhoneNumber phone, VerificationPurpose purpose, CancellationToken cancellationToken);

    /// <summary>Codes actually sent (not cancelled) to the number since <paramref name="since"/>, oldest first.</summary>
    Task<IReadOnlyList<DateTime>> GetSendTimesSinceAsync(PhoneNumber phone, DateTime since, CancellationToken cancellationToken);

    /// <summary>The end of the longest running verification block of the number, if any.</summary>
    Task<DateTime?> GetBlockedUntilAsync(PhoneNumber phone, DateTime now, CancellationToken cancellationToken);
}

/// <summary>Slow, salted hashing for admin passwords.</summary>
public interface IPasswordHasher
{
    string Hash(string password);

    bool Verify(string hash, string password);

    /// <summary>A hash to verify against when the account does not exist, so both paths take the same time.</summary>
    string DummyHash { get; }
}

public interface ISecretHasher
{
    string HashCode(PhoneNumber phone, string code);

    string HashToken(string rawToken);

    string HashPhone(PhoneNumber phone);
}

public interface IOtpCodeGenerator
{
    string Generate(int length);
}

public sealed record AccessToken(string Token, DateTime ExpiresAt);

public interface ITokenService
{
    AccessToken CreateAccessToken(UserAccount account, DateTime now);

    string CreateRefreshToken();

    TimeSpan RefreshTokenLifetime { get; }
}

/// <summary>Evicts an account's cached status after a change, so the next request sees it (design D10).</summary>
public interface IAccountStatusCache
{
    Task EvictAsync(Guid accountId, CancellationToken cancellationToken = default);
}
