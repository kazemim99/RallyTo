using Rallyto.Notifications.Domain;

namespace Rallyto.Notifications.Application.Abstractions;

/// <summary>What the gateway said about one send.</summary>
/// <param name="TokenIsDead">The token will never work again (app uninstalled or token rotated), as opposed to a transient failure.</param>
public sealed record PushSendResult(bool Success, string? MessageId, string? ErrorMessage, bool TokenIsDead = false);

/// <summary>The boundary with Firebase Cloud Messaging, ported from AsanRezerve's <c>IFirebaseMessagingGateway</c>.</summary>
public interface IPushGateway
{
    /// <summary>False when this environment has no credentials. Sends are then skipped, never faked.</summary>
    bool IsConfigured { get; }

    Task<PushSendResult> SendAsync(string deviceToken, string title, string body, IReadOnlyDictionary<string, string> data, CancellationToken cancellationToken = default);
}

/// <summary>A match as the notification texts need it, read in-process from Community and Catalog (design D3).</summary>
public sealed record MatchSummary(Guid MatchId, string SportName, string VenueName, DateTime StartsAt, Guid HostId, IReadOnlyList<Guid> PlayerIds);

public interface INotificationContextReader
{
    Task<MatchSummary?> MatchAsync(Guid matchId, CancellationToken cancellationToken);
    Task<IReadOnlyDictionary<Guid, string>> DisplayNamesAsync(IReadOnlyCollection<Guid> userIds, CancellationToken cancellationToken);

    /// <summary>Live matches at a venue that have not started, for the venue-hidden notice.</summary>
    Task<IReadOnlyList<MatchSummary>> FutureMatchesAtVenueAsync(Guid venueId, DateTime now, CancellationToken cancellationToken);

    /// <summary>Confirmed matches starting in <c>(from, to]</c>, for the 2-hour reminder.</summary>
    Task<IReadOnlyList<MatchSummary>> ConfirmedStartingAsync(DateTime from, DateTime to, CancellationToken cancellationToken);
}

public interface INotificationRepository
{
    Task<bool> ExistsAsync(Guid sourceEventId, Guid recipientId, CancellationToken cancellationToken);
    Task<Notification?> GetAsync(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyList<Notification>> InboxAsync(Guid recipientId, int skip, int take, CancellationToken cancellationToken);
    Task<int> CountInboxAsync(Guid recipientId, CancellationToken cancellationToken);
    Task<int> UnreadCountAsync(Guid recipientId, CancellationToken cancellationToken);
    Task MarkAllReadAsync(Guid recipientId, DateTime now, CancellationToken cancellationToken);
    Task<int> PurgeOlderThanAsync(DateTime cutoff, CancellationToken cancellationToken);
    void Add(Notification notification);

    Task<NotificationPreferences?> PreferencesAsync(Guid userId, CancellationToken cancellationToken);
    void Add(NotificationPreferences preferences);

    Task<DeviceToken?> TokenAsync(string token, CancellationToken cancellationToken);
    Task<IReadOnlyList<DeviceToken>> ActiveTokensAsync(Guid userId, CancellationToken cancellationToken);
    Task RevokeAllTokensAsync(Guid userId, string reason, DateTime now, CancellationToken cancellationToken);
    void Add(DeviceToken token);
}
