using Rallyto.Contracts.Community;
using Rallyto.Contracts.Identity;
using Rallyto.Contracts.Messaging;
using Rallyto.Core.Application.Localization;
using Rallyto.Notifications.Application.Abstractions;
using C = Rallyto.Notifications.Application.Catalog.NotificationEventCatalog;

namespace Rallyto.Notifications.Application.Delivery;

/// <summary>Turns each integration event into the notification of the catalog, with its Persian text and deep link.</summary>
public sealed class NotificationComposer(INotificationContextReader context, TimeProvider clock)
{
    private DateTime Now => clock.GetUtcNow().UtcDateTime;

    public async Task<NotificationRequest?> InvitationReceivedAsync(InvitationReceived e, CancellationToken ct) =>
        await ForMatchAsync(e.MatchId, ct, async m =>
            new NotificationRequest(e.EventId, C.InvitationReceived, [e.PlayerId], "دعوت به بازی", $"{await NameAsync(e.HostId, ct)} شما را به {C.Game(m)} دعوت کرد.", C.MatchLink(m.MatchId)));

    public async Task<NotificationRequest?> InvitationAnsweredAsync(InvitationAnswered e, CancellationToken ct) =>
        await ForMatchAsync(e.MatchId, ct, async m =>
            new NotificationRequest(e.EventId, C.InvitationAnswered, [e.HostId], e.Accepted ? "دعوت پذیرفته شد" : "دعوت رد شد",
                $"{await NameAsync(e.PlayerId, ct)} دعوت شما به {C.Game(m)} را {(e.Accepted ? "پذیرفت" : "رد کرد")}.", C.MatchLink(m.MatchId)));

    public async Task<NotificationRequest?> JoinRequestReceivedAsync(JoinRequestReceived e, CancellationToken ct) =>
        await ForMatchAsync(e.MatchId, ct, async m =>
            new NotificationRequest(e.EventId, C.JoinRequestReceived, [e.HostId], "درخواست پیوستن", $"{await NameAsync(e.PlayerId, ct)} می‌خواهد به {C.Game(m)} بپیوندد.", C.MatchLink(m.MatchId)));

    public async Task<NotificationRequest?> JoinRequestAnsweredAsync(JoinRequestAnswered e, CancellationToken ct) =>
        await ForMatchAsync(e.MatchId, ct, m => Task.FromResult(
            new NotificationRequest(e.EventId, C.JoinRequestAnswered, [e.PlayerId], e.Accepted ? "درخواست پذیرفته شد" : "درخواست رد شد",
                $"درخواست شما برای {C.Game(m)} {(e.Accepted ? "پذیرفته شد" : "پذیرفته نشد")}.", C.MatchLink(m.MatchId))));

    public async Task<NotificationRequest?> MatchConfirmedAsync(MatchConfirmed e, CancellationToken ct) =>
        await ForMatchAsync(e.MatchId, ct, m => Task.FromResult(
            new NotificationRequest(e.EventId, C.MatchConfirmed, e.PlayerIds, "بازی قطعی شد", $"{C.Game(m)} قطعی شد.", C.MatchLink(m.MatchId))));

    /// <summary>The host cancelled; the others are told, immediately even in quiet hours when the game was within 12 hours.</summary>
    public async Task<NotificationRequest?> MatchCancelledAsync(MatchCancelled e, CancellationToken ct) =>
        await ForMatchAsync(e.MatchId, ct, m => Task.FromResult(
            new NotificationRequest(e.EventId, e.StartsAt - Now < C.ImminentWindow ? C.MatchCancelledSoon : C.MatchCancelled, e.PlayerIds.Where(id => id != e.HostId).ToList(),
                "بازی لغو شد", $"{C.Game(m)} لغو شد.{(string.IsNullOrWhiteSpace(e.Reason) ? string.Empty : $" دلیل: {e.Reason}")}", C.MatchLink(m.MatchId))));

    public async Task<NotificationRequest?> MatchExpiredAsync(MatchExpired e, CancellationToken ct) =>
        await ForMatchAsync(e.MatchId, ct, m => Task.FromResult(
            new NotificationRequest(e.EventId, C.MatchExpired, [e.HostId], "بازی منقضی شد", $"برای {C.Game(m)} هم‌بازی پیدا نشد.", C.MatchLink(m.MatchId))));

    public async Task<NotificationRequest?> ParticipantLeftAsync(ParticipantLeft e, CancellationToken ct) =>
        await ForMatchAsync(e.MatchId, ct, async m =>
            new NotificationRequest(e.EventId, C.ParticipantLeft, e.RemainingPlayerIds, "انصراف از بازی", $"{await NameAsync(e.PlayerId, ct)} از {C.Game(m)} انصراف داد.", C.MatchLink(m.MatchId)));

    public async Task<NotificationRequest?> ParticipantRemovedAsync(ParticipantRemoved e, CancellationToken ct) =>
        await ForMatchAsync(e.MatchId, ct, m => Task.FromResult(
            new NotificationRequest(e.EventId, C.ParticipantRemoved, [e.PlayerId], "حذف از بازی", $"شما دیگر در {C.Game(m)} نیستید.", C.MatchLink(m.MatchId))));

