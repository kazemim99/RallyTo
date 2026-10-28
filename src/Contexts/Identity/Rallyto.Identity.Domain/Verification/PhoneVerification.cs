using Rallyto.Core.Domain.Base;

namespace Rallyto.Identity.Domain.Verification;

public enum VerificationPurpose
{
    SignIn = 1,
    AccountDeletion = 2,
}

public enum VerificationStatus
{
    Pending = 1,
    Verified = 2,
    Superseded = 3,
    Cancelled = 4,
    Failed = 5,
}

public enum VerificationOutcome
{
    Verified,
    WrongCode,
    Expired,
    NotUsable,
}

/// <summary>
/// One code sent by SMS (after AsanRezerve's PhoneVerification aggregate). Only the code's hash is stored. Too many
/// wrong attempts block the number from verifying for a while.
/// </summary>
public sealed class PhoneVerification : AggregateRoot<Guid>
{
    private PhoneVerification() { }

    public PhoneNumber Phone { get; private set; } = null!;
    public VerificationPurpose Purpose { get; private set; }
    public string CodeHash { get; private set; } = string.Empty;
    public DateTime SentAt { get; private set; }
    public DateTime ExpiresAt { get; private set; }
    public int Attempts { get; private set; }
    public VerificationStatus Status { get; private set; }
    public DateTime? BlockedUntil { get; private set; }

    public static PhoneVerification Create(PhoneNumber phone, VerificationPurpose purpose, string codeHash, DateTime now, TimeSpan lifetime) => new()
    {
        Id = Guid.NewGuid(),
        Phone = phone,
        Purpose = purpose,
        CodeHash = codeHash,
        SentAt = now,
        ExpiresAt = now + lifetime,
        Status = VerificationStatus.Pending,
    };

    public VerificationOutcome Verify(string codeHash, DateTime now, int maxAttempts, TimeSpan blockDuration)
    {
        if (Status != VerificationStatus.Pending)
            return VerificationOutcome.NotUsable;
        if (now >= ExpiresAt)
            return VerificationOutcome.Expired;
        if (string.Equals(codeHash, CodeHash, StringComparison.Ordinal))
        {
            Status = VerificationStatus.Verified;
            return VerificationOutcome.Verified;
        }

        Attempts++;
        if (Attempts >= maxAttempts)
        {
            Status = VerificationStatus.Failed;
            BlockedUntil = now + blockDuration;
        }

        return VerificationOutcome.WrongCode;
    }

    /// <summary>A newer code was sent to the same number for the same purpose.</summary>
    public void Supersede()
    {
        if (Status == VerificationStatus.Pending)
            Status = VerificationStatus.Superseded;
    }

    /// <summary>The SMS could not be sent; the code must never work.</summary>
    public void Cancel() => Status = VerificationStatus.Cancelled;
}
