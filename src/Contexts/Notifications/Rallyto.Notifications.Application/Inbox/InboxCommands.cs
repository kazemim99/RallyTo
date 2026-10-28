using System.Globalization;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Core.Application.Results;
using Rallyto.Notifications.Application.Abstractions;
using Rallyto.Notifications.Application.Delivery;
using Rallyto.Notifications.Domain;

namespace Rallyto.Notifications.Application.Inbox;

public sealed record UnreadCountView(int Count);

/// <summary>Quiet hours as "HH:mm", Tehran time.</summary>
public sealed record PreferencesView(bool PushMatches, bool PushChat, bool PushRatings, bool PushSavedSearches, bool QuietHoursEnabled, string QuietStart, string QuietEnd);

public sealed record ListInboxQuery(int Page = 1, int PageSize = 20) : IQuery<PagedResult<NotificationView>>;

public sealed record GetUnreadCountQuery : IQuery<UnreadCountView>;

public sealed record MarkNotificationReadCommand(Guid NotificationId) : ICommand;

public sealed record MarkAllReadCommand : ICommand;

public sealed record GetPreferencesQuery : IQuery<PreferencesView>;

public sealed record UpdatePreferencesCommand(bool PushMatches, bool PushChat, bool PushRatings, bool PushSavedSearches, bool QuietHoursEnabled, string QuietStart, string QuietEnd)
    : ICommand<PreferencesView>;

public sealed record RegisterDeviceTokenCommand(string Token, string? Platform) : ICommand;

public sealed record UnregisterDeviceTokenCommand(string Token) : ICommand;

internal static class PreferencesMapping
{
    public static PreferencesView ToView(NotificationPreferences p) =>
        new(p.PushMatches, p.PushChat, p.PushRatings, p.PushSavedSearches, p.QuietHoursEnabled, Clock(p.QuietStartMinute), Clock(p.QuietEndMinute));

    public static string Clock(int minute) => $"{minute / 60:00}:{minute % 60:00}";

    public static int Minute(string? text) =>
        TimeOnly.TryParseExact(text, "HH:mm", CultureInfo.InvariantCulture, DateTimeStyles.None, out var time)
            ? time.Hour * 60 + time.Minute
            : throw new ValidationFailedException("INVALID_QUIET_HOURS", "ساعت سکوت معتبر نیست.");
}

internal sealed class ListInboxHandler(ICurrentUserService currentUser, INotificationRepository notifications) : IQueryHandler<ListInboxQuery, PagedResult<NotificationView>>
{
    public async Task<PagedResult<NotificationView>> Handle(ListInboxQuery request, CancellationToken cancellationToken)
    {
        var me = currentUser.RequireUserId();
        var page = Math.Max(1, request.Page);
        var size = Math.Clamp(request.PageSize, 1, 100);
        var items = await notifications.InboxAsync(me, (page - 1) * size, size, cancellationToken);
        return new PagedResult<NotificationView>(items.Select(NotificationEvents.View).ToList(), page, size, await notifications.CountInboxAsync(me, cancellationToken));
    }
}

internal sealed class GetUnreadCountHandler(ICurrentUserService currentUser, INotificationRepository notifications) : IQueryHandler<GetUnreadCountQuery, UnreadCountView>
{
    public async Task<UnreadCountView> Handle(GetUnreadCountQuery request, CancellationToken cancellationToken) =>
        new(await notifications.UnreadCountAsync(currentUser.RequireUserId(), cancellationToken));
}

internal sealed class MarkNotificationReadHandler(ICurrentUserService currentUser, INotificationRepository notifications, INotificationsUnitOfWork unitOfWork, TimeProvider clock)
    : ICommandHandler<MarkNotificationReadCommand>
{
    public async Task Handle(MarkNotificationReadCommand request, CancellationToken cancellationToken)
    {
        var notification = await notifications.GetAsync(request.NotificationId, cancellationToken);
        if (notification is null || notification.RecipientId != currentUser.RequireUserId() || !notification.InInbox)
            throw new NotFoundException("اعلان پیدا نشد.", "NOTIFICATION_NOT_FOUND");
        notification.MarkRead(clock.GetUtcNow().UtcDateTime);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
    }
}

internal sealed class MarkAllReadHandler(ICurrentUserService currentUser, INotificationRepository notifications, TimeProvider clock) : ICommandHandler<MarkAllReadCommand>
{
    public Task Handle(MarkAllReadCommand request, CancellationToken cancellationToken) =>
        notifications.MarkAllReadAsync(currentUser.RequireUserId(), clock.GetUtcNow().UtcDateTime, cancellationToken);
}

internal sealed class GetPreferencesHandler(ICurrentUserService currentUser, INotificationRepository notifications) : IQueryHandler<GetPreferencesQuery, PreferencesView>
{
    public async Task<PreferencesView> Handle(GetPreferencesQuery request, CancellationToken cancellationToken)
    {
        var me = currentUser.RequireUserId();
        return PreferencesMapping.ToView(await notifications.PreferencesAsync(me, cancellationToken) ?? NotificationPreferences.DefaultsFor(me));
    }
}

internal sealed class UpdatePreferencesHandler(ICurrentUserService currentUser, INotificationRepository notifications, INotificationsUnitOfWork unitOfWork)
    : ICommandHandler<UpdatePreferencesCommand, PreferencesView>
{
    public async Task<PreferencesView> Handle(UpdatePreferencesCommand request, CancellationToken cancellationToken)
    {
        var me = currentUser.RequireUserId();
        var preferences = await notifications.PreferencesAsync(me, cancellationToken);
        if (preferences is null)
        {
            preferences = NotificationPreferences.DefaultsFor(me);
            notifications.Add(preferences);
        }

        preferences.Update(request.PushMatches, request.PushChat, request.PushRatings, request.PushSavedSearches, request.QuietHoursEnabled,
            PreferencesMapping.Minute(request.QuietStart), PreferencesMapping.Minute(request.QuietEnd));
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return PreferencesMapping.ToView(preferences);
    }
}

/// <summary>A token belongs to one account at a time: registering it again moves it (spec notifications › Shared phone, new user).</summary>
internal sealed class RegisterDeviceTokenHandler(ICurrentUserService currentUser, INotificationRepository notifications, INotificationsUnitOfWork unitOfWork, TimeProvider clock)
    : ICommandHandler<RegisterDeviceTokenCommand>
{
    public async Task Handle(RegisterDeviceTokenCommand request, CancellationToken cancellationToken)
    {
        var me = currentUser.RequireUserId();
        var now = clock.GetUtcNow().UtcDateTime;
        var token = (request.Token ?? string.Empty).Trim();
        if (await notifications.TokenAsync(token, cancellationToken) is { } existing)
            existing.AssignTo(me, request.Platform, now);
        else
            notifications.Add(DeviceToken.Register(me, token, request.Platform, now));
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
    }
}

/// <summary>Called by the app on sign-out, so the device stops receiving this account's pushes.</summary>
internal sealed class UnregisterDeviceTokenHandler(ICurrentUserService currentUser, INotificationRepository notifications, INotificationsUnitOfWork unitOfWork, TimeProvider clock)
    : ICommandHandler<UnregisterDeviceTokenCommand>
{
    public async Task Handle(UnregisterDeviceTokenCommand request, CancellationToken cancellationToken)
    {
        var token = await notifications.TokenAsync((request.Token ?? string.Empty).Trim(), cancellationToken);
        if (token is null || token.UserId != currentUser.RequireUserId())
            return;
        token.Revoke("signed out", clock.GetUtcNow().UtcDateTime);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
    }
}
