using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Rallyto.Notifications.Application.Abstractions;
using Rallyto.Notifications.Application.Delivery;
using Rallyto.Notifications.Domain;
using Rallyto.Notifications.Infrastructure.Persistence;

namespace Rallyto.Notifications.Infrastructure;

/// <summary>Timed notifications and upkeep: match reminders 2 hours before start, and the 90-day inbox retention. Callable from tests.</summary>
public sealed class NotificationsMaintenance(
    NotificationsDbContext db,
    INotificationContextReader context,
    INotificationRepository repository,
    NotificationComposer composer,
    NotificationDispatcher dispatcher,
    TimeProvider clock,
    ILogger<NotificationsMaintenance> logger)
{
    public static readonly TimeSpan ReminderLead = TimeSpan.FromHours(2);

    /// <summary>Fixed key for <c>pg_try_advisory_lock</c>: only one instance runs the job at a time.</summary>
    private const long LockKey = 7_301_002;

    public async Task RunAsync(CancellationToken cancellationToken)
    {
        await db.Database.OpenConnectionAsync(cancellationToken);
        try
        {
            if (!await db.Database.SqlQueryRaw<bool>("SELECT pg_try_advisory_lock({0}) AS \"Value\"", LockKey).SingleAsync(cancellationToken))
                return;
            var now = clock.GetUtcNow().UtcDateTime;
            // Reminders carry an id derived from the match, so a match is reminded once however often this runs.
            foreach (var match in await context.ConfirmedStartingAsync(now, now + ReminderLead, cancellationToken))
                await dispatcher.DispatchAsync(composer.Reminder(match), cancellationToken);
            var purged = await repository.PurgeOlderThanAsync(now - Notification.Retention, cancellationToken);
            if (purged > 0)
                logger.LogInformation("Removed {Count} notifications older than 90 days", purged);
        }
        finally
        {
            await db.Database.ExecuteSqlRawAsync("SELECT pg_advisory_unlock({0})", [LockKey], CancellationToken.None);
            await db.Database.CloseConnectionAsync();
        }
    }
}

/// <summary>Runs <see cref="NotificationsMaintenance"/> every 5 minutes. Disabled with <c>Workers:Enabled=false</c>.</summary>
public sealed class NotificationsMaintenanceWorker(IServiceScopeFactory scopes, IConfiguration configuration, ILogger<NotificationsMaintenanceWorker> logger) : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromMinutes(5);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!configuration.GetValue("Workers:Enabled", true))
            return;
        using var timer = new PeriodicTimer(Interval);
        do
        {
            try
            {
                await using var scope = scopes.CreateAsyncScope();
                await scope.ServiceProvider.GetRequiredService<NotificationsMaintenance>().RunAsync(stoppingToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                logger.LogError(ex, "Notifications maintenance failed");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
