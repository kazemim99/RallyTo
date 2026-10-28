using System.Diagnostics;
using Microsoft.Extensions.DependencyInjection;
using Rallyto.Community.Domain.Availabilities;
using Rallyto.Community.Domain.Matches;
using Rallyto.Community.Domain.Players;
using Rallyto.Community.Infrastructure.Persistence;
using Rallyto.Core.Domain.SharedKernel;
using Rallyto.Host.IntegrationTests.Community;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;
using Xunit.Abstractions;

namespace Rallyto.Host.IntegrationTests.Performance;

/// <summary>Runs only when <c>RALLYTO_PERF=1</c>: seeding takes minutes and timings need a quiet machine.</summary>
public sealed class PerformanceFactAttribute : FactAttribute
{
    public PerformanceFactAttribute()
    {
        if (Environment.GetEnvironmentVariable("RALLYTO_PERF") != "1")
            Skip = "Set RALLYTO_PERF=1 to run the performance check (tasks 11.3).";
    }
}

/// <summary>
/// tasks 11.3: with 50,000 availability windows and 10,000 open posts in one city, partner search answers under
/// 300 ms at p95, measured end to end through the API.
/// </summary>
public sealed class SearchPerformanceTests(RallytoHostFactory factory, ITestOutputHelper output) : MatchTestBase(factory)
{
    private const int Players = 10_000;
    private const int WindowsPerPlayer = 5;
    private const int Posts = 10_000;
    private const int VenueCount = 20;
    private const int Searches = 100;

    [PerformanceFact]
    public async Task Partner_search_stays_under_300_ms_at_p95()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        var venues = new List<Guid> { Esteghlal, TennisOnly };
        for (var i = venues.Count; i < VenueCount; i++)
            venues.Add((await CatalogApi.CreateVenueAsync(admin, tehran, $"باشگاه آزمایشی {i}", CatalogApi.TennisOutdoor(6), CatalogApi.Sport("padel"))).Id);
        var seeding = Stopwatch.StartNew();
        await SeedAsync(tehran, venues);
        output.WriteLine($"Seeded {Players * WindowsPerPlayer:N0} windows and {Posts:N0} posts in {seeding.Elapsed}");

        var (searcher, _) = await PlayerAsync("جستجوگر");
        string[] days = ["Saturday", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];
        string Query(int i) => i % 3 == 0
            ? SearchApi.Query(Sports["tennis"], date: MatchApi.Saturday, from: $"{16 + i % 4}:00", to: "23:00")
            : SearchApi.Query(Sports["tennis"], weekdays: days[i % 7], from: $"{6 + i % 12}:00", to: $"{12 + i % 12}:00", venueIds: i % 2 == 0 ? [venues[i % VenueCount]] : null);

        for (var i = 0; i < 10; i++)
            await searcher.GetApiAsync<PlayPostTests.SearchWithPosts>(Query(i)); // warm-up: JIT, plans, caches
        var timings = new List<double>();
        for (var i = 0; i < Searches; i++)
        {
            var watch = Stopwatch.StartNew();
            var response = await searcher.GetApiAsync<PlayPostTests.SearchWithPosts>(Query(i));
            timings.Add(watch.Elapsed.TotalMilliseconds);
            response.Data.Should().NotBeNull();
        }

        timings.Sort();
        var p50 = timings[Searches / 2];
        var p95 = timings[(int)(Searches * 0.95) - 1];
        output.WriteLine($"Partner search over {Searches} queries: p50 {p50:F0} ms, p95 {p95:F0} ms, max {timings[^1]:F0} ms");
        p95.Should().BeLessThan(300);
    }

    private async Task SeedAsync(int cityId, IReadOnlyList<Guid> venues)
    {
        var now = Factory.Clock.GetUtcNow().UtcDateTime;
        var today = DateOnly.FromDateTime(now.AddHours(3.5));
        var random = new Random(1405);
        var tennis = Sports["tennis"];
        var playerIds = new List<Guid>(Players);

        for (var batch = 0; batch < Players; batch += 1_000)
        {
            await using var scope = Factory.Services.CreateAsyncScope();
            var db = scope.ServiceProvider.GetRequiredService<CommunityDbContext>();
            for (var i = batch; i < batch + 1_000; i++)
            {
                var id = Guid.NewGuid();
                playerIds.Add(id);
                var level = (LevelTier)(1 + random.Next(5));
                db.PlayerProfiles.Add(PlayerProfile.Create(id, $"بازیکن {i}", random.Next(4) == 0 ? Gender.Female : Gender.Male, new DateOnly(1990, 1, 1).AddDays(random.Next(5000)),
                    today, cityId, null, [new SportProfile(tennis, level, ExperienceBand.OneToThreeYears, [PlayFormat.Singles, PlayFormat.Doubles], PlayGoals.FriendlyMatch)], now));
                for (var w = 0; w < WindowsPerPlayer; w++)
                {
                    var start = 6 * 60 + random.Next(28) * 30;
                    var window = TimeWindow.Create(start, Math.Min(start + 60 + random.Next(6) * 30, TimeWindow.EndOfDay));
                    var schedule = AvailabilitySchedule.Recurring((IranianWeekdays)(1 << random.Next(7)) | (IranianWeekdays)(1 << random.Next(7)), window, null, today);
                    db.Availability.Add(Availability.Create(id, tennis, cityId, schedule, [venues[random.Next(venues.Count)], venues[random.Next(venues.Count)]],
                        [PlayFormat.Singles], null, now));
                }
            }

            await db.SaveChangesAsync();
        }

        var terms = MatchTerms.Create(LevelTier.Beginner, LevelTier.Professional, PartnerGender.Any, true, null, null);
        for (var batch = 0; batch < Posts; batch += 1_000)
        {
            await using var scope = Factory.Services.CreateAsyncScope();
            var db = scope.ServiceProvider.GetRequiredService<CommunityDbContext>();
            for (var i = batch; i < batch + 1_000; i++)
            {
                var startsAt = now.Date.AddDays(1 + random.Next(29)).AddHours(2.5 + random.Next(30) * 0.5);
                var slot = MatchSlot.Create(tennis, PlayFormat.Singles, 2, venues[random.Next(venues.Count)], cityId, startsAt, 90, now);
                db.Matches.Add(Match.CreatePost(playerIds[random.Next(playerIds.Count)], slot, terms, 0, now));
            }

            await db.SaveChangesAsync();
        }
    }
}
