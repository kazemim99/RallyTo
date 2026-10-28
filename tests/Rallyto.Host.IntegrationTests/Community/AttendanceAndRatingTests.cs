using System.Net;
using Microsoft.Extensions.DependencyInjection;
using Rallyto.Community.Infrastructure.Jobs;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Community;

/// <summary>spec match-lifecycle › Attendance confirmation, and spec player-ratings.</summary>
public sealed class AttendanceAndRatingTests(RallytoHostFactory factory) : MatchTestBase(factory)
{
    /// <summary>The test games are on Saturday 19:00 Tehran (15:30 UTC); the clock starts on Friday 09:00 UTC.</summary>
    private static readonly TimeSpan PastTheEnd = TimeSpan.FromHours(33);

    private sealed record Player(string Phone, Guid Id)
    {
        public HttpClient Client { get; set; } = null!;
    }

    private async Task<Player> NewPlayerAsync(string name)
    {
        var (client, id) = await PlayerAsync(name);
        return new Player(LastPhone, id) { Client = client };
    }

    /// <summary>Moves the clock and signs everyone in again, since access tokens last 60 minutes.</summary>
    private async Task AdvanceAsync(TimeSpan by, params Player[] players)
    {
        Factory.Advance(by);
        foreach (var player in players)
            player.Client = await Factory.FreshClientAsync(player.Phone);
    }

    private async Task RunMaintenanceAsync()
    {
        await using var scope = Factory.Services.CreateAsyncScope();
        await scope.ServiceProvider.GetRequiredService<CommunityMaintenance>().RunAsync(CancellationToken.None);
    }

    private async Task<(Guid MatchId, Player Host, Player Guest)> FinishedSinglesAsync()
    {
        var host = await NewPlayerAsync("میزبان");
        var guest = await NewPlayerAsync("مهمان");
        var post = await PostAsync(host.Client, MatchApi.Post(Sports["tennis"], Esteghlal));
        await JoinAsync(guest.Client, post.Id);
        (await AcceptAsync(host.Client, post.Id, guest.Id)).Data!.Status.Should().Be("Confirmed");
        await AdvanceAsync(PastTheEnd, host, guest);
        return (post.Id, host, guest);
    }

    /// <summary>A full padel game: the host and three accepted players.</summary>
    private async Task<(Guid MatchId, Player[] Players)> FinishedPadelAsync(string hostName = "میزبان")
    {
        var host = await NewPlayerAsync(hostName);
        var post = await PostAsync(host.Client, MatchApi.Post(Sports["padel"], Esteghlal, "Doubles"));
        var players = new List<Player> { host };
        for (var i = 1; i <= 3; i++)
        {
            var player = await NewPlayerAsync($"بازیکن {i}");
            await JoinAsync(player.Client, post.Id);
            await AcceptAsync(host.Client, post.Id, player.Id);
            players.Add(player);
        }

        await AdvanceAsync(PastTheEnd, [.. players]);
        return (post.Id, [.. players]);
    }

    private static string? OutcomeOf(MatchAttendance match, Guid playerId) => match.Participants!.Single(p => p.UserId == playerId).Outcome;

    // ---- Attendance -------------------------------------------------------------------------------------------

    [Fact]
    public async Task Attendance_cannot_be_answered_before_the_game_ends()
    {
        var host = await NewPlayerAsync("میزبان");
        var guest = await NewPlayerAsync("مهمان");
        var post = await PostAsync(host.Client, MatchApi.Post(Sports["tennis"], Esteghlal));
        await JoinAsync(guest.Client, post.Id);
        await AcceptAsync(host.Client, post.Id, guest.Id);

        var early = await RatingApi.AnswerAsync(host.Client, post.Id, "Played");

        early.Status.Should().Be(HttpStatusCode.Conflict);
        early.ErrorCode.Should().Be("ATTENDANCE_NOT_OPEN");
    }

    [Fact]
    public async Task Singles_both_say_played_completes_at_once()
    {
        var (matchId, host, guest) = await FinishedSinglesAsync();

        await RatingApi.AnswerAsync(host.Client, matchId, "Played");
        var last = (await RatingApi.AnswerAsync(guest.Client, matchId, "Played")).Data!;

        last.Status.Should().Be("Completed");
        OutcomeOf(last, host.Id).Should().Be("Played");
        OutcomeOf(last, guest.Id).Should().Be("Played");
        last.Attendance!.CanRate.Should().Equal(host.Id);
        (await Factory.PublishedAsync("rallyto.community.match-resolved")).Should().Contain(p => p.Contains(matchId.ToString()) && p.Contains("Completed"));
    }

