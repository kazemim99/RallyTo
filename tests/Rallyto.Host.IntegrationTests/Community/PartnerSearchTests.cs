using System.Net;
using Rallyto.Host.IntegrationTests.Infrastructure;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Community;

/// <summary>
/// spec partner-search, player results. Post results are covered with the play-posts slice. The clock starts on
/// Friday 1405/08/01; 1405/08/02 is a Saturday.
/// </summary>
public sealed class PartnerSearchTests(RallytoHostFactory factory) : IntegrationTestBase(factory)
{
    private const string Saturday = "1405/08/02";
    private int _phone = 4000000;

    private sealed record Venues(Guid Esteghlal, Guid Enghelab, Guid Karaj);

    private async Task<Venues> VenuesAsync()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        var karajCity = await CatalogApi.CityIdAsync(admin, "البرز", "کرج");
        return new Venues(
            (await CatalogApi.CreateVenueAsync(admin, tehran, "مجموعه تنیس استقلال", CatalogApi.TennisOutdoor(14))).Id,
            (await CatalogApi.CreateVenueAsync(admin, tehran, "مجموعه ورزشی انقلاب", CatalogApi.TennisOutdoor(10))).Id,
            (await CatalogApi.CreateVenueAsync(admin, karajCity, "باشگاه تنیس کرج", CatalogApi.TennisOutdoor(4))).Id);
    }

    private async Task<(HttpClient Client, Guid Id)> PlayerAsync(string name, string level = "Intermediate", string gender = "Male", string visibility = "Everyone")
    {
        _phone++;
        return await Factory.OnboardedPlayerAsync($"0912{_phone:0000000}", name, gender, level, visibility: visibility);
    }

    private static async Task AvailableAsync(HttpClient client, Guid venue, string[] days, string start, string end)
    {
        var sports = await CommunityApi.SportIdsAsync(client);
        var created = await client.PostApiAsync<AvailabilityView>(AvailabilityApi.Root, AvailabilityApi.Recurring(sports["tennis"], [venue], days, start, end));
        created.Status.Should().Be(HttpStatusCode.Created, created.ErrorCode);
    }

    private static async Task<SearchResultsView> SearchAsync(HttpClient client, Func<Guid, string> query)
    {
        var sports = await CommunityApi.SportIdsAsync(client);
        var response = await client.GetApiAsync<SearchResultsView>(query(sports["tennis"]));
        response.Status.Should().Be(HttpStatusCode.OK, response.ErrorCode);
        return response.Data!;
    }

    [Fact]
    public async Task Defaults_cover_the_city_the_whole_day_and_one_tier_either_side()
    {
        var venues = await VenuesAsync();
        var (searcher, _) = await PlayerAsync("جستجوگر", "Intermediate");
        var (advanced, advancedId) = await PlayerAsync("پیشرفته", "Advanced");
        var (beginner, _) = await PlayerAsync("مبتدی", "Beginner");
        var (inKaraj, _) = await PlayerAsync("کرجی", "Intermediate");
        await AvailableAsync(advanced, venues.Esteghlal, ["Saturday"], "18:00", "24:00");
        await AvailableAsync(beginner, venues.Enghelab, ["Saturday"], "18:00", "24:00");
        await AvailableAsync(inKaraj, venues.Karaj, ["Saturday"], "18:00", "24:00");

        var results = await SearchAsync(searcher, sport => SearchApi.Query(sport, date: Saturday));

        results.Players.Select(p => p.UserId).Should().Equal(advancedId);
    }

    [Fact]
    public async Task Two_hours_of_overlap_is_found_with_its_overlap()
    {
        var venues = await VenuesAsync();
        var (searcher, _) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهزاد");
        await AvailableAsync(b, venues.Esteghlal, ["Saturday"], "18:00", "24:00");

        var results = await SearchAsync(searcher, sport => SearchApi.Query(sport, weekdays: "Saturday", from: "20:00", to: "22:00", venueIds: [venues.Esteghlal]));

        var result = results.Players.Should().ContainSingle().Subject;
        result.UserId.Should().Be(bId);
        result.Windows.Single().OverlapStart.Should().Be("20:00");
        result.Windows.Single().OverlapEnd.Should().Be("22:00");
        result.Windows.Single().Venues.Single().Name.Should().Be("مجموعه تنیس استقلال");
    }

    [Fact]
    public async Task Thirty_minutes_of_overlap_is_not_enough()
    {
        var venues = await VenuesAsync();
        var (searcher, _) = await PlayerAsync("علی");
        var (b, _) = await PlayerAsync("بهزاد");
        await AvailableAsync(b, venues.Esteghlal, ["Saturday"], "18:00", "24:00");

        var results = await SearchAsync(searcher, sport => SearchApi.Query(sport, weekdays: "Saturday", from: "23:30", to: "24:00", venueIds: [venues.Esteghlal]));

        results.Players.Should().BeEmpty();
    }

    [Fact]
    public async Task A_window_on_another_weekday_does_not_match_the_date()
    {
        var venues = await VenuesAsync();
        var (searcher, _) = await PlayerAsync("علی");
        var (b, _) = await PlayerAsync("بهزاد");
        await AvailableAsync(b, venues.Esteghlal, ["Monday"], "18:00", "24:00");

        var results = await SearchAsync(searcher, sport => SearchApi.Query(sport, date: Saturday));

        results.Players.Should().BeEmpty();
    }

    [Fact]
    public async Task Blocked_in_either_direction_is_excluded()
    {
        var venues = await VenuesAsync();
        var (searcher, searcherId) = await PlayerAsync("علی");
        var (b, _) = await PlayerAsync("بهزاد");
        await AvailableAsync(b, venues.Esteghlal, ["Saturday"], "18:00", "24:00");
        await b.PostApiAsync<Empty>($"{CommunityApi.Blocks}/{searcherId}");

        var results = await SearchAsync(searcher, sport => SearchApi.Query(sport, date: Saturday));

        results.Players.Should().BeEmpty();
    }

    [Fact]
    public async Task A_restricted_woman_only_finds_women()
    {
        var venues = await VenuesAsync();
        var (sara, _) = await PlayerAsync("سارا", gender: "Female", visibility: "SameGender");
        var (man, _) = await PlayerAsync("رضا", gender: "Male");
        var (woman, womanId) = await PlayerAsync("مریم", gender: "Female");
        await AvailableAsync(man, venues.Esteghlal, ["Saturday"], "18:00", "24:00");
        await AvailableAsync(woman, venues.Esteghlal, ["Saturday"], "18:00", "24:00");

        var results = await SearchAsync(sara, sport => SearchApi.Query(sport, date: Saturday, gender: "Male"));

        results.Players.Select(p => p.UserId).Should().Equal(womanId);
    }

    [Fact]
    public async Task A_restricted_woman_is_invisible_to_men()
    {
        var venues = await VenuesAsync();
        var (sara, _) = await PlayerAsync("سارا", gender: "Female", visibility: "SameGender");
        var (man, _) = await PlayerAsync("رضا", gender: "Male");
        await AvailableAsync(sara, venues.Esteghlal, ["Saturday"], "18:00", "24:00");

        var results = await SearchAsync(man, sport => SearchApi.Query(sport, date: Saturday));

        results.Players.Should().BeEmpty();
    }

    [Fact]
    public async Task Paused_windows_and_suspended_players_are_excluded()
    {
        var venues = await VenuesAsync();
        var (searcher, _) = await PlayerAsync("علی");
        var (paused, _) = await PlayerAsync("بهزاد");
        var (suspended, suspendedId) = await PlayerAsync("کامران");
        await AvailableAsync(paused, venues.Esteghlal, ["Saturday"], "18:00", "24:00");
        await AvailableAsync(suspended, venues.Esteghlal, ["Saturday"], "18:00", "24:00");
        var window = (await paused.GetApiAsync<List<AvailabilityView>>(AvailabilityApi.Root)).Data!.Single();
        await paused.PostApiAsync<AvailabilityView>($"{AvailabilityApi.Root}/{window.Id}/pause");
        var admin = await Factory.AdminClientAsync();
        await admin.PostApiAsync<Empty>($"{IdentityApi.AdminUsers}/{suspendedId}/suspend", new { until = RallytoHostFactory.DefaultNow.UtcDateTime.AddDays(3), reason = "test" });

        await CommunityApi.EventuallyAsync(async () => (await SearchAsync(searcher, sport => SearchApi.Query(sport, date: Saturday))).Players.Count == 0);
    }

    [Fact]
    public async Task Closer_level_ranks_first()
    {
        var venues = await VenuesAsync();
        var (searcher, _) = await PlayerAsync("علی", "Intermediate");
        var (far, farId) = await PlayerAsync("دور", "Professional");
        var (near, nearId) = await PlayerAsync("نزدیک", "Intermediate");
        await AvailableAsync(far, venues.Esteghlal, ["Saturday"], "18:00", "24:00");
        await AvailableAsync(near, venues.Esteghlal, ["Saturday"], "18:00", "24:00");

        var results = await SearchAsync(searcher, sport => SearchApi.Query(sport, date: Saturday, minLevel: "Beginner", maxLevel: "Professional"));

        results.Players.Select(p => p.UserId).Should().Equal(nearId, farId);
    }

    [Fact]
    public async Task Paging_continues_without_duplicates()
    {
        var venues = await VenuesAsync();
        var (searcher, _) = await PlayerAsync("علی");
        var expected = new List<Guid>();
        for (var i = 0; i < 25; i++)
        {
            var (player, id) = await PlayerAsync($"بازیکن {i}");
            await AvailableAsync(player, venues.Esteghlal, ["Saturday"], "18:00", "24:00");
            expected.Add(id);
        }

        var first = await SearchAsync(searcher, sport => SearchApi.Query(sport, date: Saturday));
        var second = await SearchAsync(searcher, sport => SearchApi.Query(sport, date: Saturday, cursor: first.NextCursor));

        first.Players.Should().HaveCount(20);
        first.NextCursor.Should().NotBeNull();
        second.Players.Should().HaveCount(5);
        second.NextCursor.Should().BeNull();
        first.Players.Concat(second.Players).Select(p => p.UserId).Should().BeEquivalentTo(expected).And.OnlyHaveUniqueItems();
    }

    [Fact]
    public async Task Results_carry_no_phone_birth_date_or_timestamps()
    {
        var venues = await VenuesAsync();
        var (searcher, _) = await PlayerAsync("علی");
        var (b, _) = await PlayerAsync("بهزاد");
        await AvailableAsync(b, venues.Esteghlal, ["Saturday"], "18:00", "24:00");
        var sports = await CommunityApi.SportIdsAsync(searcher);

        var body = await (await searcher.GetAsync(SearchApi.Query(sports["tennis"], date: Saturday))).Content.ReadAsStringAsync();

        body.Should().Contain("بهزاد");
        body.Should().NotContain("+98").And.NotContain("birthDate").And.NotContain("lastActiveAt");
    }
}
