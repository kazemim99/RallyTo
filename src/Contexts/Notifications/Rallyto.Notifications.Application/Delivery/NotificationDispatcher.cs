using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Logging;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Application.Localization;
using Rallyto.Notifications.Application.Abstractions;
using Rallyto.Notifications.Application.Catalog;
using Rallyto.Notifications.Domain;

namespace Rallyto.Notifications.Application.Delivery;

/// <summary>One notification to one or more recipients, from one source event.</summary>
public sealed record NotificationRequest(Guid SourceEventId, NotificationKind Kind, IReadOnlyCollection<Guid> RecipientIds, string Title, string Body, string? DeepLink);

public sealed record NotificationView(Guid Id, string Code, NotificationCategory Category, string Title, string Body, string? DeepLink, DateTime CreatedAt, bool IsRead);

public static class NotificationEvents
{
    /// <summary>Realtime event on <c>/hubs/realtime</c>: the new item and the new unread count (spec notifications › Real-time inbox updates).</summary>
    public const string Created = "notification.created";

    public static NotificationView View(Notification n) => new(n.Id, n.Code, n.Category, n.Title, n.Body, n.DeepLink, n.NotifiedAt, n.IsRead);

    /// <summary>A stable id for a notification derived from one source, e.g. one reminder per match.</summary>
    public static Guid DerivedId(Guid source, string discriminator) =>
        new(MD5.HashData(Encoding.UTF8.GetBytes($"{source:N}:{discriminator}")));
}

/// <summary>
/// The single send path (design D9): stores every notification first, deduplicated on (source event, recipient),
/// then updates online clients and pushes to active devices within the recipient's preferences. A push failure
/// never touches the stored notification.
/// </summary>
public sealed class NotificationDispatcher(
    INotificationRepository repository,
    INotificationsUnitOfWork unitOfWork,
    IPushGateway push,
    IRealtimePublisher realtime,
    TimeProvider clock,
    ILogger<NotificationDispatcher> logger)
{
    public async Task DispatchAsync(NotificationRequest request, CancellationToken cancellationToken)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var created = new List<Notification>();
        foreach (var recipient in request.RecipientIds.Distinct())
        {
            if (await repository.ExistsAsync(request.SourceEventId, recipient, cancellationToken))
                continue;
            var notification = Notification.Create(recipient, request.SourceEventId, request.Kind.Code, request.Kind.Category, request.Title, request.Body,
                request.DeepLink, request.Kind.InInbox, now);
            repository.Add(notification);
            created.Add(notification);
        }

        if (created.Count == 0)
            return;
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);

        var local = PersianFormat.ToTehran(now);
        var revoked = false;
        foreach (var notification in created)
        {
            if (notification.InInbox)
            {
                var unread = await repository.UnreadCountAsync(notification.RecipientId, cancellationToken);
                await realtime.PublishToUsersAsync([notification.RecipientId], NotificationEvents.Created,
                    new { notification = NotificationEvents.View(notification), unreadCount = unread }, cancellationToken);
            }

            revoked |= await PushAsync(notification, request.Kind, local.Hour * 60 + local.Minute, now, cancellationToken);
        }

        if (revoked)
            await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
    }

    /// <returns>Whether a dead token was revoked.</returns>
    private async Task<bool> PushAsync(Notification notification, NotificationKind kind, int localMinute, DateTime now, CancellationToken cancellationToken)
    {
        if (!push.IsConfigured)
            return false;
        var preferences = await repository.PreferencesAsync(notification.RecipientId, cancellationToken) ?? NotificationPreferences.DefaultsFor(notification.RecipientId);
        if (!PushPolicy.ShouldPush(kind.Category, kind.QuietExempt, preferences, localMinute))
            return false;
        var data = new Dictionary<string, string>
        {
            ["notificationId"] = notification.Id.ToString(),
            ["code"] = notification.Code,
            ["deepLink"] = notification.DeepLink ?? string.Empty,
        };
        var revoked = false;
        foreach (var device in await repository.ActiveTokensAsync(notification.RecipientId, cancellationToken))
        {
            var result = await push.SendAsync(device.Token, notification.Title, notification.Body, data, cancellationToken);
            if (result.TokenIsDead)
            {
                device.Revoke("rejected by FCM", now);
                revoked = true;
            }
            else if (!result.Success)
            {
                logger.LogWarning("Push {Code} to a device of {UserId} failed: {Error}", notification.Code, notification.RecipientId, result.ErrorMessage);
            }
        }

        return revoked;
    }
}
