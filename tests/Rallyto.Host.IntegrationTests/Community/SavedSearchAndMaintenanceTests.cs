using System.Net;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Rallyto.Community.Infrastructure.Persistence;
using Rallyto.Community.Infrastructure.Jobs;
using Rallyto.Host.IntegrationTests.Infrastructure;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Community;

/// <summary>spec partner-search › Saved searches and alerts; spec availability › reconfirmation, expiry and state changes.</summary>
public sealed class SavedSearchAndMaintenanceTests(RallytoHostFactory factory) : IntegrationTestBase(factory)
{
    private int _phone = 5000000;

    private string LastPhone => $"0912{_phone:0000000}";

    private async Task<(HttpClient Client, Guid Id)> PlayerAsync(string name, string gender = "Male")
    {
        _phone++;
        return await Factory.OnboardedPlayerAsync(LastPhone, name, gender);
    }

    /// <summary>After the clock jumps, the old access token has expired: sign in again.</summary>
    private Task<HttpClient> FreshAsync(string phone) => Factory.FreshClientAsync(phone);

    private async Task<Guid> VenueAsync(string name = "مجموعه تنیس استقلال")
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        return (await CatalogApi.CreateVenueAsync(admin, tehran, name, CatalogApi.TennisOutdoor())).Id;
    }

    private static async Task<AvailabilityView> AvailableAsync(HttpClient client, Guid venue, string day = "Saturday", string start = "18:00", string end = "24:00")
    {
        var sports = await CommunityApi.SportIdsAsync(client);
        var created = await client.PostApiAsync<AvailabilityView>(AvailabilityApi.Root, AvailabilityApi.Recurring(sports["tennis"], [venue], [day], start, end));
        created.Status.Should().Be(HttpStatusCode.Created, created.ErrorCode);
        return created.Data!;
    }

    private static async Task<SavedSearchView> SaveAsync(HttpClient client, string name = "شنبه‌ها استقلال")
    {
        var sports = await CommunityApi.SportIdsAsync(client);
        var saved = await client.PostApiAsync<SavedSearchView>(SearchApi.SavedSearches, new
        {
            name,
            alertsEnabled = true,
            criteria = new { sportId = sports["tennis"], weekdays = new[] { "Saturday" }, from = "18:00", to = "22:00" },
        });
        saved.Status.Should().Be(HttpStatusCode.Created, saved.ErrorCode);
        return saved.Data!;
    }

    private async Task RunMaintenanceAsync()
    {
        await using var scope = Factory.Services.CreateAsyncScope();
        await scope.ServiceProvider.GetRequiredService<CommunityMaintenance>().RunAsync(CancellationToken.None);
    }

    private static async Task<SavedSearchView> ReloadAsync(HttpClient client, Guid id) =>
        (await client.GetApiAsync<List<SavedSearchView>>(SearchApi.SavedSearches)).Data!.Single(s => s.Id == id);

    [Fact]
    public async Task A_new_matching_window_raises_an_alert()
    {
        var venue = await VenueAsync();
        var (owner, _) = await PlayerAsync("صاحب جستجو");
        var saved = await SaveAsync(owner);
        var (other, _) = await PlayerAsync("بهزاد");

        await AvailableAsync(other, venue);

        (await ReloadAsync(owner, saved.Id)).AlertsSent.Should().Be(1);
    }

    [Fact]
    public async Task At_most_one_alert_per_six_hours_then_a_digest()
    {
        var venue = await VenueAsync();
        var (owner, _) = await PlayerAsync("صاحب جستجو");
        var ownerPhone = LastPhone;
        var saved = await SaveAsync(owner);
        await AvailableAsync((await PlayerAsync("اول")).Client, venue);
        Factory.Advance(TimeSpan.FromHours(2));

        for (var i = 0; i < 3; i++)
            await AvailableAsync((await PlayerAsync($"بعدی {i}")).Client, venue);
        var throttled = await ReloadAsync(await FreshAsync(ownerPhone), saved.Id);
        Factory.Advance(TimeSpan.FromHours(4));
        await RunMaintenanceAsync();
        var digest = await ReloadAsync(await FreshAsync(ownerPhone), saved.Id);

        throttled.AlertsSent.Should().Be(1);
        throttled.PendingMatches.Should().Be(3);
        digest.AlertsSent.Should().Be(2);
        digest.PendingMatches.Should().Be(0);
    }

    [Fact]
    public async Task Hidden_windows_raise_no_alert()
    {
        var venue = await VenueAsync();
        var (owner, ownerId) = await PlayerAsync("صاحب جستجو");
        var saved = await SaveAsync(owner);
        var (blocker, _) = await PlayerAsync("مسدودکننده");
        await blocker.PostApiAsync<Empty>($"{CommunityApi.Blocks}/{ownerId}");

        await AvailableAsync(blocker, venue);

        (await ReloadAsync(owner, saved.Id)).AlertsSent.Should().Be(0);
    }

    [Fact]
    public async Task At_most_five_saved_searches()
    {
        var (owner, _) = await PlayerAsync("صاحب جستجو");
        for (var i = 0; i < 5; i++)
            await SaveAsync(owner, $"جستجوی {i}");
        var sports = await CommunityApi.SportIdsAsync(owner);

        var sixth = await owner.PostApiAsync<SavedSearchView>(SearchApi.SavedSearches,
            new { name = "ششم", alertsEnabled = true, criteria = new { sportId = sports["tennis"] } });

        sixth.Status.Should().Be(HttpStatusCode.Conflict);
        sixth.ErrorCode.Should().Be("TOO_MANY_SAVED_SEARCHES");
    }

    [Fact]
    public async Task Reminder_on_day_27_and_auto_pause_on_day_30()
    {
        var venue = await VenueAsync();
        var (player, _) = await PlayerAsync("بازیکن");
        var phone = LastPhone;
        var window = await AvailableAsync(player, venue);

        Factory.Advance(TimeSpan.FromDays(27));
        await RunMaintenanceAsync();
        var reminded = await LoadAsync(window.Id);
        Factory.Advance(TimeSpan.FromDays(3));
        await RunMaintenanceAsync();
        var mine = (await (await FreshAsync(phone)).GetApiAsync<List<AvailabilityView>>(AvailabilityApi.Root)).Data!.Single();

        reminded.ReminderSentAt.Should().NotBeNull();
        mine.Status.Should().Be("Paused");
    }

    [Fact]
    public async Task Confirming_resets_the_clock()
    {
        var venue = await VenueAsync();
        var (player, _) = await PlayerAsync("بازیکن");
        var phone = LastPhone;
        var window = await AvailableAsync(player, venue);
        Factory.Advance(TimeSpan.FromDays(27));
        await RunMaintenanceAsync();

        (await (await FreshAsync(phone)).PostApiAsync<AvailabilityView>($"{AvailabilityApi.Root}/{window.Id}/confirm")).Status.Should().Be(HttpStatusCode.OK);
        Factory.Advance(TimeSpan.FromDays(5));
        await RunMaintenanceAsync();

        (await (await FreshAsync(phone)).GetApiAsync<List<AvailabilityView>>(AvailabilityApi.Root)).Data!.Single().Status.Should().Be("Active");
    }

    [Fact]
    public async Task One_off_window_expires_after_it_ends()
    {
        var venue = await VenueAsync();
        var (player, _) = await PlayerAsync("بازیکن");
        var phone = LastPhone;
        var sports = await CommunityApi.SportIdsAsync(player);
        await player.PostApiAsync<AvailabilityView>(AvailabilityApi.Root, AvailabilityApi.OneOff(sports["tennis"], [venue], "1405/08/02", "18:00", "20:00", ["Singles"]));

        Factory.Advance(TimeSpan.FromDays(2));
        await RunMaintenanceAsync();

        (await (await FreshAsync(phone)).GetApiAsync<List<AvailabilityView>>(AvailabilityApi.Root)).Data!.Should().BeEmpty();
    }

    [Fact]
    public async Task Hiding_a_venue_removes_it_and_pauses_windows_left_without_one()
    {
        var esteghlal = await VenueAsync();
        var enghelab = await VenueAsync("مجموعه ورزشی انقلاب");
        var (player, _) = await PlayerAsync("بازیکن");
        var sports = await CommunityApi.SportIdsAsync(player);
        await player.PostApiAsync<AvailabilityView>(AvailabilityApi.Root, AvailabilityApi.Recurring(sports["tennis"], [esteghlal, enghelab], ["Saturday"], "18:00", "20:00"));
        await player.PostApiAsync<AvailabilityView>(AvailabilityApi.Root, AvailabilityApi.Recurring(sports["tennis"], [esteghlal], ["Monday"], "18:00", "20:00"));
        var admin = await Factory.AdminClientAsync();

        await admin.PostApiAsync<Empty>($"{CatalogApi.AdminVenues}/{esteghlal}/hide");

        await CommunityApi.EventuallyAsync(async () =>
        {
            var windows = (await player.GetApiAsync<List<AvailabilityView>>(AvailabilityApi.Root)).Data!;
            var both = windows.Single(w => w.Weekdays.Contains("Saturday"));
            var single = windows.Single(w => w.Weekdays.Contains("Monday"));
            return both.Venues.Select(v => v.Id).SequenceEqual([enghelab]) && both.Status == "Active" && single.Status == "Paused";
        });
    }

    [Fact]
    public async Task Removing_a_sport_profile_pauses_its_windows()
    {
        var venue = await VenueAsync();
        var (player, _) = await PlayerAsync("بازیکن");
        var sports = await CommunityApi.SportIdsAsync(player);
        await player.PutApiAsync<MyProfileView>($"{CommunityApi.Profile}/sports/{sports["badminton"]}",
            CommunityApi.SportProfile(sports["badminton"], formats: ["Singles"]));
        await AvailableAsync(player, venue);

        await player.DeleteApiAsync<MyProfileView>($"{CommunityApi.Profile}/sports/{sports["tennis"]}");

        (await player.GetApiAsync<List<AvailabilityView>>(AvailabilityApi.Root)).Data!.Single().Status.Should().Be("Paused");
    }

    [Fact]
    public async Task A_deleted_accounts_windows_are_removed()
    {
        var venue = await VenueAsync();
        const string phone = "09126000001";
        var (player, playerId) = await Factory.OnboardedPlayerAsync(phone, "رفتنی");
        await AvailableAsync(player, venue);
        Factory.Advance(TimeSpan.FromSeconds(61));
        await player.PostApiAsync<SendCodeResponse>(IdentityApi.DeletionCode);
        await player.PostApiAsync<Empty>(IdentityApi.Deletion, new { code = Factory.Sms.LastCodeFor(phone) });

        await CommunityApi.EventuallyAsync(async () =>
        {
            await using var scope = Factory.Services.CreateAsyncScope();
            var db = scope.ServiceProvider.GetRequiredService<CommunityDbContext>();
            return !await db.Availability.AnyAsync(a => a.PlayerId == playerId);
        });
    }

    private async Task<Rallyto.Community.Domain.Availabilities.Availability> LoadAsync(Guid id)
    {
        await using var scope = Factory.Services.CreateAsyncScope();
        return await scope.ServiceProvider.GetRequiredService<CommunityDbContext>().Availability.AsNoTracking().SingleAsync(a => a.Id == id);
    }
}