    [Fact]
    public async Task Singles_one_silent_completes_when_the_window_closes()
    {
        var (matchId, host, guest) = await FinishedSinglesAsync();
        await RatingApi.AnswerAsync(host.Client, matchId, "Played");

        await AdvanceAsync(TimeSpan.FromHours(72), host);
        await RunMaintenanceAsync();
        var match = await RatingApi.MatchAsync(host.Client, matchId);

        match.Status.Should().Be("Completed");
        OutcomeOf(match, guest.Id).Should().Be("Played");
    }

    [Fact]
    public async Task Played_against_did_not_happen_is_disputed_and_cannot_be_rated()
    {
        var (matchId, host, guest) = await FinishedSinglesAsync();

        await RatingApi.AnswerAsync(host.Client, matchId, "Played");
        var disputed = (await RatingApi.AnswerAsync(guest.Client, matchId, "DidNotHappen")).Data!;
        var rating = await RatingApi.RateAsync(host.Client, matchId, RatingApi.Rating(guest.Id));

        disputed.Status.Should().Be("Disputed");
        rating.Status.Should().Be(HttpStatusCode.Conflict);
        rating.ErrorCode.Should().Be("RATING_NOT_ALLOWED");
    }

    [Fact]
    public async Task Doubles_with_a_no_show()
    {
        var (matchId, p) = await FinishedPadelAsync();
        foreach (var player in p.Take(3))
            await RatingApi.AnswerAsync(player.Client, matchId, "Played", p[3].Id);

        await AdvanceAsync(TimeSpan.FromHours(72), p);
        await RunMaintenanceAsync();
        var match = await RatingApi.MatchAsync(p[0].Client, matchId);

        match.Status.Should().Be("Completed");
        p.Take(3).Should().OnlyContain(x => OutcomeOf(match, x.Id) == "Played");
        OutcomeOf(match, p[3].Id).Should().Be("NoShow");
        (await RatingApi.RateAsync(p[0].Client, matchId, RatingApi.Rating(p[3].Id))).ErrorCode.Should().Be("RATING_NOT_ALLOWED");
    }

    [Fact]
    public async Task Contested_no_show()
    {
        var (matchId, p) = await FinishedPadelAsync();
        foreach (var player in p.Take(3))
            await RatingApi.AnswerAsync(player.Client, matchId, "Played", p[3].Id);

        var match = (await RatingApi.AnswerAsync(p[3].Client, matchId, "Played")).Data!;

        match.Status.Should().Be("Completed");
        OutcomeOf(match, p[3].Id).Should().Be("Contested");
        p.Take(3).Should().OnlyContain(x => OutcomeOf(match, x.Id) == "Played");
    }

    [Fact]
    public async Task Nobody_answers_leaves_the_match_unconfirmed()
    {
        var (matchId, host, _) = await FinishedSinglesAsync();

        await AdvanceAsync(TimeSpan.FromHours(72), host);
        await RunMaintenanceAsync();

        (await RatingApi.MatchAsync(host.Client, matchId)).Status.Should().Be("Unconfirmed");
    }

    [Fact]
    public async Task Attendance_opens_with_a_prompt_and_is_answered_once()
    {
        var (matchId, host, _) = await FinishedSinglesAsync();

        await RunMaintenanceAsync();
        await RatingApi.AnswerAsync(host.Client, matchId, "Played");
        var again = await RatingApi.AnswerAsync(host.Client, matchId, "DidNotHappen");

        (await Factory.PublishedAsync("rallyto.community.attendance-opened")).Should().Contain(p => p.Contains(matchId.ToString()));
        again.ErrorCode.Should().Be("ALREADY_ANSWERED");
    }

    // ---- Ratings ----------------------------------------------------------------------------------------------

    private async Task<(Guid MatchId, Player Host, Player Guest)> CompletedSinglesAsync()
    {
        var (matchId, host, guest) = await FinishedSinglesAsync();
        await RatingApi.AnswerAsync(host.Client, matchId, "Played");
        await RatingApi.AnswerAsync(guest.Client, matchId, "Played");
        return (matchId, host, guest);
    }

    [Fact]
    public async Task An_eligible_rating_is_stored_with_exactly_its_values()
    {
        var (matchId, host, guest) = await CompletedSinglesAsync();
        await AdvanceAsync(TimeSpan.FromDays(2), host);

        var rating = await RatingApi.RateAsync(host.Client, matchId, RatingApi.Rating(guest.Id, 4, ["OnTime", "GoodRally"], "AboutRight", "کمی دیر رسید"));
        var stored = (await RatingApi.AdminRatingsAsync(await Factory.AdminClientAsync(), guest.Id)).Single();

        rating.Status.Should().Be(HttpStatusCode.Created);
        stored.Should().BeEquivalentTo(new { Stars = 4, LevelAccuracy = "AboutRight", PrivateNote = "کمی دیر رسید", RaterId = host.Id, Revealed = false });
        stored.Tags.Should().BeEquivalentTo("OnTime", "GoodRally");
    }