    public async Task<NotificationRequest?> AttendanceOpenedAsync(AttendanceOpened e, CancellationToken ct) =>
        await ForMatchAsync(e.MatchId, ct, m => Task.FromResult(
            new NotificationRequest(e.EventId, C.AttendanceOpened, e.PlayerIds, "بازی انجام شد؟", $"{C.Game(m)} انجام شد؟ حضور را اعلام کنید.", C.MatchLink(m.MatchId))));

    public async Task<NotificationRequest?> MatchResolvedAsync(MatchResolved e, CancellationToken ct) =>
        e.Outcome != "Completed" || e.PlayedIds.Count < 2
            ? null
            : await ForMatchAsync(e.MatchId, ct, m => Task.FromResult(
                new NotificationRequest(e.EventId, C.RatingRequested, e.PlayedIds, "امتیاز به هم‌بازی‌ها", $"به هم‌بازی‌های {C.Game(m)} امتیاز بدهید.", C.MatchLink(m.MatchId))));

    public async Task<NotificationRequest?> RatingReminderAsync(RatingReminderDue e, CancellationToken ct) =>
        await ForMatchAsync(e.MatchId, ct, m => Task.FromResult(
            new NotificationRequest(e.EventId, C.RatingReminder, [e.PlayerId], "یادآوری امتیاز", $"هنوز به هم‌بازی‌های {C.Game(m)} امتیاز نداده‌اید.", C.MatchLink(m.MatchId))));

    public NotificationRequest SavedSearchMatched(SavedSearchMatched e) =>
        new(e.EventId, C.SavedSearchMatched, [e.UserId], "هم‌بازی جدید",
            $"{PersianFormat.Digits(e.MatchCount.ToString(System.Globalization.CultureInfo.InvariantCulture))} مورد جدید برای جستجوی «{e.SearchName}» پیدا شد.", $"/saved-searches/{e.SavedSearchId}");

    public NotificationRequest AvailabilityReconfirm(AvailabilityReconfirmationDue e) =>
        new(e.EventId, C.AvailabilityReconfirm, [e.UserId], "هنوز آزادید؟", "زمان آزاد شما به‌زودی متوقف می‌شود. اگر هنوز در این زمان بازی می‌کنید، تأیید کنید.", "/availability");

    public NotificationRequest AvailabilityPaused(AvailabilityAutoPaused e) =>
        new(e.EventId, C.AvailabilityPaused, [e.UserId], "زمان آزاد متوقف شد", "زمان آزاد شما چون تأیید نشد متوقف شد. هر وقت خواستید دوباره فعالش کنید.", "/availability");

    public NotificationRequest MessageReceived(MessageReceivedOffline e) =>
        new(e.EventId, C.MessageReceived, [e.RecipientId], e.IsRequest ? $"درخواست پیام از {e.SenderName}" : e.SenderName, e.Preview, $"/chat/{e.ConversationId}");

    public NotificationRequest PlayerWarned(PlayerWarned e) => new(e.EventId, C.PlayerWarned, [e.UserId], "اخطار", e.Text, null);

    public NotificationRequest AccountSuspended(AccountSuspended e) =>
        new(e.EventId, C.AccountSuspended, [e.UserId], "تعلیق حساب",
            $"حساب شما تا {PersianFormat.Date(e.SuspendedUntil.AddMinutes(-1))} معلق شد. دلیل: {e.Reason}", null);

    public NotificationRequest GenderCorrected(GenderCorrected e) =>
        new(e.EventId, C.GenderCorrected, [e.UserId], "اصلاح پروفایل", $"جنسیت در پروفایل شما اصلاح شد. دلیل: {e.Reason}", "/profile");

    /// <summary>One notice per future match at the hidden venue, each deduplicated separately.</summary>
    public async Task<IReadOnlyList<NotificationRequest>> VenueHiddenAsync(Guid eventId, Guid venueId, CancellationToken ct) =>
        (await context.FutureMatchesAtVenueAsync(venueId, Now, ct))
        .Select(m => new NotificationRequest(NotificationEvents.DerivedId(eventId, m.MatchId.ToString()), C.VenueHidden, m.PlayerIds, "باشگاه در دسترس نیست",
            $"باشگاه {m.VenueName} دیگر در فهرست نیست. وضعیت {C.Game(m)} را با میزبان هماهنگ کنید.", C.MatchLink(m.MatchId)))
        .ToList();

    public NotificationRequest Reminder(MatchSummary m) =>
        new(NotificationEvents.DerivedId(m.MatchId, "reminder"), C.MatchReminder, m.PlayerIds, "یادآوری بازی", C.Reminder(m, Now), C.MatchLink(m.MatchId));

    private async Task<NotificationRequest?> ForMatchAsync(Guid matchId, CancellationToken ct, Func<MatchSummary, Task<NotificationRequest>> build) =>
        await context.MatchAsync(matchId, ct) is { } match ? await build(match) : null;

    private async Task<string> NameAsync(Guid userId, CancellationToken ct) =>
        (await context.DisplayNamesAsync([userId], ct)).GetValueOrDefault(userId, "یک بازیکن");
}
