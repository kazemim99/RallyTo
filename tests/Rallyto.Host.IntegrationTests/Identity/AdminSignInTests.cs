using System.Net;
using Rallyto.Host.IntegrationTests.Infrastructure;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Identity;

/// <summary>The admin panel signs in with an email and a password; players keep the SMS code.</summary>
public sealed class AdminSignInTests(RallytoHostFactory factory) : IntegrationTestBase(factory)
{
    private Task<ApiResponse<AuthTokens>> SignInAsync(string email, string password) =>
        Factory.CreateClient().PostApiAsync<AuthTokens>(IdentityApi.AdminSignIn, new { email, password });

    [Fact]
    public async Task The_configured_admin_signs_in_with_email_and_password()
    {
        var response = await SignInAsync(RallytoHostFactory.AdminEmail, RallytoHostFactory.AdminPassword);

        response.Status.Should().Be(HttpStatusCode.OK);
        response.Data!.Roles.Should().Contain("Admin");
        var admin = Factory.CreateClient().WithBearer(response.Data.AccessToken);
        (await admin.GetApiAsync<PagedResult<AdminAccount>>(IdentityApi.AdminUsers)).Status.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task The_email_is_not_case_sensitive()
    {
        var response = await SignInAsync(RallytoHostFactory.AdminEmail.ToUpperInvariant(), RallytoHostFactory.AdminPassword);

        response.Status.Should().Be(HttpStatusCode.OK);
    }

    [Theory]
    [InlineData(RallytoHostFactory.AdminEmail, "wrong-password")]
    [InlineData("someone@example.com", RallytoHostFactory.AdminPassword)]
    public async Task Wrong_credentials_get_one_generic_answer(string email, string password)
    {
        var response = await SignInAsync(email, password);

        response.Status.Should().Be(HttpStatusCode.Unauthorized);
        response.ErrorCode.Should().Be("INVALID_CREDENTIALS");
    }

    [Fact]
    public async Task Five_wrong_passwords_lock_the_admin_for_15_minutes()
    {
        for (var i = 0; i < 5; i++)
            await SignInAsync(RallytoHostFactory.AdminEmail, "wrong-password");

        var locked = await SignInAsync(RallytoHostFactory.AdminEmail, RallytoHostFactory.AdminPassword);
        Factory.Advance(TimeSpan.FromMinutes(15));
        var after = await SignInAsync(RallytoHostFactory.AdminEmail, RallytoHostFactory.AdminPassword);

        locked.Status.Should().Be(HttpStatusCode.TooManyRequests);
        locked.ErrorCode.Should().Be("ADMIN_SIGN_IN_LOCKED");
        after.Status.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task A_player_never_becomes_admin_through_the_sms_code()
    {
        var tokens = await Factory.SignInAsync("09121111111");

        tokens.Roles.Should().Equal("Player");
    }

    [Fact]
    public async Task A_player_account_cannot_use_the_password_sign_in()
    {
        await Factory.SignInAsync("09191234567");

        (await SignInAsync("09191234567", "anything")).ErrorCode.Should().Be("INVALID_CREDENTIALS");
    }
}
