using Rallyto.Core.Application.Localization;
using Rallyto.Notifications.Application.Abstractions;
using Rallyto.Notifications.Domain;

namespace Rallyto.Notifications.Application.Catalog;

/// <param name="InInbox">False for chat, which is push only.</param>
/// <param name="QuietExempt">Pushed even in quiet hours (match reminders).</param>
public sealed record NotificationKind(string Code, NotificationCategory Category, bool InInbox = true, bool QuietExempt = false);

/// <summary>
/// Every notification the system sends (spec notifications › Notification catalog): its category, channels and
/// Persian text, with Persian digits and Jalali dates in Tehran time. The idea comes from AsanRezerve's catalog.
/// </summary>
public static class NotificationEventCatalog
{
    public static readonly NotificationKind InvitationReceived = new("invitation-received", NotificationCategory.Matches);
    public static readonly NotificationKind InvitationAnswered = new("invitation-answered", NotificationCategory.Matches);
    public static readonly NotificationKind JoinRequestReceived = new("join-request-received", NotificationCategory.Matches);
    public static readonly NotificationKind JoinRequestAnswered = new("join-request-answered", NotificationCategory.Matches);
    public static readonly NotificationKind MatchConfirmed = new("match-confirmed", NotificationCategory.Matches);
    public static readonly NotificationKind MatchCancelled = new("match-cancelled", NotificationCategory.Matches);

    /// <summary>A cancellation of a match starting within 12 hours ignores quiet hours.</summary>
    public static readonly NotificationKind MatchCancelledSoon = new("match-cancelled", NotificationCategory.Matches, QuietExempt: true);

    public static readonly NotificationKind MatchExpired = new("match-expired", NotificationCategory.Matches);
    public static readonly NotificationKind ParticipantLeft = new("participant-left", NotificationCategory.Matches);
    public static readonly NotificationKind ParticipantRemoved = new("participant-removed", NotificationCategory.Matches);
    public static readonly NotificationKind VenueHidden = new("venue-hidden", NotificationCategory.Matches);
    public static readonly NotificationKind MatchReminder = new("match-reminder", NotificationCategory.Matches, QuietExempt: true);
    public static readonly NotificationKind AttendanceOpened = new("attendance-opened", NotificationCategory.Ratings);
    public static readonly NotificationKind RatingRequested = new("rating-requested", NotificationCategory.Ratings);
    public static readonly NotificationKind RatingReminder = new("rating-reminder", NotificationCategory.Ratings);
    public static readonly NotificationKind SavedSearchMatched = new("saved-search-matched", NotificationCategory.SavedSearches);
    public static readonly NotificationKind AvailabilityReconfirm = new("availability-reconfirm", NotificationCategory.Matches);
    public static readonly NotificationKind AvailabilityPaused = new("availability-paused", NotificationCategory.Matches);
    public static readonly NotificationKind MessageReceived = new("message-received", NotificationCategory.Chat, InInbox: false);
    public static readonly NotificationKind PlayerWarned = new("player-warned", NotificationCategory.Account);
    public static readonly NotificationKind AccountSuspended = new("account-suspended", NotificationCategory.Account);
    public static readonly NotificationKind GenderCorrected = new("gender-corrected", NotificationCategory.Account);

    public static readonly TimeSpan ImminentWindow = TimeSpan.FromHours(12);

    /// <summary>«۱۴۰۵/۰۸/۰۲ ساعت ۱۹:۰۰»</summary>
    public static string When(DateTime startsAtUtc) => $"{PersianFormat.Date(startsAtUtc)} ساعت {PersianFormat.Time(startsAtUtc)}";

    /// <summary>«بازی تنیس در مجموعه تنیس استقلال، ۱۴۰۵/۰۸/۰۲ ساعت ۱۹:۰۰»</summary>
    public static string Game(MatchSummary match) => $"بازی {match.SportName} در {match.VenueName}، {When(match.StartsAt)}";

    /// <summary>«بازی تنیس شما امروز ساعت ۱۹:۰۰ در مجموعه تنیس استقلال» (spec notifications › Persian content).</summary>
    public static string Reminder(MatchSummary match, DateTime nowUtc)
    {
        var day = PersianFormat.TehranToday(match.StartsAt) == PersianFormat.TehranToday(nowUtc) ? "امروز" : "فردا";
        return $"بازی {match.SportName} شما {day} ساعت {PersianFormat.Time(match.StartsAt)} در {match.VenueName}";
    }

    public static string MatchLink(Guid matchId) => $"/matches/{matchId}";
}
