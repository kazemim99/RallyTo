using System.Net;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Rallyto.Host.IntegrationTests.Infrastructure;
using Rallyto.Identity.Infrastructure.Persistence;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Identity;

/// <summary>spec identity-access: roles, admin status changes, status enforcement, phone privacy.</summary>
public sealed class AccountAdministrationTests(RallytoHostFactory factory) : IntegrationTestBase(factory)
{
    private const string Player = "09191234567";

    [Fact]
    public async Task Player_calling_an_admin_api_is_forbidden()
    {
        var (client, _) = await Factory.SignedInClientAsync(Player);

        var response = await client.GetApiAsync<PagedResult<AdminAccount>>(IdentityApi.AdminUsers);

        response.Status.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Admin_sees_phone_numbers_in_the_user_list()
    {
        await Factory.SignInAsync(Player);
        var admin = await Factory.AdminClientAsync();

        var response = await admin.GetApiAsync<PagedResult<AdminAccount>>($"{IdentityApi.AdminUsers}?search=0919");

        response.Status.Should().Be(HttpStatusCode.OK);
        response.Data!.Items.Should().ContainSingle(a => a.PhoneNumber == "+989191234567");
    }

    [Fact]
    public async Task Suspension_takes_effect_on_the_next_request()
    {
        var (player, _) = await Factory.SignedInClientAsync(Player);
        var playerId = await IdentityApi.UserIdOf(player);
        var admin = await Factory.AdminClientAsync();

        var suspend = await admin.PostApiAsync<Empty>($"{IdentityApi.AdminUsers}/{playerId}/suspend",
            new { until = RallytoHostFactory.DefaultNow.UtcDateTime.AddDays(9), reason = "harassment in chat" });
        var next = await player.GetApiAsync<MyAccount>(IdentityApi.Me);

        suspend.Status.Should().Be(HttpStatusCode.NoContent);
        next.Status.Should().Be(HttpStatusCode.Unauthorized);
        next.ErrorCode.Should().Be("ACCOUNT_SUSPENDED");
    }

    [Fact]
    public async Task Suspended_user_cannot_sign_in_and_is_told_the_end_date()
    {
        var (player, _) = await Factory.SignedInClientAsync(Player);
        var playerId = await IdentityApi.UserIdOf(player);
        var admin = await Factory.AdminClientAsync();
        // 2026-11-22 12:00 UTC is 1405/09/01 in Tehran.
        await admin.PostApiAsync<Empty>($"{IdentityApi.AdminUsers}/{playerId}/suspend",
            new { until = new DateTime(2026, 11, 22, 12, 0, 0, DateTimeKind.Utc), reason = "no-shows" });
        Factory.Advance(TimeSpan.FromSeconds(61));
        using var anonymous = Factory.CreateClient();
        await anonymous.PostApiAsync<SendCodeResponse>(IdentityApi.SendCode, new { phoneNumber = Player });

        var response = await anonymous.PostApiAsync<AuthTokens>(IdentityApi.Verify, new { phoneNumber = Player, code = Factory.Sms.LastCodeFor(Player) });

        response.Status.Should().Be(HttpStatusCode.Forbidden);
        response.ErrorCode.Should().Be("ACCOUNT_SUSPENDED");
        response.Error!.Message.Should().Contain("۱۴۰۵/۰۹/۰۱");
    }

    [Fact]
    public async Task Suspension_ends_on_its_end_date()
    {
        var (player, _) = await Factory.SignedInClientAsync(Player);
        var playerId = await IdentityApi.UserIdOf(player);
        var admin = await Factory.AdminClientAsync();
        await admin.PostApiAsync<Empty>($"{IdentityApi.AdminUsers}/{playerId}/suspend",
            new { until = RallytoHostFactory.DefaultNow.UtcDateTime.AddDays(1), reason = "cooling off" });
        Factory.Advance(TimeSpan.FromDays(2));

        var tokens = await Factory.SignInAsync(Player);

        using var client = Factory.CreateClient().WithBearer(tokens.AccessToken);
        (await client.GetApiAsync<MyAccount>(IdentityApi.Me)).Data!.Status.Should().Be("Active");
    }

    [Fact]
    public async Task Lifting_a_suspension_restores_access()
    {
        var (player, _) = await Factory.SignedInClientAsync(Player);
        var playerId = await IdentityApi.UserIdOf(player);
        var admin = await Factory.AdminClientAsync();
        await admin.PostApiAsync<Empty>($"{IdentityApi.AdminUsers}/{playerId}/suspend",
            new { until = RallytoHostFactory.DefaultNow.UtcDateTime.AddDays(7), reason = "mistake" });

        var lift = await admin.PostApiAsync<Empty>($"{IdentityApi.AdminUsers}/{playerId}/lift-suspension", new { reason = "appeal accepted" });
        var next = await player.GetApiAsync<MyAccount>(IdentityApi.Me);

        lift.Status.Should().Be(HttpStatusCode.NoContent);
        next.Status.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Banned_number_cannot_register_again()
    {
        var (player, _) = await Factory.SignedInClientAsync(Player);
        var playerId = await IdentityApi.UserIdOf(player);
        var admin = await Factory.AdminClientAsync();

        var ban = await admin.PostApiAsync<Empty>($"{IdentityApi.AdminUsers}/{playerId}/ban", new { reason = "repeated harassment" });
        Factory.Advance(TimeSpan.FromSeconds(61));
        using var anonymous = Factory.CreateClient();
        await anonymous.PostApiAsync<SendCodeResponse>(IdentityApi.SendCode, new { phoneNumber = Player });
        var signIn = await anonymous.PostApiAsync<AuthTokens>(IdentityApi.Verify, new { phoneNumber = Player, code = Factory.Sms.LastCodeFor(Player) });

        ban.Status.Should().Be(HttpStatusCode.NoContent);
        signIn.Status.Should().Be(HttpStatusCode.Forbidden);
        signIn.ErrorCode.Should().Be("ACCOUNT_BANNED");
        await using var scope = Factory.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
        (await db.BannedPhones.CountAsync()).Should().Be(1);
        (await db.UserAccounts.CountAsync(a => a.Id != playerId && a.Phone != null && a.Phone.Value == "+989191234567")).Should().Be(0);
    }

    [Fact]
    public async Task Admin_grants_and_revokes_the_admin_role()
    {
        var (player, _) = await Factory.SignedInClientAsync(Player);
        var playerId = await IdentityApi.UserIdOf(player);
        var admin = await Factory.AdminClientAsync();

        var grant = await admin.PostApiAsync<Empty>($"{IdentityApi.AdminUsers}/{playerId}/roles/admin");
        Factory.Advance(TimeSpan.FromSeconds(61));
        var promoted = await Factory.SignInAsync(Player);
        var revoke = await admin.DeleteApiAsync<Empty>($"{IdentityApi.AdminUsers}/{playerId}/roles/admin");

        grant.Status.Should().Be(HttpStatusCode.NoContent);
        promoted.Roles.Should().Contain("Admin");
        revoke.Status.Should().Be(HttpStatusCode.NoContent);
    }

    [Fact]
    public async Task The_last_admin_cannot_be_removed()
    {
        var admin = await Factory.AdminClientAsync();
        var adminId = await IdentityApi.UserIdOf(admin);

        var revoke = await admin.DeleteApiAsync<Empty>($"{IdentityApi.AdminUsers}/{adminId}/roles/admin");

        revoke.Status.Should().Be(HttpStatusCode.Conflict);
        revoke.ErrorCode.Should().Be("LAST_ADMIN");
    }

    [Fact]
    public async Task Account_endpoint_returns_the_phone_only_to_its_owner()
    {
        var (player, _) = await Factory.SignedInClientAsync(Player);

        var me = await player.GetApiAsync<MyAccount>(IdentityApi.Me);

        me.Data!.PhoneNumber.Should().Be("+989191234567");
    }
}
