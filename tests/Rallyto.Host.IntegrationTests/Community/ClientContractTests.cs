using System.Net;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Community;

/// <summary>Response shapes the clients rely on: what goes in comes back in the same shape.</summary>
public sealed class ClientContractTests(RallytoHostFactory factory) : MatchTestBase(factory)
{
    private sealed record CriteriaShape(Guid SportId, int? CityId, IReadOnlyList<Guid>? VenueIds, string? Date, IReadOnlyList<string>? Weekdays, string? From, string? To,
        string? MinLevel, string? MaxLevel, string? Gender, string? Format);

    private sealed record SavedSearchShape(Guid Id, string Name, CriteriaShape Criteria, NamedCity City, IReadOnlyList<NamedRef> Venues);

    private sealed record NamedCity(int Id, string Name);

    private sealed record ResultsShape(IReadOnlyList<PartnerResultView> Players, IReadOnlyList<MatchView> Posts, string? NextCursor);

    private sealed record CancelledShape(Guid Id, string Status, string? CancelReason);

    [Fact]
    public async Task A_saved_search_returns_its_criteria_in_the_input_shape_with_names()
    {
        var (player, _) = await PlayerAsync("علی");
        var tehran = await CatalogApi.CityIdAsync(player, "تهران", "تهران");

        var saved = await player.PostApiAsync<SavedSearchShape>(SearchApi.SavedSearches, new
        {
            name = "شنبه‌ها",
            alertsEnabled = true,
            criteria = new { sportId = Sports["tennis"], cityId = tehran, venueIds = new[] { Esteghlal }, weekdays = new[] { "Saturday", "Monday" }, from = "18:00", to = "24:00" },
        });

        saved.Status.Should().Be(HttpStatusCode.Created);
        var criteria = saved.Data!.Criteria;
        criteria.Weekdays.Should().Equal("Saturday", "Monday");
        criteria.From.Should().Be("18:00");
        criteria.To.Should().Be("24:00");
        criteria.Date.Should().BeNull();
        saved.Data.City.Name.Should().Be("تهران");
        saved.Data.Venues.Should().ContainSingle(v => v.Id == Esteghlal && v.Name == "مجموعه تنیس استقلال");
    }

    [Fact]
    public async Task A_dated_saved_search_returns_a_jalali_date()
    {
        var (player, _) = await PlayerAsync("علی");

        var saved = await player.PostApiAsync<SavedSearchShape>(SearchApi.SavedSearches, new
        {
            name = "شنبه",
            alertsEnabled = false,
            criteria = new { sportId = Sports["tennis"], date = MatchApi.Saturday, from = "08:00", to = "12:00" },
        });

        saved.Data!.Criteria.Date.Should().Be(MatchApi.Saturday);
        saved.Data.Criteria.Weekdays.Should().BeEmpty();
    }

    [Theory]
    [InlineData("players", false, true)]
    [InlineData("posts", true, false)]
    public async Task Search_can_ask_for_players_or_posts_only(string results, bool expectPosts, bool expectPlayers)
    {
        var (host, _) = await PlayerAsync("میزبان");
        await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal));
        var (searcher, _) = await PlayerAsync("جستجوگر");

        var response = (await searcher.GetApiAsync<ResultsShape>(SearchApi.Query(Sports["tennis"], date: MatchApi.Saturday, from: "18:00", to: "22:00") + $"&results={results}")).Data!;

        response.Posts.Any().Should().Be(expectPosts);
        if (!expectPlayers)
            response.Players.Should().BeEmpty();
    }

    private sealed record WindowShape(Guid Id, string Status, bool NeedsReconfirmation, string? PausesOn);

    private sealed record PlayerShape(Guid UserId, string Reliability, double? RatingAverage, int RatingCount);

    private sealed record PlayersShape(IReadOnlyList<PlayerShape> Players);

    [Fact]
    public async Task A_weekly_window_says_when_it_needs_reconfirming_and_when_it_pauses()
    {
        var (player, _) = await PlayerAsync("علی");
        var phone = LastPhone;
        var created = await player.PostApiAsync<WindowShape>(AvailabilityApi.Root,
            AvailabilityApi.Recurring(Sports["tennis"], [Esteghlal], ["Saturday"], "18:00", "20:00"));

        Factory.Advance(TimeSpan.FromDays(27));
        player = await Factory.FreshClientAsync(phone);
        var later = (await player.GetApiAsync<List<WindowShape>>(AvailabilityApi.Root)).Data!.Single();

        created.Data!.NeedsReconfirmation.Should().BeFalse();
        created.Data.PausesOn.Should().Be("1405/09/01");
        later.NeedsReconfirmation.Should().BeTrue();
    }

    [Fact]
    public async Task Search_results_carry_reliability_and_rating()
    {
        var (other, otherId) = await PlayerAsync("علی");
        await other.PostApiAsync<WindowShape>(AvailabilityApi.Root, AvailabilityApi.Recurring(Sports["tennis"], [Esteghlal], ["Saturday"], "18:00", "22:00"));
        var (searcher, _) = await PlayerAsync("جستجوگر");

        var players = (await searcher.GetApiAsync<PlayersShape>(SearchApi.Query(Sports["tennis"], weekdays: "Saturday", from: "18:00", to: "22:00"))).Data!.Players;

        players.Should().ContainSingle(p => p.UserId == otherId).Which.Should().BeEquivalentTo(new { Reliability = "New", RatingAverage = (double?)null, RatingCount = 0 });
    }

    [Fact]
    public async Task A_cancelled_match_shows_its_reason()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal));

        var cancelled = (await host.PostApiAsync<CancelledShape>($"{MatchApi.Matches}/{post.Id}/cancel", new { reason = "باران" })).Data!;

        cancelled.Status.Should().Be("Cancelled");
        cancelled.CancelReason.Should().Be("باران");
    }
}
