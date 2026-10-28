using System.Net;
using Rallyto.Host.IntegrationTests.Infrastructure;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Community;

/// <summary>spec availability. The clock starts on Friday 1405/08/01 (2026-10-23) in Tehran.</summary>
public sealed class AvailabilityTests(RallytoHostFactory factory) : IntegrationTestBase(factory)
{
    private const string Ali = "09123000001";

    private async Task<(HttpClient Client, Dictionary<string, Guid> Sports, Guid Esteghlal, Guid Enghelab, Guid Karaj)> ArrangeAsync()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        var karajCity = await CatalogApi.CityIdAsync(admin, "البرز", "کرج");
        var esteghlal = await CatalogApi.CreateVenueAsync(admin, tehran, "مجموعه تنیس استقلال", CatalogApi.TennisOutdoor(14), CatalogApi.Sport("padel"));
        var enghelab = await CatalogApi.CreateVenueAsync(admin, tehran, "مجموعه ورزشی انقلاب", CatalogApi.TennisOutdoor(10), CatalogApi.Sport("padel"));
        var karaj = await CatalogApi.CreateVenueAsync(admin, karajCity, "باشگاه تنیس کرج", CatalogApi.TennisOutdoor(4));
        var (client, _) = await Factory.OnboardedPlayerAsync(Ali, "علی");
        var sports = await CommunityApi.SportIdsAsync(client);
        await client.PutApiAsync<MyProfileView>($"{CommunityApi.Profile}/sports/{sports["padel"]}",
            CommunityApi.SportProfile(sports["padel"], formats: ["Doubles"]));
        return (client, sports, esteghlal.Id, enghelab.Id, karaj.Id);
    }

    [Fact]
    public async Task Evening_tennis_window_is_published()
    {
        var (client, sports, esteghlal, _, _) = await ArrangeAsync();

        var response = await client.PostApiAsync<AvailabilityView>(AvailabilityApi.Root,
            AvailabilityApi.Recurring(sports["tennis"], [esteghlal], ["Saturday", "Monday"], "18:00", "24:00"));

        response.Status.Should().Be(HttpStatusCode.Created);
        response.Data!.Status.Should().Be("Active");
        response.Data.Weekdays.Should().Equal("Saturday", "Monday");
        response.Data.EndTime.Should().Be("24:00");
        response.Data.Venues.Should().ContainSingle(v => v.Name == "مجموعه تنیس استقلال");
    }

    [Theory]
    [InlineData("18:00", "18:30", "WINDOW_TOO_SHORT")]
    [InlineData("22:00", "02:00", "WINDOW_CROSSES_MIDNIGHT")]
    [InlineData("18:15", "20:00", "INVALID_TIME_STEP")]
    public async Task Invalid_time_windows_are_rejected(string start, string end, string code)
    {
        var (client, sports, esteghlal, _, _) = await ArrangeAsync();

        var response = await client.PostApiAsync<AvailabilityView>(AvailabilityApi.Root,
            AvailabilityApi.Recurring(sports["tennis"], [esteghlal], ["Saturday"], start, end));

        response.Status.Should().Be(HttpStatusCode.BadRequest);
        response.ErrorCode.Should().Be(code);
    }

    [Fact]
    public async Task Venues_in_different_cities_are_rejected()
    {
        var (client, sports, esteghlal, _, karaj) = await ArrangeAsync();

        var response = await client.PostApiAsync<AvailabilityView>(AvailabilityApi.Root,
            AvailabilityApi.Recurring(sports["tennis"], [esteghlal, karaj], ["Saturday"], "18:00", "20:00"));

        response.Status.Should().Be(HttpStatusCode.BadRequest);
        response.ErrorCode.Should().Be("VENUES_IN_DIFFERENT_CITIES");
    }

    [Fact]
    public async Task Padel_window_with_singles_is_rejected()
    {
        var (client, sports, esteghlal, _, _) = await ArrangeAsync();

        var response = await client.PostApiAsync<AvailabilityView>(AvailabilityApi.Root,
            AvailabilityApi.Recurring(sports["padel"], [esteghlal], ["Saturday"], "18:00", "20:00", ["Singles"]));

        response.Status.Should().Be(HttpStatusCode.BadRequest);
        response.ErrorCode.Should().Be("FORMAT_NOT_ALLOWED");
    }

    [Fact]
    public async Task A_venue_that_does_not_offer_the_sport_is_rejected()
    {
        var (client, sports, _, _, karaj) = await ArrangeAsync();

        var response = await client.PostApiAsync<AvailabilityView>(AvailabilityApi.Root,
            AvailabilityApi.Recurring(sports["padel"], [karaj], ["Saturday"], "18:00", "20:00", ["Doubles"]));

        response.Status.Should().Be(HttpStatusCode.BadRequest);
        response.ErrorCode.Should().Be("VENUE_DOES_NOT_OFFER_SPORT");
    }

    [Fact]
    public async Task One_off_friday_morning_padel()
    {
        var (client, sports, esteghlal, enghelab, _) = await ArrangeAsync();

        var response = await client.PostApiAsync<AvailabilityView>(AvailabilityApi.Root,
            AvailabilityApi.OneOff(sports["padel"], [esteghlal, enghelab], "1405/08/08", "08:00", "11:00"));

        response.Status.Should().Be(HttpStatusCode.Created);
        response.Data!.Kind.Should().Be("OneOff");
        response.Data.Date.Should().Be("1405/08/08");
    }

    [Fact]
    public async Task One_off_more_than_60_days_ahead_is_rejected()
    {
        var (client, sports, esteghlal, _, _) = await ArrangeAsync();

        var response = await client.PostApiAsync<AvailabilityView>(AvailabilityApi.Root,
            AvailabilityApi.OneOff(sports["padel"], [esteghlal], "1405/10/16", "08:00", "11:00"));

        response.Status.Should().Be(HttpStatusCode.BadRequest);
        response.ErrorCode.Should().Be("DATE_TOO_FAR");
    }

    [Fact]
    public async Task One_off_in_the_past_is_rejected()
    {
        var (client, sports, esteghlal, _, _) = await ArrangeAsync();

        // Today is 1405/08/01 and it is 12:30 in Tehran: a window ending at 10:00 today is over.
        var response = await client.PostApiAsync<AvailabilityView>(AvailabilityApi.Root,
            AvailabilityApi.OneOff(sports["padel"], [esteghlal], "1405/08/01", "08:00", "10:00"));

        response.Status.Should().Be(HttpStatusCode.BadRequest);
        response.ErrorCode.Should().Be("WINDOW_IN_PAST");
    }

    [Fact]
    public async Task Eleventh_window_is_rejected()
    {
        var (client, sports, esteghlal, _, _) = await ArrangeAsync();
        for (var hour = 6; hour < 26; hour += 2)
        {
            var start = $"{hour % 24:00}:00";
            var created = await client.PostApiAsync<AvailabilityView>(AvailabilityApi.Root,
                AvailabilityApi.Recurring(sports["tennis"], [esteghlal], [hour < 24 ? "Saturday" : "Sunday"], start, $"{(hour % 24) + 1:00}:00"));
            created.Status.Should().Be(HttpStatusCode.Created, created.ErrorCode);
        }

        var eleventh = await client.PostApiAsync<AvailabilityView>(AvailabilityApi.Root,
            AvailabilityApi.Recurring(sports["tennis"], [esteghlal], ["Tuesday"], "18:00", "20:00"));

        eleventh.Status.Should().Be(HttpStatusCode.Conflict);
        eleventh.ErrorCode.Should().Be("TOO_MANY_WINDOWS");
    }

    [Fact]
    public async Task Overlapping_duplicate_is_rejected_with_a_reference()
    {
        var (client, sports, esteghlal, _, _) = await ArrangeAsync();
        var first = await client.PostApiAsync<AvailabilityView>(AvailabilityApi.Root,
            AvailabilityApi.Recurring(sports["tennis"], [esteghlal], ["Saturday"], "18:00", "24:00"));

        var duplicate = await client.PostApiAsync<AvailabilityView>(AvailabilityApi.Root,
            AvailabilityApi.Recurring(sports["tennis"], [esteghlal], ["Saturday"], "20:00", "22:00"));

        duplicate.Status.Should().Be(HttpStatusCode.Conflict);
        duplicate.ErrorCode.Should().Be("OVERLAPPING_WINDOW");
        duplicate.Error!.Message.Should().Contain(first.Data!.Id.ToString());
    }

    [Fact]
    public async Task Pause_and_resume()
    {
        var (client, sports, esteghlal, _, _) = await ArrangeAsync();
        var window = (await client.PostApiAsync<AvailabilityView>(AvailabilityApi.Root,
            AvailabilityApi.Recurring(sports["tennis"], [esteghlal], ["Saturday"], "18:00", "24:00"))).Data!;

        var paused = await client.PostApiAsync<AvailabilityView>($"{AvailabilityApi.Root}/{window.Id}/pause");
        var resumed = await client.PostApiAsync<AvailabilityView>($"{AvailabilityApi.Root}/{window.Id}/resume");
        var deleted = await client.DeleteApiAsync<Empty>($"{AvailabilityApi.Root}/{window.Id}");
        var mine = await client.GetApiAsync<List<AvailabilityView>>(AvailabilityApi.Root);

        paused.Data!.Status.Should().Be("Paused");
        resumed.Data!.Status.Should().Be("Active");
        deleted.Status.Should().Be(HttpStatusCode.NoContent);
        mine.Data!.Should().BeEmpty();
    }

    [Fact]
    public async Task Other_players_cannot_change_my_window()
    {
        var (client, sports, esteghlal, _, _) = await ArrangeAsync();
        var window = (await client.PostApiAsync<AvailabilityView>(AvailabilityApi.Root,
            AvailabilityApi.Recurring(sports["tennis"], [esteghlal], ["Saturday"], "18:00", "24:00"))).Data!;
        var (other, _) = await Factory.OnboardedPlayerAsync("09123000002", "رضا");

        var response = await other.PostApiAsync<AvailabilityView>($"{AvailabilityApi.Root}/{window.Id}/pause");

        response.Status.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Windows_appear_on_the_owners_profile_for_viewers_who_may_see_it()
    {
        var (client, sports, esteghlal, _, _) = await ArrangeAsync();
        await client.PostApiAsync<AvailabilityView>(AvailabilityApi.Root,
            AvailabilityApi.Recurring(sports["tennis"], [esteghlal], ["Saturday"], "18:00", "24:00"));
        var aliId = await IdentityApi.UserIdOf(client);
        var (viewer, _) = await Factory.OnboardedPlayerAsync("09123000002", "رضا");

        var windows = await viewer.GetApiAsync<List<AvailabilityView>>($"{CommunityApi.Players}/{aliId}/availability");
        await client.PostApiAsync<Empty>($"{CommunityApi.Blocks}/{await IdentityApi.UserIdOf(viewer)}");
        var afterBlock = await viewer.GetApiAsync<List<AvailabilityView>>($"{CommunityApi.Players}/{aliId}/availability");

        windows.Data!.Should().ContainSingle(w => w.StartTime == "18:00");
        afterBlock.Status.Should().Be(HttpStatusCode.NotFound);
    }
}
