using Rallyto.Core.Domain.Base;
using Rallyto.Core.Domain.Exceptions;

namespace Rallyto.Notifications.Domain;

/// <summary>The push categories a player can switch off; <see cref="Account"/> notices cannot be switched off.</summary>
public enum NotificationCategory
{
    Matches = 1,
    Chat = 2,
    Ratings = 3,
    SavedSearches = 4,
    Account = 5,
}

/// <summary>
/// One notification for one recipient, created from one source event (design D9). Chat pushes are stored too,
/// outside the inbox, so a redelivered event is never pushed twice.
/// </summary>
public sealed class Notification : AggregateRoot<Guid>
{
    public static readonly TimeSpan Retention = TimeSpan.FromDays(90);

    private Notification() { }

    public Guid RecipientId { get; private set; }
    public Guid SourceEventId { get; private set; }
    public string Code { get; private set; } = string.Empty;
    public NotificationCategory Category { get; private set; }
    public string Title { get; private set; } = string.Empty;
    public string Body { get; private set; } = string.Empty;

    /// <summary>The app route a tap opens, e.g. <c>/matches/{id}</c>.</summary>
    public string? DeepLink { get; private set; }

    /// <summary>False for chat pushes, which the chat unread counts surface instead (spec notifications).</summary>
    public bool InInbox { get; private set; }

    public DateTime NotifiedAt { get; private set; }
    public DateTime? ReadAt { get; private set; }

    public bool IsRead => ReadAt is not null;

    public static Notification Create(Guid recipientId, Guid sourceEventId, string code, NotificationCategory category, string title, string body,
        string? deepLink, bool inInbox, DateTime now) =>
        new()
        {
            Id = Guid.NewGuid(),
            RecipientId = recipientId,
            SourceEventId = sourceEventId,
            Code = code,
            Category = category,
            Title = title,
            Body = body,
            DeepLink = deepLink,
            InInbox = inInbox,
            NotifiedAt = now,
        };

    public void MarkRead(DateTime now) => ReadAt ??= now;
}

/// <summary>A player's push switches and quiet hours, in Tehran local minutes (spec notifications).</summary>
public sealed class NotificationPreferences : Entity<Guid>
{
    public const int DefaultQuietStart = 23 * 60;
    public const int DefaultQuietEnd = 8 * 60;

    private NotificationPreferences() { }

    public bool PushMatches { get; private set; } = true;
    public bool PushChat { get; private set; } = true;
    public bool PushRatings { get; private set; } = true;
    public bool PushSavedSearches { get; private set; } = true;
    public bool QuietHoursEnabled { get; private set; } = true;
    public int QuietStartMinute { get; private set; } = DefaultQuietStart;
    public int QuietEndMinute { get; private set; } = DefaultQuietEnd;

    /// <summary>The defaults, for a player who never changed anything. Keyed by the user id.</summary>
    public static NotificationPreferences DefaultsFor(Guid userId) => new() { Id = userId };

    public void Update(bool matches, bool chat, bool ratings, bool savedSearches, bool quietHoursEnabled, int quietStart, int quietEnd)
    {
        if (quietStart is < 0 or >= 24 * 60 || quietEnd is < 0 or >= 24 * 60 || quietStart % 30 != 0 || quietEnd % 30 != 0)
            throw new BusinessRuleViolationException("INVALID_QUIET_HOURS", "ساعت سکوت باید مضرب ۳۰ دقیقه باشد.");
        if (quietHoursEnabled && quietStart == quietEnd)
            throw new BusinessRuleViolationException("INVALID_QUIET_HOURS", "شروع و پایان ساعت سکوت یکی است.");
        PushMatches = matches;
        PushChat = chat;
        PushRatings = ratings;
        PushSavedSearches = savedSearches;
        QuietHoursEnabled = quietHoursEnabled;
        QuietStartMinute = quietStart;
        QuietEndMinute = quietEnd;
    }

    public bool AllowsPush(NotificationCategory category) => category switch
    {
        NotificationCategory.Matches => PushMatches,
        NotificationCategory.Chat => PushChat,
        NotificationCategory.Ratings => PushRatings,
        NotificationCategory.SavedSearches => PushSavedSearches,
        _ => true,
    };

    /// <summary>Whether a Tehran local minute falls in the quiet window, which may span midnight.</summary>
    public bool IsQuiet(int localMinute) =>
        QuietHoursEnabled && (QuietStartMinute < QuietEndMinute
            ? localMinute >= QuietStartMinute && localMinute < QuietEndMinute
            : localMinute >= QuietStartMinute || localMinute < QuietEndMinute);
}

/// <summary>
/// spec notifications › Notification preferences, Quiet hours. Account notices ignore the category switches;
/// match reminders and imminent cancellations ignore quiet hours. The inbox entry is created in every case.
/// </summary>
public static class PushPolicy
{
    public static bool ShouldPush(NotificationCategory category, bool quietExempt, NotificationPreferences preferences, int localMinute) =>
        preferences.AllowsPush(category) && (quietExempt || !preferences.IsQuiet(localMinute));
}

/// <summary>An FCM registration token. It belongs to one account at a time (spec notifications › Device token registration).</summary>
public sealed class DeviceToken : Entity<Guid>
{
    public const int MaxTokenLength = 4096;

    private DeviceToken() { }

    public Guid UserId { get; private set; }
    public string Token { get; private set; } = string.Empty;
    public string Platform { get; private set; } = string.Empty;
    public DateTime RegisteredAt { get; private set; }
    public DateTime? RevokedAt { get; private set; }
    public string? RevokedReason { get; private set; }

    public bool IsActive => RevokedAt is null;

    public static DeviceToken Register(Guid userId, string token, string? platform, DateTime now)
    {
        var value = token?.Trim() ?? string.Empty;
        if (value.Length is 0 or > MaxTokenLength)
            throw new BusinessRuleViolationException("INVALID_DEVICE_TOKEN", "شناسهٔ دستگاه معتبر نیست.");
        return new DeviceToken { Id = Guid.NewGuid(), UserId = userId, Token = value, Platform = NormalisePlatform(platform), RegisteredAt = now };
    }

    /// <summary>The same token registered by another account (or again) moves to it and becomes active.</summary>
    public void AssignTo(Guid userId, string? platform, DateTime now)
    {
        UserId = userId;
        Platform = NormalisePlatform(platform);
        RegisteredAt = now;
        RevokedAt = null;
        RevokedReason = null;
    }

    public void Revoke(string reason, DateTime now)
    {
        if (RevokedAt is not null)
            return;
        RevokedAt = now;
        RevokedReason = reason;
    }

    private static string NormalisePlatform(string? platform) =>
        platform?.Trim().ToLowerInvariant() is "android" or "ios" or "web" ? platform.Trim().ToLowerInvariant() : "android";
}
