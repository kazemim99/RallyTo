using System.Net;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Rallyto.Community.Infrastructure.Jobs;
using Rallyto.Community.Infrastructure.Persistence;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Community;

/// <summary>spec match-lifecycle (attendance is covered with the ratings slice).</summary>
public sealed class MatchLifecycleTests(RallytoHostFactory factory) : MatchTestBase(factory)
{
    private async Task RunMaintenanceAsync()
    {
        await using var scope = Factory.Services.CreateAsyncScope();
        await scope.ServiceProvider.GetRequiredService<CommunityMaintenance>().RunAsync(CancellationToken.None);
    }

    private async Task<int> LateCancellationsOfAsync(Guid playerId)
    {
        await using var scope = Factory.Services.CreateAsyncScope();
        return await scope.ServiceProvider.GetRequiredService<CommunityDbContext>().LateCancellations.CountAsync(l => l.PlayerId == playerId);
    }

    private async Task<MatchView> InviteAsync(HttpClient host, object body)
    {
        var response = await host.PostApiAsync<MatchView>(MatchApi.Invitations, body);
        response.Status.Should().Be(HttpStatusCode.Created, response.ErrorCode);
        return response.Data!;
    }

    [Fact]
    public async Task Invitation_creates_a_private_pending_match()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var (guest, guestId) = await PlayerAsync("مهمان");

        var match = await InviteAsync(host, MatchApi.Invitation(Sports["tennis"], Esteghlal, [guestId], message: "شنبه بازی؟"));