    [Fact]
    public async Task Ratings_close_after_seven_days()
    {
        var (matchId, host, guest) = await CompletedSinglesAsync();
        await AdvanceAsync(TimeSpan.FromDays(8), host);

        var rating = await RatingApi.RateAsync(host.Client, matchId, RatingApi.Rating(guest.Id));

        rating.Status.Should().Be(HttpStatusCode.Conflict);
        rating.ErrorCode.Should().Be("RATING_WINDOW_CLOSED");
    }

    [Fact]
    public async Task A_rating_cannot_be_submitted_twice_or_without_a_level_answer()
    {
        var (matchId, host, guest) = await CompletedSinglesAsync();

        var noLevel = await RatingApi.RateAsync(host.Client, matchId, RatingApi.Rating(guest.Id, level: null));
        await RatingApi.RateAsync(host.Client, matchId, RatingApi.Rating(guest.Id));
        var duplicate = await RatingApi.RateAsync(host.Client, matchId, RatingApi.Rating(guest.Id, 1));

        noLevel.Status.Should().Be(HttpStatusCode.BadRequest);
        noLevel.ErrorCode.Should().Be("LEVEL_ACCURACY_REQUIRED");
        duplicate.Status.Should().Be(HttpStatusCode.Conflict);
        duplicate.ErrorCode.Should().Be("ALREADY_RATED");
    }

    [Fact]
    public async Task Ratings_validate_stars_tags_and_self()
    {
        var (matchId, host, guest) = await CompletedSinglesAsync();

        (await RatingApi.RateAsync(host.Client, matchId, RatingApi.Rating(guest.Id, 6))).ErrorCode.Should().Be("INVALID_STARS");
        (await RatingApi.RateAsync(host.Client, matchId, RatingApi.Rating(guest.Id, tags: ["OnTime", "Friendly", "GoodRally", "FairCalls"]))).ErrorCode.Should().Be("TOO_MANY_TAGS");
        (await RatingApi.RateAsync(host.Client, matchId, RatingApi.Rating(host.Id))).ErrorCode.Should().Be("CANNOT_RATE_SELF");
    }

    [Fact]
    public async Task Ratings_are_double_blind_until_both_sides_rate()
    {
        var (matchId, host, guest) = await CompletedSinglesAsync();
        var admin = await Factory.AdminClientAsync();

        await RatingApi.RateAsync(host.Client, matchId, RatingApi.Rating(guest.Id));
        var hidden = (await RatingApi.AdminRatingsAsync(admin, guest.Id)).Single();
        await RatingApi.RateAsync(guest.Client, matchId, RatingApi.Rating(host.Id));

        hidden.Revealed.Should().BeFalse();
        (await RatingApi.AdminRatingsAsync(admin, guest.Id)).Single().Revealed.Should().BeTrue();
        (await RatingApi.AdminRatingsAsync(admin, host.Id)).Single().Revealed.Should().BeTrue();
    }

    [Fact]
    public async Task A_one_sided_rating_is_revealed_when_the_window_closes()
    {
        var (matchId, host, guest) = await CompletedSinglesAsync();
        await RatingApi.RateAsync(host.Client, matchId, RatingApi.Rating(guest.Id));

        await AdvanceAsync(TimeSpan.FromDays(7) + TimeSpan.FromMinutes(1), host);
        await RunMaintenanceAsync();

        (await RatingApi.AdminRatingsAsync(await Factory.AdminClientAsync(), guest.Id)).Single().Revealed.Should().BeTrue();
    }

    [Fact]
    public async Task Reputation_shows_new_player_until_three_revealed_ratings()
    {
        var (matchId, p) = await FinishedPadelAsync();
        foreach (var player in p)
            await RatingApi.AnswerAsync(player.Client, matchId, "Played");
        var host = p[0];
        await RatingApi.RateAsync(p[1].Client, matchId, RatingApi.Rating(host.Id, 5, ["OnTime", "Friendly"]));
        await RatingApi.RateAsync(p[2].Client, matchId, RatingApi.Rating(host.Id, 4, ["OnTime"]));

        await AdvanceAsync(TimeSpan.FromDays(8), p);
        await RunMaintenanceAsync();
        var two = (await RatingApi.ReputationOfAsync(p[3].Client, host.Id)).Sports.Single(s => s.SportId == Sports["padel"]);

        two.IsNew.Should().BeTrue();
        two.StarAverage.Should().BeNull();
    }

