using Microsoft.EntityFrameworkCore;
using Rallyto.Identity.Domain.Accounts;
using Rallyto.Identity.Domain.Verification;
using Rallyto.Infrastructure.Core.Persistence;

namespace Rallyto.Identity.Infrastructure.Persistence;

public sealed class IdentityDbContext(DbContextOptions<IdentityDbContext> options) : RallytoDbContext(options)
{
    public override string Schema => IdentityModule.Schema;

    public DbSet<UserAccount> UserAccounts => Set<UserAccount>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<PhoneVerification> PhoneVerifications => Set<PhoneVerification>();
    public DbSet<BannedPhone> BannedPhones => Set<BannedPhone>();
    public DbSet<AccountStatusChange> AccountStatusChanges => Set<AccountStatusChange>();
}
