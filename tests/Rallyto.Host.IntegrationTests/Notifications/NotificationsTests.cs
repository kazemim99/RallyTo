using System.Net;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.DependencyInjection;
using Rallyto.Contracts.Community;
using Rallyto.Host.IntegrationTests.Community;
using Rallyto.Notifications.Infrastructure;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Notifications;

/// <summary>spec notifications. The test clock is Friday 1405/08/01 12:30 Tehran, outside the default quiet hours.</summary>
public sealed class NotificationsTests(RallytoHostFactory factory) : MatchTestBase(factory)
{
    private async Task RunMaintenanceAsync()
    {
        await using var scope = Factory.Services.CreateAsyncScope();
        await scope.ServiceProvider.GetRequiredService<NotificationsMaintenance>().RunAsync(CancellationToken.None);
    }

    private static Task EventuallyAsync(Func<Task<bool>> condition) => CommunityApi.EventuallyAsync(condition);

    private async Task<(HttpClient Host, Guid HostId, MatchView Post)> HostWithPostAsync(string date = MatchApi.Saturday, string time = "19:00")
    {
        var (host, hostId) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal, date: date, startTime: time));
        return (host, hostId, post);
    }

    [Fact]
    public async Task A_join_request_lands_in_the_inbox_without_any_device()
    {
        var (host, _, post) = await HostWithPostAsync();
        var (guest, _) = await PlayerAsync("مهمان");

        await JoinAsync(guest, post.Id);

        await EventuallyAsync(async () => await NotificationApi.UnreadAsync(host) == 1);
        var item = (await NotificationApi.InboxAsync(host)).Single();
        item.Code.Should().Be("join-request-received");
        item.Body.Should().Contain("مهمان");
        item.DeepLink.Should().Be($"/matches/{post.Id}");
        Factory.Push.Sent.Should().BeEmpty();
    }

    [Fact]
    public async Task A_join_request_is_pushed_to_the_hosts_device()
    {
        var (host, _, post) = await HostWithPostAsync();
        await NotificationApi.RegisterAsync(host, "host-phone");
        var (guest, _) = await PlayerAsync("مهمان");

        await JoinAsync(guest, post.Id);

        await EventuallyAsync(() => Task.FromResult(Factory.Push.SentTo("host-phone").Count == 1));
        Factory.Push.SentTo("host-phone")[0].Data["deepLink"].Should().Be($"/matches/{post.Id}");
    }

    [Fact]
    public async Task An_invalid_token_is_revoked_and_the_other_device_still_gets_pushes()
    {
        var (host, _, post) = await HostWithPostAsync();
        await NotificationApi.RegisterAsync(host, "old-phone");
        await NotificationApi.RegisterAsync(host, "new-phone");
        Factory.Push.DeadTokens["old-phone"] = true;
        var (first, _) = await PlayerAsync("اول");
        var (second, _) = await PlayerAsync("دوم");

        await JoinAsync(first, post.Id);
        await EventuallyAsync(() => Task.FromResult(Factory.Push.SentTo("new-phone").Count == 1));
        Factory.Push.DeadTokens.Clear();
        await JoinAsync(second, post.Id);

        await EventuallyAsync(() => Task.FromResult(Factory.Push.SentTo("new-phone").Count == 2));
        Factory.Push.SentTo("old-phone").Should().BeEmpty();
        (await NotificationApi.InboxAsync(host)).Should().HaveCount(2);
    }

    [Fact]
    public async Task A_token_moves_to_the_account_that_registers_it_last()
    {
        var (a, aId) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهار");
        await NotificationApi.RegisterAsync(a, "shared-phone");
        await NotificationApi.RegisterAsync(b, "shared-phone");
        await using var scope = Factory.Services.CreateAsyncScope();
        var dispatch = scope.ServiceProvider.GetRequiredService<NotificationSubscribers>();

        await dispatch.OnPlayerWarned(new PlayerWarned(aId, "اخطار برای علی", "test"));
        await dispatch.OnPlayerWarned(new PlayerWarned(bId, "اخطار برای بهار", "test"));

        Factory.Push.SentTo("shared-phone").Should().ContainSingle(p => p.Body == "اخطار برای بهار");
    }

    [Fact]
    public async Task A_switched_off_category_still_fills_the_inbox()
    {
        var (host, _, post) = await HostWithPostAsync();
        await NotificationApi.RegisterAsync(host, "host-phone");
        await NotificationApi.SetPreferencesAsync(host, matches: false);
        var (guest, _) = await PlayerAsync("مهمان");

        await JoinAsync(guest, post.Id);

        await EventuallyAsync(async () => await NotificationApi.UnreadAsync(host) == 1);
        Factory.Push.Sent.Should().BeEmpty();
    }

    [Fact]
    public async Task Account_notices_are_pushed_even_with_every_category_off()
    {
        var (player, playerId) = await PlayerAsync("علی");
        await NotificationApi.RegisterAsync(player, "phone");
        await NotificationApi.SetPreferencesAsync(player, false, false, false, false, quiet: false);

        await SafetyApi.ActAsync(await Factory.AdminClientAsync(), playerId, "Warn", "رفتار", warningText: "لطفاً محترمانه رفتار کنید.");

        await EventuallyAsync(() => Task.FromResult(Factory.Push.SentTo("phone").Any(p => p.Body == "لطفاً محترمانه رفتار کنید.")));
    }

    [Fact]
    public async Task Quiet_hours_hold_back_pushes_but_not_the_inbox()
    {
        var (host, _, post) = await HostWithPostAsync();
        await NotificationApi.RegisterAsync(host, "host-phone");
        await NotificationApi.SetPreferencesAsync(host, quietStart: "12:00", quietEnd: "13:00");
        var (guest, _) = await PlayerAsync("مهمان");

        await JoinAsync(guest, post.Id);

        await EventuallyAsync(async () => await NotificationApi.UnreadAsync(host) == 1);
        Factory.Push.Sent.Should().BeEmpty();
    }

    [Fact]
    public async Task A_cancellation_within_12_hours_is_pushed_in_quiet_hours()
    {
        var (host, _, post) = await HostWithPostAsync(date: "1405/08/01", time: "19:00");
        var (guest, guestId) = await PlayerAsync("مهمان");
        await JoinAsync(guest, post.Id);
        await AcceptAsync(host, post.Id, guestId);
        await NotificationApi.RegisterAsync(guest, "guest-phone");
        await NotificationApi.SetPreferencesAsync(guest, quietStart: "12:00", quietEnd: "13:00");

        await host.PostApiAsync<MatchView>($"{MatchApi.Matches}/{post.Id}/cancel", new { reason = "بیمار شدم" });

        await EventuallyAsync(() => Task.FromResult(Factory.Push.SentTo("guest-phone").Any(p => p.Data["code"] == "match-cancelled")));
    }

    [Fact]
    public async Task A_redelivered_event_creates_one_notification()
    {
        var (host, hostId, post) = await HostWithPostAsync();
        var (_, guestId) = await PlayerAsync("مهمان");
        var message = new JoinRequestReceived(post.Id, hostId, guestId);
        await using var scope = Factory.Services.CreateAsyncScope();
        var subscribers = scope.ServiceProvider.GetRequiredService<NotificationSubscribers>();

        await subscribers.OnJoinRequestReceived(message);
        await subscribers.OnJoinRequestReceived(message);

        (await NotificationApi.InboxAsync(host)).Should().ContainSingle();
    }

    [Fact]
    public async Task Online_players_get_the_notification_and_badge_live()
    {
        var (host, _, post) = await HostWithPostAsync();
        var token = host.DefaultRequestHeaders.Authorization!.Parameter!;
        var badge = new TaskCompletionSource<int>();
        await using var hub = new HubConnectionBuilder()
            .WithUrl(new Uri(Factory.Server.BaseAddress, "/hubs/realtime"), o =>
            {
                o.HttpMessageHandlerFactory = _ => Factory.Server.CreateHandler();
                o.AccessTokenProvider = () => Task.FromResult<string?>(token);
                o.Transports = Microsoft.AspNetCore.Http.Connections.HttpTransportType.LongPolling;
            })
            .Build();
        hub.On<LiveNotification>("notification.created", n => badge.TrySetResult(n.UnreadCount));
        await hub.StartAsync();
        var (guest, _) = await PlayerAsync("مهمان");

        await JoinAsync(guest, post.Id);

        (await badge.Task.WaitAsync(TimeSpan.FromSeconds(10))).Should().Be(1);
    }

    private sealed record LiveNotification(NotificationView Notification, int UnreadCount);

    [Fact]
    public async Task Match_reminder_two_hours_before_in_persian()
    {
        var (host, _, post) = await HostWithPostAsync();
        var (guest, guestId) = await PlayerAsync("مهمان");
        await JoinAsync(guest, post.Id);
        await AcceptAsync(host, post.Id, guestId);
        await NotificationApi.RegisterAsync(guest, "guest-phone");

        Factory.Advance(TimeSpan.FromHours(28)); // Saturday 16:30 Tehran: 2h30 before
        await RunMaintenanceAsync();
        Factory.Push.SentTo("guest-phone").Should().NotContain(p => p.Data["code"] == "match-reminder");
        Factory.Advance(TimeSpan.FromMinutes(30)); // 17:00
        await RunMaintenanceAsync();
        await RunMaintenanceAsync();

        Factory.Push.SentTo("guest-phone").Should().ContainSingle(p => p.Data["code"] == "match-reminder")
            .Which.Body.Should().Be("بازی تنیس شما امروز ساعت ۱۹:۰۰ در مجموعه تنیس استقلال");
    }

    [Fact]
    public async Task Marking_read_clears_the_badge()
    {
        var (host, _, post) = await HostWithPostAsync();
        for (var i = 0; i < 2; i++)
        {
            var (guest, _) = await PlayerAsync($"مهمان {i}");
            await JoinAsync(guest, post.Id);
        }

        await EventuallyAsync(async () => await NotificationApi.UnreadAsync(host) == 2);
        var first = (await NotificationApi.InboxAsync(host))[0];
        await host.PostApiAsync<Empty>($"{NotificationApi.Notifications}/{first.Id}/read");
        var afterOne = await NotificationApi.UnreadAsync(host);
        await host.PostApiAsync<Empty>($"{NotificationApi.Notifications}/read-all");

        afterOne.Should().Be(1);
        (await NotificationApi.UnreadAsync(host)).Should().Be(0);
    }

    [Fact]
    public async Task Chat_messages_are_pushed_but_not_put_in_the_inbox()
    {
        var (a, _) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهار");
        await NotificationApi.RegisterAsync(b, "b-phone");
        var conversation = await ChatApi.OpenDirectAsync(a, bId);

        await ChatApi.SendAsync(a, conversation.Id, "سلام، شنبه بازی؟");

        await EventuallyAsync(() => Task.FromResult(Factory.Push.SentTo("b-phone").Any(p => p.Body == "سلام، شنبه بازی؟")));
        (await NotificationApi.InboxAsync(b)).Should().BeEmpty();
    }

    [Fact]
    public async Task A_suspension_informs_the_player_and_revokes_their_devices()
    {
        var (player, playerId) = await PlayerAsync("علی");
        await NotificationApi.RegisterAsync(player, "phone");

        await SafetyApi.ActAsync(await Factory.AdminClientAsync(), playerId, "Suspend", "توهین در گفتگو", until: "1405/08/08");

        await EventuallyAsync(() => Task.FromResult(Factory.Push.SentTo("phone").Any(p => p.Body.Contains("۱۴۰۵/۰۸/۰۸") && p.Body.Contains("توهین در گفتگو"))));
        await using var scope = Factory.Services.CreateAsyncScope();
        var subscribers = scope.ServiceProvider.GetRequiredService<NotificationSubscribers>();
        await subscribers.OnPlayerWarned(new PlayerWarned(playerId, "بعد از تعلیق", "test"));
        Factory.Push.SentTo("phone").Should().NotContain(p => p.Body == "بعد از تعلیق");
    }

    [Fact]
    public async Task Unregistering_a_token_stops_pushes_to_it()
    {
        var (player, playerId) = await PlayerAsync("علی");
        await NotificationApi.RegisterAsync(player, "phone");

        var unregister = await player.DeleteApiAsync<Empty>(NotificationApi.DeviceTokens, new { token = "phone" });
        await using var scope = Factory.Services.CreateAsyncScope();
        await scope.ServiceProvider.GetRequiredService<NotificationSubscribers>().OnPlayerWarned(new PlayerWarned(playerId, "متن", "test"));

        unregister.Status.Should().Be(HttpStatusCode.NoContent);
        Factory.Push.Sent.Should().BeEmpty();
    }

    [Fact]
    public async Task Preferences_default_to_quiet_nights_and_validate_steps()
    {
        var (player, _) = await PlayerAsync("علی");

        var defaults = (await player.GetApiAsync<PreferencesView>($"{NotificationApi.Notifications}/preferences")).Data!;
        var invalid = await NotificationApi.SetPreferencesAsync(player, quietStart: "23:10");

        defaults.Should().Be(new PreferencesView(true, true, true, true, true, "23:00", "08:00"));
        invalid.ErrorCode.Should().Be("INVALID_QUIET_HOURS");
    }

    [Fact]
    public async Task Notifications_older_than_90_days_are_removed()
    {
        var (host, _, post) = await HostWithPostAsync();
        var (guest, _) = await PlayerAsync("مهمان");
        await JoinAsync(guest, post.Id);
        await EventuallyAsync(async () => await NotificationApi.UnreadAsync(host) == 1);

        Factory.Advance(TimeSpan.FromDays(91));
        await RunMaintenanceAsync();
        host = await Factory.FreshClientAsync("09127000001");

        (await NotificationApi.InboxAsync(host)).Should().BeEmpty();
    }
}
