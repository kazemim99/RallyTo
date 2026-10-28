using System.Net;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Community;

/// <summary>spec play-posts.</summary>
public sealed class PlayPostTests(RallytoHostFactory factory) : MatchTestBase(factory)
{
    [Fact]
    public async Task Tennis_singles_post_has_one_open_spot()
    {
        var (host, _) = await PlayerAsync("میزبان");

        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal, minLevel: "Intermediate", maxLevel: "Advanced", duration: 90));

        post.Status.Should().Be("Open");
        post.OpenSpots.Should().Be(1);
        post.Capacity.Should().Be(2);
        post.EndTime.Should().Be("20:30");
        post.CourtBooked.Should().BeTrue();
    }

    [Theory]
    [InlineData("padel", "Doubles", 1, 2)]
    [InlineData("badminton", "Doubles", 0, 3)]
    [InlineData("squash", "Singles", 0, 1)]
    public async Task Open_spots_follow_capacity_and_players_brought(string sport, string format, int brought, int expectedSpots)
    {
        var (host, _) = await PlayerAsync("میزبان");

        var post = await PostAsync(host, MatchApi.Post(Sports[sport], Esteghlal, format, playersBrought: brought));

        post.OpenSpots.Should().Be(expectedSpots);
    }

    [Fact]
    public async Task Default_duration_is_the_sports_session_length()
    {
        var (host, _) = await PlayerAsync("میزبان");

        var post = await PostAsync(host, MatchApi.Post(Sports["badminton"], Esteghlal));

        post.DurationMinutes.Should().Be(60);
    }

    [Theory]
    [InlineData("padel", "Singles", "1405/08/02", "19:00", "FORMAT_NOT_ALLOWED")]
    [InlineData("tennis", "Singles", "1405/08/01", "12:30", "START_TOO_SOON")]
    [InlineData("tennis", "Singles", "1405/09/05", "19:00", "START_TOO_FAR")]
    public async Task Invalid_posts_are_rejected(string sport, string format, string date, string time, string code)
    {
        var (host, _) = await PlayerAsync("میزبان");

        var response = await host.PostApiAsync<MatchView>(MatchApi.Posts, MatchApi.Post(Sports[sport], Esteghlal, format, date, time));

        response.Status.Should().Be(HttpStatusCode.BadRequest);
        response.ErrorCode.Should().Be(code);
    }

    [Fact]
    public async Task A_venue_that_does_not_offer_the_sport_is_rejected()
    {
        var (host, _) = await PlayerAsync("میزبان");

        var response = await host.PostApiAsync<MatchView>(MatchApi.Posts, MatchApi.Post(Sports["badminton"], TennisOnly));

        response.ErrorCode.Should().Be("VENUE_DOES_NOT_OFFER_SPORT");
    }

    [Fact]
    public async Task A_restricted_host_posts_for_her_own_gender_only()
    {
        var (host, _) = await PlayerAsync("میزبان", gender: "Female", visibility: "SameGender");

        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal, partnerGender: "Any"));

        post.PartnerGender.Should().Be("Female");
    }

    [Fact]
    public async Task Women_only_post_is_hidden_from_men()
    {
        var (host, _) = await PlayerAsync("میزبان", gender: "Female");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal, partnerGender: "Female"));
        var (man, _) = await PlayerAsync("رضا");

        var view = await man.GetApiAsync<MatchView>($"{MatchApi.Matches}/{post.Id}");
        var join = await JoinAsync(man, post.Id);

        view.Status.Should().Be(HttpStatusCode.NotFound);
        join.Status.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task In_range_request_notifies_the_host()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal, minLevel: "Intermediate", maxLevel: "Advanced"));
        var (player, playerId) = await PlayerAsync("مهمان", "Intermediate");

        var join = await JoinAsync(player, post.Id, "سلام، پایه‌ام");
        var hostView = await GetAsync(host, post.Id);

        join.Status.Should().Be(HttpStatusCode.OK);
        join.Data!.MyState.Should().Be("Requested");
        hostView.Participants!.Should().Contain(p => p.UserId == playerId && p.State == "Requested" && !p.OutOfRange && p.Message == "سلام، پایه‌ام");
    }

    [Fact]
    public async Task Out_of_range_request_is_flagged_for_the_host()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal, minLevel: "Intermediate", maxLevel: "Advanced"));
        var (beginner, beginnerId) = await PlayerAsync("مبتدی", "Beginner");

        await JoinAsync(beginner, post.Id);

        (await GetAsync(host, post.Id)).Participants!.Single(p => p.UserId == beginnerId).OutOfRange.Should().BeTrue();
    }

    [Fact]
    public async Task Filling_the_last_spot_confirms_and_declines_the_rest()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal));
        var (a, aId) = await PlayerAsync("اول");
        var (b, _) = await PlayerAsync("دوم");
        var (c, _) = await PlayerAsync("سوم");
        await JoinAsync(a, post.Id);
        await JoinAsync(b, post.Id);
        await JoinAsync(c, post.Id);

        var accepted = await AcceptAsync(host, post.Id, aId);

        accepted.Data!.Status.Should().Be("Confirmed");
        accepted.Data.OpenSpots.Should().Be(0);
        (await GetAsync(b, post.Id)).MyState.Should().Be("Declined");
        (await GetAsync(c, post.Id)).MyState.Should().Be("Declined");
    }

    [Fact]
    public async Task Concurrent_accepts_of_the_last_spot_fill_it_once()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal));
        var (a, aId) = await PlayerAsync("اول");
        var (b, bId) = await PlayerAsync("دوم");
        await JoinAsync(a, post.Id);
        await JoinAsync(b, post.Id);

        var results = await Task.WhenAll(AcceptAsync(host, post.Id, aId), AcceptAsync(host, post.Id, bId));

        results.Count(r => r.Status == HttpStatusCode.OK).Should().Be(1);
        results.Count(r => r.Status == HttpStatusCode.Conflict).Should().Be(1);
        (await GetAsync(host, post.Id)).Participants!.Count(p => p.State == "Accepted").Should().Be(1);
    }

    [Fact]
    public async Task Requester_withdraws_before_a_decision()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal));
        var (player, playerId) = await PlayerAsync("مهمان");
        await JoinAsync(player, post.Id);

        var withdraw = await player.PostApiAsync<MatchView>($"{MatchApi.Matches}/{post.Id}/withdraw");

        withdraw.Data!.MyState.Should().Be("Withdrawn");
        (await GetAsync(host, post.Id)).Participants!.Single(p => p.UserId == playerId).State.Should().Be("Withdrawn");
    }

    [Fact]
    public async Task Schedule_cannot_change_after_someone_joined()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["padel"], Esteghlal, "Doubles"));
        var (player, playerId) = await PlayerAsync("مهمان");
        await JoinAsync(player, post.Id);
        await AcceptAsync(host, post.Id, playerId);

        var change = await host.PutApiAsync<MatchView>($"{MatchApi.Matches}/{post.Id}", MatchApi.Post(Sports["padel"], Esteghlal, "Doubles", startTime: "20:00"));
        var describe = await host.PutApiAsync<MatchView>($"{MatchApi.Matches}/{post.Id}",
            MatchApi.Post(Sports["padel"], Esteghlal, "Doubles", description: "توپ با من"));

        change.Status.Should().Be(HttpStatusCode.Conflict);
        change.ErrorCode.Should().Be("SCHEDULE_LOCKED");
        describe.Data!.Description.Should().Be("توپ با من");
    }

    [Fact]
    public async Task Sixth_open_post_is_rejected()
    {
        var (host, _) = await PlayerAsync("میزبان");
        for (var i = 0; i < 5; i++)
            await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal, startTime: $"{8 + i * 2:00}:00"));

        var sixth = await host.PostApiAsync<MatchView>(MatchApi.Posts, MatchApi.Post(Sports["tennis"], Esteghlal, startTime: "20:00"));

        sixth.Status.Should().Be(HttpStatusCode.Conflict);
        sixth.ErrorCode.Should().Be("TOO_MANY_OPEN_POSTS");
    }

    [Fact]
    public async Task Share_link_shows_an_anonymous_summary_without_photo_or_contacts()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal));
        var token = post.ShareUrl!.Split('/').Last();
        using var anonymous = Factory.CreateClient();

        var summary = await anonymous.GetApiAsync<ShareSummaryView>($"{MatchApi.Share}/{token}");
        var body = await (await anonymous.GetAsync($"{MatchApi.Share}/{token}")).Content.ReadAsStringAsync();
        var page = await anonymous.GetAsync($"/m/{token}");

        post.ShareUrl.Should().StartWith("http://localhost:5000/m/");
        summary.Status.Should().Be(HttpStatusCode.OK);
        summary.Data!.Venue.Should().Be("مجموعه تنیس استقلال");
        summary.Data.HostName.Should().Be("میزبان");
        summary.Data.OpenSpots.Should().Be(1);
        body.Should().NotContain("photo").And.NotContain("ageRange").And.NotContain("+98");
        page.StatusCode.Should().Be(HttpStatusCode.OK);
        (await page.Content.ReadAsStringAsync()).Should().Contain("مجموعه تنیس استقلال");
    }

    [Fact]
    public async Task Regenerated_share_link_invalidates_the_old_one()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal));
        var oldToken = post.ShareUrl!.Split('/').Last();

        var regenerated = await host.PostApiAsync<MatchView>($"{MatchApi.Matches}/{post.Id}/share-token");
        var old = await Factory.CreateClient().GetApiAsync<ShareSummaryView>($"{MatchApi.Share}/{oldToken}");

        regenerated.Data!.ShareUrl.Should().NotEndWith(oldToken);
        old.Status.Should().Be(HttpStatusCode.NotFound);
        old.ErrorCode.Should().Be("SHARE_LINK_INVALID");
    }

    [Fact]
    public async Task Blocked_player_opening_the_link_sees_not_available()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal));
        var (blocked, blockedId) = await PlayerAsync("مسدود");
        await host.PostApiAsync<Empty>($"{CommunityApi.Blocks}/{blockedId}");

        var response = await blocked.GetApiAsync<MatchView>($"{MatchApi.Matches}/by-token/{post.ShareUrl!.Split('/').Last()}");

        response.Status.Should().Be(HttpStatusCode.NotFound);
        response.ErrorCode.Should().Be("MATCH_NOT_AVAILABLE");
    }

    [Fact]
    public async Task Open_posts_appear_in_partner_search()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal, startTime: "19:00", duration: 90));
        var (searcher, _) = await PlayerAsync("جستجوگر");

        var results = await searcher.GetApiAsync<SearchWithPosts>(SearchApi.Query(Sports["tennis"], date: MatchApi.Saturday, from: "18:00", to: "22:00"));

        results.Data!.Posts.Should().ContainSingle(p => p.Id == post.Id);
    }

    public sealed record SearchWithPosts(IReadOnlyList<PartnerResultView> Players, IReadOnlyList<MatchView> Posts, string? NextCursor);
}