        match.Visibility.Should().Be("Private");
        match.Status.Should().Be("Pending");
        match.Participants!.Should().Contain(p => p.UserId == guestId && p.State == "Invited");
        (await GetAsync(guest, match.Id)).MyState.Should().Be("Invited");
    }

    [Fact]
    public async Task Too_many_invitees_are_rejected()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var invitees = new List<Guid>();
        for (var i = 0; i < 4; i++)
            invitees.Add((await PlayerAsync($"مهمان {i}")).Id);

        var response = await host.PostApiAsync<MatchView>(MatchApi.Invitations, MatchApi.Invitation(Sports["padel"], Esteghlal, [.. invitees], "Doubles"));

        response.Status.Should().Be(HttpStatusCode.BadRequest);
        response.ErrorCode.Should().Be("TOO_MANY_INVITEES");
    }

    [Fact]
    public async Task Inviting_a_player_who_blocked_you_looks_like_not_found()
    {
        var (host, hostId) = await PlayerAsync("میزبان");
        var (guest, guestId) = await PlayerAsync("مهمان");
        await guest.PostApiAsync<Empty>($"{CommunityApi.Blocks}/{hostId}");

        var response = await host.PostApiAsync<MatchView>(MatchApi.Invitations, MatchApi.Invitation(Sports["tennis"], Esteghlal, [guestId]));

        response.Status.Should().Be(HttpStatusCode.NotFound);
        response.ErrorCode.Should().Be("PLAYER_NOT_FOUND");
    }

    [Fact]
    public async Task Accepting_a_singles_invitation_confirms_the_match()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var (guest, guestId) = await PlayerAsync("مهمان");
        var match = await InviteAsync(host, MatchApi.Invitation(Sports["tennis"], Esteghlal, [guestId]));

        var accepted = await guest.PostApiAsync<MatchView>($"{MatchApi.Matches}/{match.Id}/invitation/accept");

        accepted.Data!.Status.Should().Be("Confirmed");
        accepted.Data.MyState.Should().Be("Accepted");
    }

    [Fact]
    public async Task All_invitees_declining_cancels_the_match()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var (a, aId) = await PlayerAsync("اول");
        var (b, bId) = await PlayerAsync("دوم");
        var match = await InviteAsync(host, MatchApi.Invitation(Sports["padel"], Esteghlal, [aId, bId], "Doubles", playersBrought: 1));

        await a.PostApiAsync<MatchView>($"{MatchApi.Matches}/{match.Id}/invitation/decline");
        await b.PostApiAsync<MatchView>($"{MatchApi.Matches}/{match.Id}/invitation/decline");

        (await GetAsync(host, match.Id)).Status.Should().Be("Cancelled");
    }

    [Fact]
    public async Task Accepting_into_an_overlapping_match_is_a_schedule_conflict()
    {
        var (host1, _) = await PlayerAsync("میزبان اول");
        var (host2, _) = await PlayerAsync("میزبان دوم");
        var (guest, guestId) = await PlayerAsync("مهمان");
        var first = await InviteAsync(host1, MatchApi.Invitation(Sports["tennis"], Esteghlal, [guestId], startTime: "18:00"));
        await guest.PostApiAsync<MatchView>($"{MatchApi.Matches}/{first.Id}/invitation/accept");
        var second = await InviteAsync(host2, MatchApi.Invitation(Sports["tennis"], Esteghlal, [guestId], startTime: "19:00"));

        var response = await guest.PostApiAsync<MatchView>($"{MatchApi.Matches}/{second.Id}/invitation/accept");

        response.Status.Should().Be(HttpStatusCode.Conflict);
        response.ErrorCode.Should().Be("SCHEDULE_CONFLICT");
    }

    [Fact]
    public async Task Host_fills_their_own_post_by_invitation()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["padel"], Esteghlal, "Doubles", playersBrought: 1));
        var (guest, guestId) = await PlayerAsync("مهمان");

        await host.PostApiAsync<MatchView>($"{MatchApi.Matches}/{post.Id}/invite", new { playerIds = new[] { guestId } });
        var accepted = await guest.PostApiAsync<MatchView>($"{MatchApi.Matches}/{post.Id}/invitation/accept");

        accepted.Data!.OpenSpots.Should().Be(1);
    }

    [Fact]
    public async Task Host_confirms_a_doubles_game_early()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal, "Doubles"));
        var (a, aId) = await PlayerAsync("اول");
        var (b, bId) = await PlayerAsync("دوم");
        await JoinAsync(a, post.Id);
        await JoinAsync(b, post.Id);
        await AcceptAsync(host, post.Id, aId);
        await AcceptAsync(host, post.Id, bId);

        var confirmed = await host.PostApiAsync<MatchView>($"{MatchApi.Matches}/{post.Id}/confirm");
        var (late, _) = await PlayerAsync("دیررس");
        var join = await JoinAsync(late, post.Id);

        confirmed.Data!.Status.Should().Be("Confirmed");
        join.Status.Should().Be(HttpStatusCode.Conflict);
    }

    [Fact]
    public async Task At_start_time_an_empty_post_expires_and_a_partly_filled_one_confirms()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var empty = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal, startTime: "18:00"));
        var doubles = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal, "Doubles", startTime: "20:00"));
        var (a, aId) = await PlayerAsync("اول");
        var (pending, _) = await PlayerAsync("منتظر");
        await JoinAsync(a, doubles.Id);
        await AcceptAsync(host, doubles.Id, aId);
        await JoinAsync(pending, doubles.Id);
        var hostPhone = "09127000001";

        Factory.Advance(TimeSpan.FromDays(1) + TimeSpan.FromHours(8)); // Saturday 20:30 Tehran
        await RunMaintenanceAsync();
        var fresh = await Factory.FreshClientAsync(hostPhone);

        (await GetAsync(fresh, empty.Id)).Status.Should().Be("Expired");
        var started = await GetAsync(fresh, doubles.Id);
        started.Status.Should().Be("Confirmed");
        started.Participants!.Single(p => p.DisplayName == "منتظر").State.Should().Be("Declined");
    }

    [Fact]
    public async Task Leaving_a_full_public_match_reopens_it()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal, date: "1405/08/03"));
        var (guest, guestId) = await PlayerAsync("مهمان");
        await JoinAsync(guest, post.Id);
        await AcceptAsync(host, post.Id, guestId);

        var leave = await guest.PostApiAsync<MatchView>($"{MatchApi.Matches}/{post.Id}/leave");

        leave.Data!.MyState.Should().Be("Left");
        var reopened = await GetAsync(host, post.Id);
        reopened.Status.Should().Be("Open");
        reopened.OpenSpots.Should().Be(1);
        (await LateCancellationsOfAsync(guestId)).Should().Be(0);
    }

    [Fact]
    public async Task Leaving_a_confirmed_match_five_hours_before_is_a_late_cancellation()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal, date: "1405/08/01", startTime: "17:30"));
        var (guest, guestId) = await PlayerAsync("مهمان");
        await JoinAsync(guest, post.Id);
        await AcceptAsync(host, post.Id, guestId);

        await guest.PostApiAsync<MatchView>($"{MatchApi.Matches}/{post.Id}/leave");

        (await LateCancellationsOfAsync(guestId)).Should().Be(1);
    }

    [Fact]
    public async Task Host_cancelling_a_confirmed_match_late_counts_against_the_host()
    {
        var (host, hostId) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal, date: "1405/08/01", startTime: "17:30"));
        var (guest, guestId) = await PlayerAsync("مهمان");
        await JoinAsync(guest, post.Id);
        await AcceptAsync(host, post.Id, guestId);

        var cancel = await host.PostApiAsync<MatchView>($"{MatchApi.Matches}/{post.Id}/cancel", new { reason = "باران" });

        cancel.Data!.Status.Should().Be("Cancelled");
        (await LateCancellationsOfAsync(hostId)).Should().Be(1);
        (await LateCancellationsOfAsync(guestId)).Should().Be(0);
    }

    [Fact]
    public async Task Leaving_after_blocking_a_participant_is_not_a_late_cancellation()
    {
        var (host, hostId) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal, date: "1405/08/01", startTime: "17:30"));
        var (guest, guestId) = await PlayerAsync("مهمان");
        await JoinAsync(guest, post.Id);
        await AcceptAsync(host, post.Id, guestId);
        await guest.PostApiAsync<Empty>($"{CommunityApi.Blocks}/{hostId}");

        await guest.PostApiAsync<MatchView>($"{MatchApi.Matches}/{post.Id}/leave");

        (await LateCancellationsOfAsync(guestId)).Should().Be(0);
    }

    [Fact]
    public async Task Host_blocks_and_removes_a_participant()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal));
        var (guest, guestId) = await PlayerAsync("مهمان");
        await JoinAsync(guest, post.Id);
        await AcceptAsync(host, post.Id, guestId);
        await host.PostApiAsync<Empty>($"{CommunityApi.Blocks}/{guestId}");

        var remove = await host.PostApiAsync<MatchView>($"{MatchApi.Matches}/{post.Id}/participants/{guestId}/remove");

        remove.Data!.Participants!.Single(p => p.UserId == guestId).State.Should().Be("Removed");
    }

    [Fact]
    public async Task Outsiders_cannot_see_a_private_match()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var (guest, guestId) = await PlayerAsync("مهمان");
        var match = await InviteAsync(host, MatchApi.Invitation(Sports["tennis"], Esteghlal, [guestId]));
        var (outsider, _) = await PlayerAsync("غریبه");

        var response = await outsider.GetApiAsync<MatchView>($"{MatchApi.Matches}/{match.Id}");

        response.Status.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Outsiders_see_a_public_post_without_its_participants()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["padel"], Esteghlal, "Doubles"));
        var (outsider, _) = await PlayerAsync("غریبه");

        var view = await GetAsync(outsider, post.Id);

        view.Participants.Should().BeNull();
        view.MyState.Should().BeNull();
        view.OpenSpots.Should().Be(3);
    }

    [Fact]
    public async Task My_matches_lists_upcoming_games()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var (guest, guestId) = await PlayerAsync("مهمان");
        var match = await InviteAsync(host, MatchApi.Invitation(Sports["tennis"], Esteghlal, [guestId]));
        await guest.PostApiAsync<MatchView>($"{MatchApi.Matches}/{match.Id}/invitation/accept");

        var mine = await guest.GetApiAsync<List<MatchView>>($"{MatchApi.Matches}/mine?scope=upcoming");

        mine.Data!.Should().ContainSingle(m => m.Id == match.Id && m.Status == "Confirmed");
    }

    [Fact]
    public async Task A_sport_with_a_future_match_cannot_be_removed_from_the_profile()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var (guest, guestId) = await PlayerAsync("مهمان");
        var match = await InviteAsync(host, MatchApi.Invitation(Sports["badminton"], Esteghlal, [guestId]));
        await guest.PostApiAsync<MatchView>($"{MatchApi.Matches}/{match.Id}/invitation/accept");

        var remove = await guest.DeleteApiAsync<MyProfileView>($"{CommunityApi.Profile}/sports/{Sports["badminton"]}");

        remove.Status.Should().Be(HttpStatusCode.Conflict);
        remove.ErrorCode.Should().Be("SPORT_HAS_FUTURE_MATCHES");
        (await GetAsync(guest, match.Id)).Status.Should().Be("Confirmed");
    }

    [Fact]
    public async Task A_format_used_by_future_matches_cannot_be_removed()
    {
        var (host, _) = await PlayerAsync("میزبان");
        await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal, "Doubles"));
        var admin = await Factory.AdminClientAsync();
        var tennis = (await admin.GetApiAsync<List<SportDto>>(CatalogApi.AdminSports)).Data!.Single(s => s.Code == "tennis");

        var update = await admin.PutApiAsync<SportDto>($"{CatalogApi.AdminSports}/{tennis.Id}", new
        {
            code = tennis.Code, nameFa = tennis.NameFa, nameEn = tennis.NameEn, sortOrder = tennis.SortOrder,
            defaultSessionMinutes = tennis.DefaultSessionMinutes,
            formats = new[] { new { format = "Singles", playersPerSide = 1 } },
            levels = tennis.Levels.Select(l => new { tier = l.Tier, description = l.Description }).ToArray(),
            surfaces = tennis.Surfaces,
        });

        update.Status.Should().Be(HttpStatusCode.Conflict);
        update.ErrorCode.Should().Be("FORMAT_IN_USE");
    }

    [Fact]
    public async Task Players_already_booked_at_that_time_are_not_offered_in_search()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var (guest, guestId) = await PlayerAsync("مهمان");
        await guest.PostApiAsync<AvailabilityView>(AvailabilityApi.Root,
            AvailabilityApi.Recurring(Sports["tennis"], [Esteghlal], ["Saturday"], "18:00", "24:00"));
        var match = await InviteAsync(host, MatchApi.Invitation(Sports["tennis"], Esteghlal, [guestId], startTime: "19:00", duration: 90));
        await guest.PostApiAsync<MatchView>($"{MatchApi.Matches}/{match.Id}/invitation/accept");
        var (searcher, _) = await PlayerAsync("جستجوگر");

        var during = await searcher.GetApiAsync<SearchResultsView>(SearchApi.Query(Sports["tennis"], date: MatchApi.Saturday, from: "19:00", to: "21:00"));
        var later = await searcher.GetApiAsync<SearchResultsView>(SearchApi.Query(Sports["tennis"], date: MatchApi.Saturday, from: "21:00", to: "24:00"));

        during.Data!.Players.Should().NotContain(p => p.UserId == guestId);
        later.Data!.Players.Should().Contain(p => p.UserId == guestId);
    }

    [Fact]
    public async Task A_banned_host_cancels_their_matches()
    {
        var (host, hostId) = await PlayerAsync("میزبان");
        var (guest, guestId) = await PlayerAsync("مهمان");
        var match = await InviteAsync(host, MatchApi.Invitation(Sports["tennis"], Esteghlal, [guestId]));
        await guest.PostApiAsync<MatchView>($"{MatchApi.Matches}/{match.Id}/invitation/accept");
        var admin = await Factory.AdminClientAsync();

        await admin.PostApiAsync<Empty>($"{IdentityApi.AdminUsers}/{hostId}/ban", new { reason = "harassment" });

        await CommunityApi.EventuallyAsync(async () => (await GetAsync(guest, match.Id)).Status == "Cancelled");
    }

    [Fact]
    public async Task A_suspended_participant_is_removed_without_a_late_cancellation()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal, date: "1405/08/01", startTime: "17:30"));
        var (guest, guestId) = await PlayerAsync("مهمان");
        await JoinAsync(guest, post.Id);
        await AcceptAsync(host, post.Id, guestId);
        var admin = await Factory.AdminClientAsync();

        await admin.PostApiAsync<Empty>($"{IdentityApi.AdminUsers}/{guestId}/suspend", new { until = RallytoHostFactory.DefaultNow.UtcDateTime.AddDays(3), reason = "test" });

        await CommunityApi.EventuallyAsync(async () => (await GetAsync(host, post.Id)).Participants!.Single(p => p.UserId == guestId).State == "Removed");
        (await LateCancellationsOfAsync(guestId)).Should().Be(0);
    }
}
