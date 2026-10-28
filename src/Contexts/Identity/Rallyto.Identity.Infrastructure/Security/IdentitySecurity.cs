using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Caching.Hybrid;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Identity.Application;
using Rallyto.Identity.Application.Abstractions;
using Rallyto.Identity.Domain;
using Rallyto.Identity.Domain.Accounts;
using Rallyto.Identity.Infrastructure.Persistence;
using Rallyto.Infrastructure.Web.Security;
using Microsoft.EntityFrameworkCore;

namespace Rallyto.Identity.Infrastructure.Security;

/// <summary>HMAC-SHA256 with a server-side key, so stored hashes are useless without the key.</summary>
internal sealed class SecretHasher : ISecretHasher
{
    private readonly byte[] _key;
    private readonly byte[] _phonePepper;

    public SecretHasher(IConfiguration configuration)
    {
        var key = configuration["Identity:HashKey"] ?? configuration["Jwt:SecretKey"] ?? throw new InvalidOperationException("Identity:HashKey or Jwt:SecretKey is required.");
        _key = Encoding.UTF8.GetBytes(key);
        _phonePepper = Encoding.UTF8.GetBytes(configuration["Identity:PhonePepper"] ?? key + ":phone");
    }

    public string HashCode(PhoneNumber phone, string code) => Hash(_key, $"otp:{phone.Value}:{code}");

    public string HashToken(string rawToken) => Hash(_key, $"refresh:{rawToken}");

    public string HashPhone(PhoneNumber phone) => Hash(_phonePepper, $"banned:{phone.Value}");

    private static string Hash(byte[] key, string value) => Convert.ToHexString(HMACSHA256.HashData(key, Encoding.UTF8.GetBytes(value)));
}

/// <summary>Random codes, or a fixed sandbox code for development (refused in Production by the configuration guard).</summary>
internal sealed class OtpCodeGenerator(IOptions<OtpOptions> options) : IOtpCodeGenerator
{
    public string Generate(int length)
    {
        var sandbox = options.Value.SandboxCode ?? Environment.GetEnvironmentVariable("OTP_SANDBOX_CODE");
        if (!string.IsNullOrWhiteSpace(sandbox) && sandbox.Length == length)
            return sandbox;
        return RandomNumberGenerator.GetInt32(0, (int)Math.Pow(10, length)).ToString(new string('0', length), System.Globalization.CultureInfo.InvariantCulture);
    }
}

/// <summary>HS256 access tokens with <c>sub</c> and role claims; opaque random refresh tokens.</summary>
internal sealed class TokenService(IOptions<JwtSettings> options) : ITokenService
{
    private readonly JwtSettings _settings = options.Value;

    public TimeSpan RefreshTokenLifetime => TimeSpan.FromDays(_settings.RefreshTokenDays);

    public AccessToken CreateAccessToken(UserAccount account, DateTime now)
    {
        var expires = now.AddMinutes(_settings.AccessTokenMinutes);
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, account.Id.ToString()),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString("N")),
        };
        claims.AddRange(Enum.GetValues<AccountRoles>()
            .Where(r => r != AccountRoles.None && account.Roles.HasFlag(r))
            .Select(r => new Claim(ClaimTypes.Role, r.ToString())));

        var descriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Issuer = _settings.Issuer,
            Audience = _settings.Audience,
            IssuedAt = now,
            NotBefore = now,
            Expires = expires,
            SigningCredentials = new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_settings.SecretKey.PadRight(32))), SecurityAlgorithms.HmacSha256),
        };
        var handler = new JwtSecurityTokenHandler();
        return new AccessToken(handler.WriteToken(handler.CreateToken(descriptor)), expires);
    }

    public string CreateRefreshToken() => Base64UrlEncoder.Encode(RandomNumberGenerator.GetBytes(48));
}

/// <summary>
/// Account status read on every request, cached for at most a minute and evicted on change, so suspensions take
/// effect at once (spec identity-access › Account status is enforced on every request).
/// </summary>
internal sealed class AccountStatusReader(HybridCache cache, IServiceProvider services, TimeProvider clock) : IAccountStatusReader, IAccountStatusCache
{
    private static readonly HybridCacheEntryOptions Entry = new() { Expiration = TimeSpan.FromSeconds(60), LocalCacheExpiration = TimeSpan.FromSeconds(60) };

    public async Task<AccountStatusKind> GetStatusAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var cached = await cache.GetOrCreateAsync(Key(userId), async ct =>
        {
            await using var scope = services.CreateAsyncScope();
            var db = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
            var row = await db.UserAccounts.AsNoTracking().Where(a => a.Id == userId)
                .Select(a => new CachedStatus(a.Status, a.SuspendedUntil)).FirstOrDefaultAsync(ct);
            return row ?? new CachedStatus(null, null);
        }, Entry, cancellationToken: cancellationToken);

        return cached.Status switch
        {
            null => AccountStatusKind.Unknown,
            AccountStatus.Active => AccountStatusKind.Active,
            AccountStatus.Suspended when cached.SuspendedUntil <= clock.GetUtcNow().UtcDateTime => AccountStatusKind.Active,
            AccountStatus.Suspended => AccountStatusKind.Suspended,
            AccountStatus.Banned => AccountStatusKind.Banned,
            _ => AccountStatusKind.Deleted,
        };
    }

    public Task EvictAsync(Guid accountId, CancellationToken cancellationToken = default) =>
        cache.RemoveAsync(Key(accountId), cancellationToken).AsTask();

    private static string Key(Guid userId) => $"account-status:{userId:N}";

    public sealed record CachedStatus(AccountStatus? Status, DateTime? SuspendedUntil);
}
