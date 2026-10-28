using System.Net;
using Rallyto.Host.IntegrationTests.Infrastructure;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Identity;

/// <summary>spec identity-access: refresh rotation, sign-out, account deletion, token lifetime.</summary>
public sealed class SessionTests(RallytoHostFactory factory) : IntegrationTestBase(factory)
{
    private const string Phone = "09351234567";

    [Fact]
    public async Task Normal_refresh_rotates_the_refresh_token()
    {
        var tokens = await Factory.SignInAsync(Phone);
        using var client = Factory.CreateClient();

        var refreshed = await client.PostApiAsync<AuthTokens>(IdentityApi.Refresh, new { refreshToken = tokens.RefreshToken });
        var oldAgain = await client.PostApiAsync<AuthTokens>(IdentityApi.Refresh, new { refreshToken = tokens.RefreshToken });

        refreshed.Status.Should().Be(HttpStatusCode.OK);
        refreshed.Data!.RefreshToken.Should().NotBe(tokens.RefreshToken);
        refreshed.Data.AccessToken.Should().NotBeNullOrEmpty();
        oldAgain.Status.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Replaying_a_rotated_token_revokes_the_whole_session()
    {
        var tokens = await Factory.SignInAsync(Phone);
        using var client = Factory.CreateClient();
        var r2 = (await client.PostApiAsync<AuthTokens>(IdentityApi.Refresh, new { refreshToken = tokens.RefreshToken })).Data!.RefreshToken;

        var replay = await client.PostApiAsync<AuthTokens>(IdentityApi.Refresh, new { refreshToken = tokens.RefreshToken });
        var afterReplay = await client.PostApiAsync<AuthTokens>(IdentityApi.Refresh, new { refreshToken = r2 });

        replay.Status.Should().Be(HttpStatusCode.Unauthorized);
        replay.ErrorCode.Should().Be("REFRESH_TOKEN_REUSED");
        afterReplay.Status.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Expired_refresh_token_is_rejected()
    {
        var tokens = await Factory.SignInAsync(Phone);
        Factory.Advance(TimeSpan.FromDays(31));
        using var client = Factory.CreateClient();

        var response = await client.PostApiAsync<AuthTokens>(IdentityApi.Refresh, new { refreshToken = tokens.RefreshToken });

        response.Status.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Access_token_expires_after_sixty_minutes()
    {
        var (client, _) = await Factory.SignedInClientAsync(Phone);
        Factory.Advance(TimeSpan.FromMinutes(61));

        var response = await client.GetApiAsync<MyAccount>(IdentityApi.Me);

        response.Status.Should().Be(HttpStatusCode.Unauthorized);
        response.Raw.Headers.Contains("Token-Expired").Should().BeTrue();
    }

    [Fact]
    public async Task Sign_out_revokes_the_refresh_token()
    {
        var (client, tokens) = await Factory.SignedInClientAsync(Phone);

        var signOut = await client.PostApiAsync<Empty>(IdentityApi.SignOut, new { refreshToken = tokens.RefreshToken });
        var refresh = await Factory.CreateClient().PostApiAsync<AuthTokens>(IdentityApi.Refresh, new { refreshToken = tokens.RefreshToken });

        signOut.Status.Should().Be(HttpStatusCode.NoContent);
        refresh.Status.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Player_deletes_the_account_with_a_fresh_code()
    {
        var (client, _) = await Factory.SignedInClientAsync(Phone);
        Factory.Advance(TimeSpan.FromSeconds(61));
        (await client.PostApiAsync<SendCodeResponse>(IdentityApi.DeletionCode)).Status.Should().Be(HttpStatusCode.OK);

        var deletion = await client.PostApiAsync<Empty>(IdentityApi.Deletion, new { code = Factory.Sms.LastCodeFor(Phone) });
        var afterwards = await client.GetApiAsync<MyAccount>(IdentityApi.Me);

        deletion.Status.Should().Be(HttpStatusCode.NoContent);
        afterwards.Status.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Deletion_without_a_valid_code_keeps_the_account()
    {
        var (client, _) = await Factory.SignedInClientAsync(Phone);

        var deletion = await client.PostApiAsync<Empty>(IdentityApi.Deletion, new { code = "0000" });
        var afterwards = await client.GetApiAsync<MyAccount>(IdentityApi.Me);

        deletion.Status.Should().Be(HttpStatusCode.BadRequest);
        afterwards.Status.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Re_registration_after_deletion_creates_a_new_empty_account()
    {
        var (client, _) = await Factory.SignedInClientAsync(Phone);
        var oldId = await IdentityApi.UserIdOf(client);
        Factory.Advance(TimeSpan.FromSeconds(61));
        await client.PostApiAsync<SendCodeResponse>(IdentityApi.DeletionCode);
        await client.PostApiAsync<Empty>(IdentityApi.Deletion, new { code = Factory.Sms.LastCodeFor(Phone) });
        Factory.Advance(TimeSpan.FromSeconds(61));

        var (newClient, tokens) = await Factory.SignedInClientAsync(Phone);

        (await IdentityApi.UserIdOf(newClient)).Should().NotBe(oldId);
        tokens.ProfileCompleted.Should().BeFalse();
    }
}
