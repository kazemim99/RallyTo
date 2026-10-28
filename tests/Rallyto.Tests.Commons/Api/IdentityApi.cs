namespace Rallyto.Tests.Commons.Api;

public sealed record SendCodeResponse(int ExpiresInSeconds, int ResendAfterSeconds);

public sealed record AuthTokens(
    string AccessToken,
    DateTime AccessTokenExpiresAt,
    string RefreshToken,
    DateTime RefreshTokenExpiresAt,
    bool ProfileCompleted,
    string[] Roles);

public sealed record MyAccount(Guid UserId, string PhoneNumber, string[] Roles, string Status, bool ProfileCompleted);

public sealed record AdminAccount(Guid UserId, string? PhoneNumber, string[] Roles, string Status, DateTime? SuspendedUntil, DateTime CreatedAt);

public sealed record PagedResult<T>(IReadOnlyList<T> Items, int Page, int PageSize, int TotalCount);

/// <summary>Sign-in flows through the real API, reading codes from the fake SMS sender.</summary>
public static class IdentityApi
{
    public const string SendCode = "/api/v1/auth/otp/send";
    public const string Verify = "/api/v1/auth/otp/verify";
    public const string Refresh = "/api/v1/auth/refresh";
    public const string SignOut = "/api/v1/auth/sign-out";
    public const string Me = "/api/v1/account/me";
    public const string DeletionCode = "/api/v1/account/deletion/code";
    public const string Deletion = "/api/v1/account/deletion";
    public const string AdminSignIn = "/api/v1/auth/admin/sign-in";
    public const string AdminUsers = "/api/v1/admin/users";

    /// <summary>Sends a code and verifies it; returns the tokens.</summary>
    public static async Task<AuthTokens> SignInAsync(this RallytoHostFactory factory, string localMobile)
    {
        using var client = factory.CreateClient();
        var sent = await client.PostApiAsync<SendCodeResponse>(SendCode, new { phoneNumber = localMobile });
        if (sent.Error is not null)
            throw new InvalidOperationException($"send code failed: {sent.ErrorCode} {sent.Error.Message}");
        var verified = await client.PostApiAsync<AuthTokens>(Verify, new { phoneNumber = localMobile, code = factory.Sms.LastCodeFor(localMobile) });
        return verified.Data ?? throw new InvalidOperationException($"verify failed: {verified.ErrorCode} {verified.Error?.Message}");
    }

    /// <summary>Signs in and returns a client carrying the access token.</summary>
    public static async Task<(HttpClient Client, AuthTokens Tokens)> SignedInClientAsync(this RallytoHostFactory factory, string localMobile)
    {
        var tokens = await factory.SignInAsync(localMobile);
        return (factory.CreateClient().WithBearer(tokens.AccessToken), tokens);
    }

    /// <summary>The configured admin signs in with email and password; the session is reused while it is valid.</summary>
    public static async Task<HttpClient> AdminClientAsync(this RallytoHostFactory factory)
    {
        if (factory.AdminAccessToken is { } token && factory.AdminTokenIssuedAt is { } issued && factory.Clock.GetUtcNow() - issued < TimeSpan.FromMinutes(55))
            return factory.CreateClient().WithBearer(token);
        var response = await factory.CreateClient().PostApiAsync<AuthTokens>(AdminSignIn,
            new { email = RallytoHostFactory.AdminEmail, password = RallytoHostFactory.AdminPassword });
        var tokens = response.Data ?? throw new InvalidOperationException($"admin sign-in failed: {response.ErrorCode}");
        factory.AdminAccessToken = tokens.AccessToken;
        factory.AdminTokenIssuedAt = factory.Clock.GetUtcNow();
        return factory.CreateClient().WithBearer(tokens.AccessToken);
    }

    /// <summary>Signs in again, for example after the clock moved past the access token's lifetime.</summary>
    public static async Task<HttpClient> FreshClientAsync(this RallytoHostFactory factory, string localMobile) =>
        (await factory.SignedInClientAsync(localMobile)).Client;

    public static async Task<Guid> UserIdOf(HttpClient signedInClient) =>
        (await signedInClient.GetApiAsync<MyAccount>(Me)).Data!.UserId;
}
