using DotNetCore.CAP;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Rallyto.Community.Application.Abstractions;
using Rallyto.Community.Domain.Availabilities;
using Rallyto.Community.Infrastructure.Persistence;
using Rallyto.Contracts.Catalog;
using Rallyto.Contracts.Community;
using Rallyto.Contracts.Identity;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Application.Localization;

namespace Rallyto.Community.Infrastructure.Jobs;

/// <summary>
/// Periodic upkeep of Community (spec availability, spec partner-search): reconfirmation reminders, auto-pause of
/// stale windows, expiry, and saved-search digests. Callable directly from tests.
/// </summary>
public sealed class CommunityMaintenance(
    CommunityDbContext db,
    ICommunityUnitOfWork unitOfWork,
    IIntegrationEventPublisher events,
    TimeProvider clock,
    ILogger<CommunityMaintenance> logger)
{
    /// <summary>Arbitrary but fixed key for <c>pg_try_advisory_lock</c>: only one instance runs the job at a time.</summary>
    private const long LockKey = 7_301_001;

    public async Task RunAsync(CancellationToken cancellationToken)
    {
        await db.Database.OpenConnectionAsync(cancellationToken);
        try
        {
            if (!await TryLockAsync(cancellationToken))
                return;
            await RunLockedAsync(cancellationToken);
        }
        finally
        {
            await db.Database.ExecuteSqlRawAsync("SELECT pg_advisory_unlock({0})", [LockKey], CancellationToken.None);
            await db.Database.CloseConnectionAsync();
        }
    }

    private async Task<bool> TryLockAsync(CancellationToken cancellationToken) =>
        await db.Database.SqlQueryRaw<bool>("SELECT pg_try_advisory_lock({0}) AS \"Value\"", LockKey).SingleAsync(cancellationToken);

    private async Task RunLockedAsync(CancellationToken cancellationToken)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var local = PersianFormat.ToTehran(now);
        var today = DateOnly.FromDateTime(local);
        var minute = local.Hour * 60 + local.Minute;

        var windows = await db.Availability.Where(a => a.Status != AvailabilityStatus.Expired).ToListAsync(cancellationToken);
        int reminded = 0, paused = 0, expired = 0;
        foreach (var window in windows)
        {
            if (window.IsOver(today, minute))
            {
                window.Expire();
                expired++;
            }
            else if (window.IsStale(now))
            {
                window.Pause();
                events.Enqueue(new AvailabilityAutoPaused(window.PlayerId, window.Id));
                paused++;
            }
            else if (window.NeedsReminder(now))
            {
                window.MarkReminderSent(now);
                events.Enqueue(new AvailabilityReconfirmationDue(window.PlayerId, window.Id));
                reminded++;
            }
        }

        // Games whose start time arrived: stop taking players, confirm with 2+ or expire (spec match-lifecycle › Match states).
        var started = await db.Matches
            .Where(m => m.StartsAt <= now
                        && (m.Status == Domain.Matches.MatchStatus.Open || m.Status == Domain.Matches.MatchStatus.Pending
                            || (m.Status == Domain.Matches.MatchStatus.Confirmed
                                && m.Participants.Any(p => p.State == Domain.Matches.ParticipantState.Requested || p.State == Domain.Matches.ParticipantState.Invited))))
            .ToListAsync(cancellationToken);
        foreach (var match in started)
            match.StartReached(now);

        // Games that ended: ask for attendance, and resolve once the 72-hour window has closed (spec match-lifecycle › Attendance confirmation).
        foreach (var match in await db.Matches.Where(m => m.Status == Domain.Matches.MatchStatus.Confirmed && m.EndsAt <= now).ToListAsync(cancellationToken))
        {
            match.OpenAttendance(now);
            match.CloseAttendance(now);
        }

        await RemindToRateAsync(now, cancellationToken);

        // Double-blind ratings still hidden when their window closes are revealed (spec player-ratings › Double-blind reveal).
        foreach (var rating in await db.Ratings.Where(r => r.RevealedAt == null && r.WindowClosesAt <= now).ToListAsync(cancellationToken))
            rating.Reveal(now);

        foreach (var search in await db.SavedSearches.Where(s => s.PendingMatches > 0).ToListAsync(cancellationToken))
        {
            var count = search.FlushDigest(now);
            if (count > 0)
                events.Enqueue(new SavedSearchMatched(search.OwnerId, search.Id, search.Name, count));
        }

        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        if (reminded + paused + expired > 0)
            logger.LogInformation("Availability upkeep: {Reminded} reminded, {Paused} paused, {Expired} expired", reminded, paused, expired);
    }

    /// <summary>One reminder, on day 5, to each Played participant who has not rated every partner (spec player-ratings › Rating prompts).</summary>
    private async Task RemindToRateAsync(DateTime now, CancellationToken cancellationToken)
    {
        var due = now - Domain.Matches.Match.RatingReminderAfter;
        var matches = await db.Matches
            .Where(m => m.Status == Domain.Matches.MatchStatus.Completed && m.RatingRemindersSentAt == null && m.ResolvedAt <= due)
            .ToListAsync(cancellationToken);
        foreach (var match in matches)
        {
            if (!match.MarkRatingRemindersSent(now))
                continue;
            var given = await db.Ratings.Where(r => r.MatchId == match.Id).Select(r => new { r.RaterId, r.RateeId }).ToListAsync(cancellationToken);
            foreach (var player in match.PlayerIds())
            {
                var pending = match.RateablePartnersOf(player, now).Where(p => !given.Any(g => g.RaterId == player && g.RateeId == p)).ToList();
                if (pending.Count > 0)
                    events.Enqueue(new RatingReminderDue(match.Id, player, pending));
            }
        }
    }
}

/// <summary>Runs <see cref="CommunityMaintenance"/> hourly. Disabled with <c>Workers:Enabled=false</c> (tests run it by hand).</summary>
public sealed class CommunityMaintenanceWorker(IServiceScopeFactory scopes, IConfiguration configuration, ILogger<CommunityMaintenanceWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!configuration.GetValue("Workers:Enabled", true))
            return;
        using var timer = new PeriodicTimer(TimeSpan.FromHours(1));
        do
        {
            try
            {
                await using var scope = scopes.CreateAsyncScope();
                await scope.ServiceProvider.GetRequiredService<CommunityMaintenance>().RunAsync(stoppingToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                logger.LogError(ex, "Community maintenance failed; retrying next hour");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}

/// <summary>A club was hidden: drop it from every window; windows left without a club pause (spec availability).</summary>
public sealed class VenueHiddenSubscriber(IAvailabilityRepository windows, ICommunityUnitOfWork unitOfWork) : ICapSubscribe
{
    [CapSubscribe(CatalogTopics.VenueHidden, Group = CommunityModule.CapGroup)]
    public async Task OnVenueHidden(VenueHidden message)
    {
        foreach (var window in await windows.ListContainingVenueAsync(message.VenueId, CancellationToken.None))
            window.RemoveVenue(message.VenueId);
        await unitOfWork.SaveAndPublishEventsAsync();
    }
}