    [Fact]
    public async Task Three_revealed_ratings_show_the_average_and_top_tags()
    {
        var (matchId, p) = await FinishedPadelAsync();
        foreach (var player in p)
            await RatingApi.AnswerAsync(player.Client, matchId, "Played");
        var host = p[0];
        await RatingApi.RateAsync(p[1].Client, matchId, RatingApi.Rating(host.Id, 5, ["OnTime", "Friendly"], "Higher"));
        await RatingApi.RateAsync(p[2].Client, matchId, RatingApi.Rating(host.Id, 4, ["OnTime"], "Higher"));
        await RatingApi.RateAsync(p[3].Client, matchId, RatingApi.Rating(host.Id, 4, ["GoodRally", "OnTime"], "AboutRight"));

        await AdvanceAsync(TimeSpan.FromDays(8), p);
        await RunMaintenanceAsync();
        var padel = (await RatingApi.ReputationOfAsync(p[1].Client, host.Id)).Sports.Single(s => s.SportId == Sports["padel"]);

        padel.IsNew.Should().BeFalse();
        padel.StarAverage.Should().Be(4.3);
        padel.RatingCount.Should().Be(3);
        padel.TopTags[0].Should().Be("OnTime");
        padel.LevelStatement.Should().Be("Higher");
    }

    [Fact]
    public async Task Players_see_only_aggregates_of_their_own_ratings()
    {
        var (matchId, host, guest) = await CompletedSinglesAsync();
        await RatingApi.RateAsync(host.Client, matchId, RatingApi.Rating(guest.Id, note: "یادداشت خصوصی"));
        await RatingApi.RateAsync(guest.Client, matchId, RatingApi.Rating(host.Id));

        var raw = await guest.Client.GetStringAsync("/api/v1/profile/reputation");

        raw.Should().Contain("reliability");
        raw.Should().NotContain(host.Id.ToString());
        raw.Should().NotContain("یادداشت خصوصی");
    }

    [Fact]
    public async Task A_new_player_has_a_new_reliability_tier()
    {
        var (_, host, guest) = await CompletedSinglesAsync();

        (await RatingApi.ReputationOfAsync(guest.Client, host.Id)).Reliability.Should().Be("New");
    }

    [Fact]
    public async Task Players_who_have_not_rated_get_one_reminder_on_day_five()
    {
        var (matchId, host, guest) = await CompletedSinglesAsync();
        await RatingApi.RateAsync(host.Client, matchId, RatingApi.Rating(guest.Id));

        await AdvanceAsync(TimeSpan.FromDays(5), host);
        await RunMaintenanceAsync();
        await RunMaintenanceAsync();
        var reminders = (await Factory.PublishedAsync("rallyto.community.rating-reminder-due")).Where(p => p.Contains(matchId.ToString())).ToList();

        reminders.Should().ContainSingle(p => p.Contains(guest.Id.ToString()));
    }

    [Fact]
    public async Task An_admin_removes_an_abusive_rating_and_it_stops_counting()
    {
        var (matchId, p) = await FinishedPadelAsync();
        foreach (var player in p)
            await RatingApi.AnswerAsync(player.Client, matchId, "Played");
        var host = p[0];
        foreach (var rater in p.Skip(1))
            await RatingApi.RateAsync(rater.Client, matchId, RatingApi.Rating(host.Id, rater == p[3] ? 1 : 5));
        await AdvanceAsync(TimeSpan.FromDays(8), p);
        await RunMaintenanceAsync();
        var admin = await Factory.AdminClientAsync();
        var abusive = (await RatingApi.AdminRatingsAsync(admin, host.Id)).Single(r => r.Stars == 1);

        var removal = await admin.DeleteApiAsync<Empty>($"/api/v1/admin/ratings/{abusive.Id}", new { reason = "انتقام بعد از اختلاف" });
        var padel = (await RatingApi.ReputationOfAsync(p[1].Client, host.Id)).Sports.Single(s => s.SportId == Sports["padel"]);

        removal.Status.Should().Be(HttpStatusCode.NoContent);
        padel.IsNew.Should().BeTrue();
        (await RatingApi.AdminRatingsAsync(admin, host.Id)).Single(r => r.Id == abusive.Id).RemovalReason.Should().Be("انتقام بعد از اختلاف");
        (await Factory.PublishedAsync("rallyto.admin.action-recorded")).Should().Contain(x => x.Contains("rating.remove") && x.Contains(abusive.Id.ToString()));
    }

    [Fact]
    public async Task Only_admins_see_individual_ratings()
    {
        var (_, host, guest) = await CompletedSinglesAsync();

        var response = await host.Client.GetApiAsync<List<AdminRatingView>>($"/api/v1/admin/players/{guest.Id}/ratings");

        response.Status.Should().Be(HttpStatusCode.Forbidden);
    }
}
