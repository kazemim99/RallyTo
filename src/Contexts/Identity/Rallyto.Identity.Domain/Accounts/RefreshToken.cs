using Rallyto.Core.Domain.Base;

namespace Rallyto.Identity.Domain.Accounts;

/// <summary>
/// One refresh token of a session family. Tokens rotate on every use; presenting a rotated token again revokes the
/// whole family (spec identity-access › Refresh token rotation). Only the hash is stored.
/// </summary>
public sealed class RefreshToken : AggregateRoot<Guid>
{
    private RefreshToken() { }

    public Guid AccountId { get; private set; }
    public Guid FamilyId { get; private set; }
    public string TokenHash { get; private set; } = string.Empty;
    public DateTime IssuedAt { get; private set; }
    public DateTime ExpiresAt { get; private set; }
    public DateTime? RevokedAt { get; private set; }
    public string? ReplacedByHash { get; private set; }
    public string? IssuedToIp { get; private set; }

    public bool WasRotated => ReplacedByHash is not null;

    public bool IsUsable(DateTime now) => RevokedAt is null && ReplacedByHash is null && ExpiresAt > now;

    public static RefreshToken Issue(Guid accountId, Guid familyId, string tokenHash, DateTime now, TimeSpan lifetime, string? ip) => new()
    {
        Id = Guid.NewGuid(),
        AccountId = accountId,
        FamilyId = familyId,
        TokenHash = tokenHash,
        IssuedAt = now,
        ExpiresAt = now + lifetime,
        IssuedToIp = ip,
    };

    /// <summary>Marks this token as used and returns its successor in the same family.</summary>
    public RefreshToken Rotate(string newTokenHash, DateTime now, TimeSpan lifetime, string? ip)
    {
        ReplacedByHash = newTokenHash;
        return Issue(AccountId, FamilyId, newTokenHash, now, lifetime, ip);
    }

    public void Revoke(DateTime now) => RevokedAt ??= now;
}
