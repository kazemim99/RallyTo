using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Rallyto.Identity.Domain;
using Rallyto.Identity.Domain.Accounts;
using Rallyto.Identity.Domain.Verification;

namespace Rallyto.Identity.Infrastructure.Persistence;

internal sealed class UserAccountConfiguration : IEntityTypeConfiguration<UserAccount>
{
    public void Configure(EntityTypeBuilder<UserAccount> builder)
    {
        builder.ToTable("user_accounts");
        builder.HasKey(a => a.Id);
        builder.Property(a => a.Id).ValueGeneratedNever();
        builder.OwnsOne(a => a.Phone, phone =>
        {
            phone.Property(p => p.Value).HasColumnName("phone").HasMaxLength(16);
            // A number belongs to at most one live account; deleted accounts forget theirs.
            phone.HasIndex(p => p.Value).IsUnique().HasFilter("phone IS NOT NULL");
        });
        builder.Navigation(a => a.Phone).IsRequired(false);
        builder.Property(a => a.Roles).HasConversion<int>();
        builder.Property(a => a.Status).HasConversion<string>().HasMaxLength(16);
        builder.Property(a => a.StatusReason).HasMaxLength(500);
        builder.HasIndex(a => a.Status);
        builder.Ignore(a => a.IsAdmin);
        builder.Property(a => a.Email).HasMaxLength(256);
        builder.HasIndex(a => a.Email).IsUnique().HasFilter("email IS NOT NULL");
        builder.Property(a => a.PasswordHash).HasMaxLength(200);
    }
}

internal sealed class RefreshTokenConfiguration : IEntityTypeConfiguration<RefreshToken>
{
    public void Configure(EntityTypeBuilder<RefreshToken> builder)
    {
        builder.ToTable("refresh_tokens");
        builder.HasKey(t => t.Id);
        builder.Property(t => t.Id).ValueGeneratedNever();
        builder.Property(t => t.TokenHash).HasMaxLength(64).IsRequired();
        builder.Property(t => t.ReplacedByHash).HasMaxLength(64);
        builder.Property(t => t.IssuedToIp).HasMaxLength(64);
        builder.HasIndex(t => t.TokenHash).IsUnique();
        builder.HasIndex(t => t.FamilyId);
        builder.HasIndex(t => t.AccountId);
        builder.Ignore(t => t.WasRotated);
    }
}

internal sealed class PhoneVerificationConfiguration : IEntityTypeConfiguration<PhoneVerification>
{
    public void Configure(EntityTypeBuilder<PhoneVerification> builder)
    {
        builder.ToTable("phone_verifications");
        builder.HasKey(v => v.Id);
        builder.Property(v => v.Id).ValueGeneratedNever();
        builder.Property(v => v.Phone)
            .HasConversion(p => p.Value, v => PhoneNumber.Parse(v))
            .HasColumnName("phone")
            .HasMaxLength(16)
            .IsRequired();
        builder.Property(v => v.Purpose).HasConversion<string>().HasMaxLength(24);
        builder.Property(v => v.Status).HasConversion<string>().HasMaxLength(16);
        builder.Property(v => v.CodeHash).HasMaxLength(64).IsRequired();
        builder.HasIndex(v => new { v.Phone, v.SentAt });
    }
}

internal sealed class BannedPhoneConfiguration : IEntityTypeConfiguration<BannedPhone>
{
    public void Configure(EntityTypeBuilder<BannedPhone> builder)
    {
        builder.ToTable("banned_phones");
        builder.HasKey(b => b.Id);
        builder.Property(b => b.Id).ValueGeneratedNever();
        builder.Property(b => b.PhoneHash).HasMaxLength(64).IsRequired();
        builder.HasIndex(b => b.PhoneHash).IsUnique();
    }
}

internal sealed class AccountStatusChangeConfiguration : IEntityTypeConfiguration<AccountStatusChange>
{
    public void Configure(EntityTypeBuilder<AccountStatusChange> builder)
    {
        builder.ToTable("account_status_changes");
        builder.HasKey(c => c.Id);
        builder.Property(c => c.Id).ValueGeneratedNever();
        builder.Property(c => c.FromStatus).HasConversion<string>().HasMaxLength(16);
        builder.Property(c => c.ToStatus).HasConversion<string>().HasMaxLength(16);
        builder.Property(c => c.Reason).HasMaxLength(500);
        builder.HasIndex(c => c.AccountId);
    }
}
