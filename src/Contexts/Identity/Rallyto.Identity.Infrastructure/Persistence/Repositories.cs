using Microsoft.EntityFrameworkCore;
using Rallyto.Core.Application.Results;
using Rallyto.Identity.Application.Abstractions;
using Rallyto.Identity.Domain;
using Rallyto.Identity.Domain.Accounts;
using Rallyto.Identity.Domain.Verification;

namespace Rallyto.Identity.Infrastructure.Persistence;

internal sealed class AccountRepository(IdentityDbContext db) : IAccountRepository
{
    public Task<UserAccount?> GetByIdAsync(Guid id, CancellationToken cancellationToken) =>
        db.UserAccounts.FirstOrDefaultAsync(a => a.Id == id, cancellationToken);

    public Task<UserAccount?> GetByPhoneAsync(PhoneNumber phone, CancellationToken cancellationToken) =>
        db.UserAccounts.FirstOrDefaultAsync(a => a.Phone != null && a.Phone.Value == phone.Value, cancellationToken);

    public Task<UserAccount?> GetByEmailAsync(string email, CancellationToken cancellationToken) =>
        db.UserAccounts.FirstOrDefaultAsync(a => a.Email == email, cancellationToken);

    public Task<int> CountActiveAdminsAsync(CancellationToken cancellationToken) =>
        db.UserAccounts.CountAsync(a => (a.Roles & AccountRoles.Admin) == AccountRoles.Admin && a.Status == AccountStatus.Active, cancellationToken);

    public async Task<PagedResult<UserAccount>> ListAsync(string? phoneDigits, AccountStatus? status, int page, int pageSize, CancellationToken cancellationToken)
    {
        var query = db.UserAccounts.AsNoTracking();
        if (phoneDigits is not null)
            query = query.Where(a => a.Phone != null && a.Phone.Value.Contains(phoneDigits));
        if (status is not null)
            query = query.Where(a => a.Status == status);
        var total = await query.CountAsync(cancellationToken);
        var items = await query.OrderByDescending(a => a.RegisteredAt).Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(cancellationToken);
        return new PagedResult<UserAccount>(items, page, pageSize, total);
    }

    public void Add(UserAccount account) => db.UserAccounts.Add(account);

    public void AddStatusChange(AccountStatusChange change) => db.AccountStatusChanges.Add(change);

    public Task<bool> IsPhoneBannedAsync(string phoneHash, CancellationToken cancellationToken) =>
        db.BannedPhones.AnyAsync(b => b.PhoneHash == phoneHash, cancellationToken);

    public void AddBannedPhone(BannedPhone bannedPhone) => db.BannedPhones.Add(bannedPhone);
}

internal sealed class RefreshTokenRepository(IdentityDbContext db) : IRefreshTokenRepository
{
    public Task<RefreshToken?> GetByHashAsync(string tokenHash, CancellationToken cancellationToken) =>
        db.RefreshTokens.FirstOrDefaultAsync(t => t.TokenHash == tokenHash, cancellationToken);

    public void Add(RefreshToken token) => db.RefreshTokens.Add(token);

    public Task RevokeFamilyAsync(Guid familyId, DateTime now, CancellationToken cancellationToken) =>
        db.RefreshTokens.Where(t => t.FamilyId == familyId && t.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAt, now), cancellationToken);

    public Task RevokeAllForAccountAsync(Guid accountId, DateTime now, CancellationToken cancellationToken) =>
        db.RefreshTokens.Where(t => t.AccountId == accountId && t.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAt, now), cancellationToken);
}

internal sealed class PhoneVerificationRepository(IdentityDbContext db) : IPhoneVerificationRepository
{
    public void Add(PhoneVerification verification) => db.PhoneVerifications.Add(verification);

    public Task<PhoneVerification?> GetLatestPendingAsync(PhoneNumber phone, VerificationPurpose purpose, CancellationToken cancellationToken) =>
        db.PhoneVerifications
            .Where(v => v.Phone == phone && v.Purpose == purpose && v.Status == VerificationStatus.Pending)
            .OrderByDescending(v => v.SentAt)
            .FirstOrDefaultAsync(cancellationToken);

    public async Task<IReadOnlyList<PhoneVerification>> GetPendingAsync(PhoneNumber phone, VerificationPurpose purpose, CancellationToken cancellationToken) =>
        await db.PhoneVerifications
            .Where(v => v.Phone == phone && v.Purpose == purpose && v.Status == VerificationStatus.Pending)
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<DateTime>> GetSendTimesSinceAsync(PhoneNumber phone, DateTime since, CancellationToken cancellationToken) =>
        await db.PhoneVerifications
            .Where(v => v.Phone == phone && v.SentAt >= since && v.Status != VerificationStatus.Cancelled)
            .OrderBy(v => v.SentAt)
            .Select(v => v.SentAt)
            .ToListAsync(cancellationToken);

    public Task<DateTime?> GetBlockedUntilAsync(PhoneNumber phone, DateTime now, CancellationToken cancellationToken) =>
        db.PhoneVerifications
            .Where(v => v.Phone == phone && v.BlockedUntil > now)
            .MaxAsync(v => v.BlockedUntil, cancellationToken);
}
