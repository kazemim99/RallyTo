using System.Globalization;
using System.Security.Cryptography;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Rallyto.Identity.Application;
using Rallyto.Identity.Application.Abstractions;
using Rallyto.Identity.Domain.Accounts;
using Rallyto.Identity.Infrastructure.Persistence;
using Rallyto.Infrastructure.Core.Persistence;

namespace Rallyto.Identity.Infrastructure.Security;

/// <summary>PBKDF2-SHA256 with a random salt, stored as <c>v1.iterations.salt.hash</c> (Base64), compared in constant time.</summary>
internal sealed class Pbkdf2PasswordHasher : IPasswordHasher
{
    private const int Iterations = 210_000;
    private const int SaltSize = 16;
    private const int HashSize = 32;

    public string DummyHash { get; } = Create("not-a-real-password", RandomNumberGenerator.GetBytes(SaltSize));

    public string Hash(string password) => Create(password, RandomNumberGenerator.GetBytes(SaltSize));

    public bool Verify(string hash, string password)
    {
        var parts = hash.Split('.');
        if (parts.Length != 4 || parts[0] != "v1" || !int.TryParse(parts[1], NumberStyles.None, CultureInfo.InvariantCulture, out var iterations))
            return false;
        var salt = Convert.FromBase64String(parts[2]);
        var expected = Convert.FromBase64String(parts[3]);
        var actual = Rfc2898DeriveBytes.Pbkdf2(password, salt, iterations, HashAlgorithmName.SHA256, expected.Length);
        return CryptographicOperations.FixedTimeEquals(actual, expected);
    }

    private static string Create(string password, byte[] salt) =>
        $"v1.{Iterations}.{Convert.ToBase64String(salt)}.{Convert.ToBase64String(Rfc2898DeriveBytes.Pbkdf2(password, salt, Iterations, HashAlgorithmName.SHA256, HashSize))}";
}

/// <summary>
/// Creates the admin panel's account from <c>Identity:InitialAdmin</c> (user-secrets locally, the server's
/// environment in production), and resets its password whenever the configured one changes. The password is
/// never stored in the repository.
/// </summary>
internal sealed class InitialAdminSeeder(
    IdentityDbContext db,
    IPasswordHasher passwords,
    IOptions<IdentityOptions> options,
    TimeProvider clock,
    ILogger<InitialAdminSeeder> logger) : IDataSeeder
{
    public const int MinimumPasswordLength = 10;

    public async Task SeedAsync(CancellationToken cancellationToken = default)
    {
        var admin = options.Value.InitialAdmin;
        if (string.IsNullOrWhiteSpace(admin.Email) || string.IsNullOrEmpty(admin.Password))
        {
            logger.LogWarning("Identity:InitialAdmin is not configured; nobody can sign in to the admin panel until it is");
            return;
        }

        if (admin.Password.Length < MinimumPasswordLength)
            throw new InvalidOperationException($"Identity:InitialAdmin:Password must be at least {MinimumPasswordLength} characters");

        var email = UserAccount.NormaliseEmail(admin.Email);
        var account = await db.UserAccounts.FirstOrDefaultAsync(a => a.Email == email, cancellationToken);
        if (account is null)
        {
            db.UserAccounts.Add(UserAccount.RegisterAdmin(email, passwords.Hash(admin.Password), clock.GetUtcNow().UtcDateTime));
            logger.LogInformation("Created the admin panel account {Email}", email);
        }
        else
        {
            if (account.PasswordHash is null || !passwords.Verify(account.PasswordHash, admin.Password))
                account.SetPassword(passwords.Hash(admin.Password));
            if (!account.IsAdmin)
                account.GrantAdmin();
        }

        await db.SaveChangesAsync(cancellationToken);
    }
}
