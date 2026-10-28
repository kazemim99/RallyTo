using DotNetCore.CAP;
using Rallyto.Contracts.Catalog;
using Rallyto.Contracts.Community;
using Rallyto.Contracts.Identity;
using Rallyto.Contracts.Messaging;
using Rallyto.Notifications.Application.Abstractions;
using Rallyto.Notifications.Application.Delivery;

namespace Rallyto.Notifications.Infrastructure;

/// <summary>Every event of the notification catalog (spec notifications); deduplication happens in the dispatcher.</summary>
public sealed class NotificationSubscribers(NotificationComposer composer, NotificationDispatcher dispatcher, INotificationRepository repository, TimeProvider clock)
    : ICapSubscribe
{
    private const string Group = NotificationsModule.CapGroup;
    private static readonly CancellationToken None = CancellationToken.None;

    [CapSubscribe(MatchTopics.InvitationReceived, Group = Group)]
    public async Task OnInvitationReceived(InvitationReceived e) => await SendAsync(await composer.InvitationReceivedAsync(e, None));

    [CapSubscribe(MatchTopics.InvitationAnswered, Group = Group)]
    public async Task OnInvitationAnswered(InvitationAnswered e) => await SendAsync(await composer.InvitationAnsweredAsync(e, None));

    [CapSubscribe(MatchTopics.JoinRequestReceived, Group = Group)]
    public async Task OnJoinRequestReceived(JoinRequestReceived e) => await SendAsync(await composer.JoinRequestReceivedAsync(e, None));

    [CapSubscribe(MatchTopics.JoinRequestAnswered, Group = Group)]
    public async Task OnJoinRequestAnswered(JoinRequestAnswered e) => await SendAsync(await composer.JoinRequestAnsweredAsync(e, None));

    [CapSubscribe(MatchTopics.MatchConfirmed, Group = Group)]
    public async Task OnMatchConfirmed(MatchConfirmed e) => await SendAsync(await composer.MatchConfirmedAsync(e, None));

    [CapSubscribe(MatchTopics.MatchCancelled, Group = Group)]
    public async Task OnMatchCancelled(MatchCancelled e) => await SendAsync(await composer.MatchCancelledAsync(e, None));

    [CapSubscribe(MatchTopics.MatchExpired, Group = Group)]
    public async Task OnMatchExpired(MatchExpired e) => await SendAsync(await composer.MatchExpiredAsync(e, None));

    [CapSubscribe(MatchTopics.ParticipantLeft, Group = Group)]
    public async Task OnParticipantLeft(ParticipantLeft e) => await SendAsync(await composer.ParticipantLeftAsync(e, None));

    [CapSubscribe(MatchTopics.ParticipantRemoved, Group = Group)]
    public async Task OnParticipantRemoved(ParticipantRemoved e) => await SendAsync(await composer.ParticipantRemovedAsync(e, None));

    [CapSubscribe(MatchTopics.AttendanceOpened, Group = Group)]
    public async Task OnAttendanceOpened(AttendanceOpened e) => await SendAsync(await composer.AttendanceOpenedAsync(e, None));

    [CapSubscribe(MatchTopics.MatchResolved, Group = Group)]
    public async Task OnMatchResolved(MatchResolved e) => await SendAsync(await composer.MatchResolvedAsync(e, None));

    [CapSubscribe(MatchTopics.RatingReminderDue, Group = Group)]
    public async Task OnRatingReminderDue(RatingReminderDue e) => await SendAsync(await composer.RatingReminderAsync(e, None));

    [CapSubscribe(CatalogTopics.VenueHidden, Group = Group)]
    public async Task OnVenueHidden(VenueHidden e)
    {
        foreach (var request in await composer.VenueHiddenAsync(e.EventId, e.VenueId, None))
            await SendAsync(request);
    }

    [CapSubscribe(AvailabilityTopics.SavedSearchMatched, Group = Group)]
    public Task OnSavedSearchMatched(SavedSearchMatched e) => SendAsync(composer.SavedSearchMatched(e));

    [CapSubscribe(AvailabilityTopics.ReconfirmationDue, Group = Group)]
    public Task OnReconfirmationDue(AvailabilityReconfirmationDue e) => SendAsync(composer.AvailabilityReconfirm(e));

    [CapSubscribe(AvailabilityTopics.AutoPaused, Group = Group)]
    public Task OnAutoPaused(AvailabilityAutoPaused e) => SendAsync(composer.AvailabilityPaused(e));

    [CapSubscribe(MessagingTopics.MessageReceivedOffline, Group = Group)]
    public Task OnMessageReceivedOffline(MessageReceivedOffline e) => SendAsync(composer.MessageReceived(e));

    [CapSubscribe(SafetyTopics.PlayerWarned, Group = Group)]
    public Task OnPlayerWarned(PlayerWarned e) => SendAsync(composer.PlayerWarned(e));

    [CapSubscribe(CommunityTopics.GenderCorrected, Group = Group)]
    public Task OnGenderCorrected(GenderCorrected e) => SendAsync(composer.GenderCorrected(e));

    /// <summary>The player is told the end date and reason first; then their devices stop receiving pushes (spec notifications).</summary>
    [CapSubscribe(IdentityTopics.AccountSuspended, Group = Group)]
    public async Task OnAccountSuspended(AccountSuspended e)
    {
        await SendAsync(composer.AccountSuspended(e));
        await repository.RevokeAllTokensAsync(e.UserId, "account suspended", clock.GetUtcNow().UtcDateTime, None);
    }

    [CapSubscribe(IdentityTopics.AccountBanned, Group = Group)]
    public Task OnAccountBanned(AccountBanned e) => repository.RevokeAllTokensAsync(e.UserId, "account banned", clock.GetUtcNow().UtcDateTime, None);

    [CapSubscribe(IdentityTopics.AccountDeleted, Group = Group)]
    public Task OnAccountDeleted(AccountDeleted e) => repository.RevokeAllTokensAsync(e.UserId, "account deleted", clock.GetUtcNow().UtcDateTime, None);

    private Task SendAsync(NotificationRequest? request) => request is null ? Task.CompletedTask : dispatcher.DispatchAsync(request, None);
}
