using System.Net;
using System.Net.Http.Headers;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Community;

/// <summary>spec trust-safety › reports, admin queue, actions, audit log and disputes.</summary>
public sealed class TrustSafetyTests(RallytoHostFactory factory) : MatchTestBase(factory)
{
    private static readonly byte[] TinyPng = Convert.FromBase64String(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==");

    private async Task<(Guid ConversationId, Guid MessageId)> MessageAsync(HttpClient from, Guid toId, string text)
    {
        var conversation = await ChatApi.OpenDirectAsync(from, toId);
        var message = (await ChatApi.SendAsync(from, conversation.Id, text)).Data!;
        return (conversation.Id, message.Id);
    }

    // ---- Reports ----------------------------------------------------------------------------------------------

    [Fact]
    public async Task Report_a_harassing_message_and_block_in_the_same_step()
    {
        var (a, aId) = await PlayerAsync("آزاردهنده");
        var (b, bId) = await PlayerAsync("بهار");
        var (_, messageId) = await MessageAsync(a, bId, "متن توهین‌آمیز");

        var report = await SafetyApi.ReportAsync(b, "Message", messageId.ToString(), "Harassment", "چند بار تکرار شد", block: true);
        var queue = await SafetyApi.QueueAsync(await Factory.AdminClientAsync());

        report.Status.Should().Be(HttpStatusCode.Created);
        var group = queue.Single(g => g.TargetUserId == aId);
        group.Reports.Single().Evidence.Text.Should().Be("متن توهین‌آمیز");
        group.HighPriority.Should().BeTrue();
        (await b.GetApiAsync<List<BlockedPlayer>>(CommunityApi.Blocks)).Data!.Should().Contain(x => x.UserId == aId);
    }

    [Fact]
    public async Task A_second_open_report_on_the_same_target_is_rejected()
    {
        var (_, aId) = await PlayerAsync("علی");
        var (b, _) = await PlayerAsync("بهار");
        await SafetyApi.ReportAsync(b, "Player", aId.ToString(), "FakeProfile");

        var again = await SafetyApi.ReportAsync(b, "Player", aId.ToString(), "Spam");

        again.Status.Should().Be(HttpStatusCode.Conflict);
        again.ErrorCode.Should().Be("ALREADY_REPORTED");
    }

    [Fact]
    public async Task Only_members_can_report_a_message()
    {
        var (a, _) = await PlayerAsync("علی");
        var (_, bId) = await PlayerAsync("بهار");
        var (outsider, _) = await PlayerAsync("غریبه");
        var (_, messageId) = await MessageAsync(a, bId, "سلام");

        var report = await SafetyApi.ReportAsync(outsider, "Message", messageId.ToString());

        report.Status.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task A_reported_photo_is_kept_as_a_copy_after_it_is_removed()
    {
        var (a, aId) = await PlayerAsync("علی");
        var (b, _) = await PlayerAsync("بهار");
        using var photo = new MultipartFormDataContent { { new ByteArrayContent(TinyPng) { Headers = { ContentType = new MediaTypeHeaderValue("image/png") } }, "file", "me.png" } };
        await a.PutAsync($"{CommunityApi.Profile}/photo", photo);
        await SafetyApi.ReportAsync(b, "Photo", aId.ToString(), "InappropriateContent");
        (await SafetyApi.TargetAsync(await Factory.AdminClientAsync(), aId)).HasPhoto.Should().BeTrue();
        var admin = await Factory.AdminClientAsync();
        var report = (await SafetyApi.QueueAsync(admin)).Single(g => g.TargetUserId == aId).Reports.Single();

        await SafetyApi.ActAsync(admin, aId, "RemovePhoto", "عکس نامناسب", report.Id);
        var copy = await Factory.CreateClient().GetAsync(report.Evidence.PhotoUrl);

        copy.StatusCode.Should().Be(HttpStatusCode.OK);
        (await SafetyApi.TargetAsync(admin, aId)).HasPhoto.Should().BeFalse();
        (await a.GetApiAsync<MyProfileView>(CommunityApi.MyProfile)).Data!.PhotoUrl.Should().BeNull();
    }

    [Fact]
    public async Task Reporting_a_post_snapshots_its_text()
    {
        var (host, hostId) = await PlayerAsync("تبلیغاتچی");
        var (b, _) = await PlayerAsync("بهار");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal, description: "خرید راکت با تخفیف"));

        await SafetyApi.ReportAsync(b, "Post", post.Id.ToString(), "Spam");

        var report = (await SafetyApi.QueueAsync(await Factory.AdminClientAsync())).Single(g => g.TargetUserId == hostId).Reports.Single();
        report.Evidence.Text.Should().Be("خرید راکت با تخفیف");
    }

    [Fact]
    public async Task Reporters_see_status_but_not_the_action()
    {
        var (_, aId) = await PlayerAsync("علی");
        var (b, _) = await PlayerAsync("بهار");
        var receipt = (await SafetyApi.ReportAsync(b, "Player", aId.ToString(), "Spam")).Data!;
        var admin = await Factory.AdminClientAsync();

        var open = (await b.GetApiAsync<List<MyReportView>>($"{SafetyApi.Reports}/mine")).Data!.Single();
        await SafetyApi.ActAsync(admin, aId, "Warn", "تبلیغات", receipt.Id, warningText: "لطفاً تبلیغ نکنید.");
        var raw = await b.GetStringAsync($"{SafetyApi.Reports}/mine");

        open.Status.Should().Be("Open");
        raw.Should().Contain("Resolved");
        raw.Should().NotContain("Warn");
    }

    [Fact]
    public async Task Dismissing_a_report_resolves_it()
    {
        var (_, aId) = await PlayerAsync("علی");
        var (b, _) = await PlayerAsync("بهار");
        var receipt = (await SafetyApi.ReportAsync(b, "Player", aId.ToString(), "Other")).Data!;

        var dismiss = await (await Factory.AdminClientAsync()).PostApiAsync<Empty>($"{SafetyApi.AdminReports}/{receipt.Id}/dismiss", new { reason = "مورد نقضی نبود" });

        dismiss.Status.Should().Be(HttpStatusCode.NoContent);
        (await b.GetApiAsync<List<MyReportView>>($"{SafetyApi.Reports}/mine")).Data!.Single().Status.Should().Be("Resolved");
        (await SafetyApi.QueueAsync(await Factory.AdminClientAsync())).Should().NotContain(g => g.TargetUserId == aId);
    }

    // ---- Queue ------------------------------------------------------------------------------------------------

    [Fact]
    public async Task Several_reporters_raise_priority_and_groups_come_first()
    {
        var (_, quiet) = await PlayerAsync("کم‌خطر");
        var (_, target) = await PlayerAsync("پرگزارش");
        var (first, _) = await PlayerAsync("گزارشگر ۰");
        await SafetyApi.ReportAsync(first, "Player", quiet.ToString(), "Spam");
        await SafetyApi.ReportAsync(first, "Player", target.ToString(), "Spam");
        for (var i = 1; i < 3; i++)
        {
            var (reporter, _) = await PlayerAsync($"گزارشگر {i}");
            await SafetyApi.ReportAsync(reporter, "Player", target.ToString(), "Spam");
        }

        var queue = await SafetyApi.QueueAsync(await Factory.AdminClientAsync());

        queue[0].TargetUserId.Should().Be(target);
        queue[0].HighPriority.Should().BeTrue();
        queue[0].DistinctReporters.Should().Be(3);
        queue.Single(g => g.TargetUserId == quiet).HighPriority.Should().BeFalse();
    }

    [Fact]
    public async Task Nobody_is_suspended_automatically()
    {
        var (_, target) = await PlayerAsync("پرگزارش");
        for (var i = 0; i < 5; i++)
        {
            var (reporter, _) = await PlayerAsync($"گزارشگر {i}");
            await SafetyApi.ReportAsync(reporter, "Player", target.ToString(), "Harassment");
        }

        var account = (await (await Factory.AdminClientAsync()).GetApiAsync<AdminAccount>($"{IdentityApi.AdminUsers}/{target}")).Data!;

        account.Status.Should().Be("Active");
    }

    [Fact]
    public async Task Only_admins_open_the_queue()
    {
        var (player, _) = await PlayerAsync("علی");

        (await player.GetApiAsync<List<ReportGroupView>>(SafetyApi.AdminReports)).Status.Should().Be(HttpStatusCode.Forbidden);
    }

    // ---- Actions ----------------------------------------------------------------------------------------------

    [Fact]
    public async Task Suspend_for_a_week()
    {
        var (bad, badId) = await PlayerAsync("خاطی");
        var (host, _) = await PlayerAsync("میزبان");
        var (viewer, _) = await PlayerAsync("بیننده");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal));
        await JoinAsync(bad, post.Id);
        await AcceptAsync(host, post.Id, badId);
        var receipt = (await SafetyApi.ReportAsync(viewer, "Player", badId.ToString(), "Harassment")).Data!;
        var admin = await Factory.AdminClientAsync();

        var action = await SafetyApi.ActAsync(admin, badId, "Suspend", "harassment in chat", receipt.Id, until: "1405/08/08");

        action.Status.Should().Be(HttpStatusCode.OK);
        var account = (await admin.GetApiAsync<AdminAccount>($"{IdentityApi.AdminUsers}/{badId}")).Data!;
        account.Status.Should().Be("Suspended");
        account.SuspendedUntil.Should().Be(new DateTime(2026, 10, 30, 20, 30, 0, DateTimeKind.Utc));
        await CommunityApi.EventuallyAsync(async () => (await GetAsync(host, post.Id)).Participants!.Single(p => p.UserId == badId).State == "Removed");
        (await viewer.GetApiAsync<PlayerProfileView>($"/api/v1/players/{badId}")).Status.Should().Be(HttpStatusCode.NotFound);
        (await SafetyApi.TargetAsync(admin, badId)).Actions.Should().ContainSingle(a => a.Action == "Suspend" && a.ReportId == receipt.Id);
    }

    [Fact]
    public async Task Ban_blocks_the_number_from_registering_again()
    {
        var (_, badId) = await PlayerAsync("خاطی");
        var phone = LastPhone;
        var admin = await Factory.AdminClientAsync();

        await SafetyApi.ActAsync(admin, badId, "Ban", "تهدید مکرر");
        Factory.Advance(TimeSpan.FromSeconds(61));
        using var anonymous = Factory.CreateClient();
        await anonymous.PostApiAsync<SendCodeResponse>(IdentityApi.SendCode, new { phoneNumber = phone });
        var signIn = await anonymous.PostApiAsync<AuthTokens>(IdentityApi.Verify, new { phoneNumber = phone, code = Factory.Sms.LastCodeFor(phone) });

        (await admin.GetApiAsync<AdminAccount>($"{IdentityApi.AdminUsers}/{badId}")).Data!.Status.Should().Be("Banned");
        signIn.ErrorCode.Should().Be("ACCOUNT_BANNED");
    }

    [Fact]
    public async Task Hiding_a_post_removes_it_from_search_and_share_links_but_keeps_the_match()
    {
        var (host, hostId) = await PlayerAsync("میزبان");
        var (guest, guestId) = await PlayerAsync("مهمان");
        var (searcher, _) = await PlayerAsync("جستجوگر");
        var post = await PostAsync(host, MatchApi.Post(Sports["padel"], Esteghlal, "Doubles"));
        await JoinAsync(guest, post.Id);
        await AcceptAsync(host, post.Id, guestId);
        var token = post.ShareUrl!.Split('/')[^1];

        var hide = await SafetyApi.ActAsync(await Factory.AdminClientAsync(), hostId, "HidePost", "تبلیغات", matchId: post.Id);

        hide.Status.Should().Be(HttpStatusCode.OK);
        (await searcher.GetApiAsync<MatchView>($"{MatchApi.Matches}/{post.Id}")).Status.Should().Be(HttpStatusCode.NotFound);
        (await Factory.CreateClient().GetAsync($"{MatchApi.Share}/{token}")).StatusCode.Should().Be(HttpStatusCode.NotFound);
        (await JoinAsync(searcher, post.Id)).Status.Should().NotBe(HttpStatusCode.OK);
        (await GetAsync(guest, post.Id)).MyState.Should().Be("Accepted");
        var results = (await searcher.GetApiAsync<PlayPostTests.SearchWithPosts>(SearchApi.Query(Sports["padel"], date: MatchApi.Saturday, from: "18:00", to: "22:00"))).Data!;
        results.Posts.Should().NotContain(p => p.Id == post.Id);
    }

    [Fact]
    public async Task Deleting_a_message_removes_it_for_everyone()
    {
        var (a, aId) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهار");
        var (conversationId, messageId) = await MessageAsync(a, bId, "پیام توهین‌آمیز");

        var action = await SafetyApi.ActAsync(await Factory.AdminClientAsync(), aId, "DeleteMessage", "توهین", messageId: messageId);

        action.Status.Should().Be(HttpStatusCode.OK);
        await CommunityApi.EventuallyAsync(async () => (await ChatApi.HistoryAsync(b, conversationId)).Items.Single().Deleted);
    }

    [Fact]
    public async Task A_warning_is_recorded_and_sent_to_the_player()
    {
        var (_, aId) = await PlayerAsync("علی");

        var warn = await SafetyApi.ActAsync(await Factory.AdminClientAsync(), aId, "Warn", "رفتار نامناسب", warningText: "لطفاً محترمانه رفتار کنید.");

        warn.Status.Should().Be(HttpStatusCode.OK);
        (await Factory.PublishedAsync("rallyto.community.player-warned")).Should().Contain(p => p.Contains(aId.ToString()) && p.Contains("لطفاً محترمانه رفتار کنید."));
    }

    [Fact]
    public async Task A_warning_needs_its_text()
    {
        var (_, aId) = await PlayerAsync("علی");

        var warn = await SafetyApi.ActAsync(await Factory.AdminClientAsync(), aId, "Warn", "رفتار نامناسب");

        warn.Status.Should().Be(HttpStatusCode.BadRequest);
        warn.ErrorCode.Should().Be("WARNING_TEXT_REQUIRED");
    }

    // ---- Audit and disputes -----------------------------------------------------------------------------------

    [Fact]
    public async Task The_audit_log_filters_by_admin_and_date()
    {
        var (_, aId) = await PlayerAsync("علی");
        var admin = await Factory.AdminClientAsync();
        var adminId = await IdentityApi.UserIdOf(admin);
        await SafetyApi.ActAsync(admin, aId, "Warn", "اخطار اول", warningText: "اخطار");
        await admin.PostApiAsync<Empty>($"/api/v1/admin/players/{aId}/gender", new { gender = "Female", reason = "اشتباه در ثبت" });

        PagedResult<AuditEntryView>? mine = null;
        await CommunityApi.EventuallyAsync(async () =>
            (mine = (await admin.GetApiAsync<PagedResult<AuditEntryView>>($"{SafetyApi.Audit}?adminId={adminId}&from=1405/07/25&to=1405/08/01")).Data!).Items.Count >= 2);
        var other = (await admin.GetApiAsync<PagedResult<AuditEntryView>>($"{SafetyApi.Audit}?adminId={Guid.NewGuid()}")).Data!;
        var byAction = (await admin.GetApiAsync<PagedResult<AuditEntryView>>($"{SafetyApi.Audit}?action=player.correct-gender&targetUserId={aId}")).Data!;

        mine!.Items.Should().Contain(e => e.Action == "moderation.warn" && e.Reason == "اخطار اول");
        mine.Items.Should().Contain(e => e.Action == "player.correct-gender" && e.Reason == "اشتباه در ثبت");
        other.Items.Should().BeEmpty();
        byAction.Items.Should().ContainSingle();
    }

    [Fact]
    public async Task Disputes_and_private_notes_show_in_the_target_history()
    {
        var (host, hostId) = await PlayerAsync("میزبان");
        var hostPhone = LastPhone;
        var (guest, guestId) = await PlayerAsync("مهمان");
        var guestPhone = LastPhone;
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal));
        await JoinAsync(guest, post.Id);
        await AcceptAsync(host, post.Id, guestId);
        Factory.Advance(TimeSpan.FromHours(33));
        host = await Factory.FreshClientAsync(hostPhone);
        guest = await Factory.FreshClientAsync(guestPhone);
        await RatingApi.AnswerAsync(host, post.Id, "Played");
        await RatingApi.AnswerAsync(guest, post.Id, "DidNotHappen");
        var admin = await Factory.AdminClientAsync();

        var detail = await SafetyApi.TargetAsync(admin, guestId);
        var disputed = (await admin.GetApiAsync<List<DisputedMatchView>>(SafetyApi.Disputed)).Data!;

        detail.Disputes.Count.Should().Be(1);
        detail.Disputes.MatchIds.Should().Equal(post.Id);
        detail.Reliability.Should().Be("New");
        disputed.Should().ContainSingle(m => m.MatchId == post.Id && m.Players.Any(p => p.UserId == hostId && p.Answer == "Played"));
    }

    [Fact]
    public async Task Private_rating_notes_are_visible_to_admins_in_the_target_history()
    {
        var (host, hostId) = await PlayerAsync("میزبان");
        var hostPhone = LastPhone;
        var (guest, guestId) = await PlayerAsync("مهمان");
        var guestPhone = LastPhone;
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal));
        await JoinAsync(guest, post.Id);
        await AcceptAsync(host, post.Id, guestId);
        Factory.Advance(TimeSpan.FromHours(33));
        host = await Factory.FreshClientAsync(hostPhone);
        guest = await Factory.FreshClientAsync(guestPhone);
        await RatingApi.AnswerAsync(host, post.Id, "Played");
        await RatingApi.AnswerAsync(guest, post.Id, "Played");
        await RatingApi.RateAsync(host, post.Id, RatingApi.Rating(guestId, 2, note: "در زمین بدرفتاری کرد"));

        var detail = await SafetyApi.TargetAsync(await Factory.AdminClientAsync(), guestId);

        detail.PrivateNotes.Should().ContainSingle(n => n.RaterId == hostId && n.Note == "در زمین بدرفتاری کرد");
    }

    // ---- End to end -------------------------------------------------------------------------------------------

    [Fact]
    public async Task A_ban_reaches_every_context()
    {
        var (bad, badId) = await PlayerAsync("خاطی");
        var (friend, _) = await PlayerAsync("دوست");
        var conversation = await ChatApi.OpenDirectAsync(friend, badId);
        await ChatApi.SendAsync(friend, conversation.Id, "سلام");
        await bad.PostApiAsync<ConversationSummary>($"{ChatApi.Conversations}/{conversation.Id}/accept");
        var hosted = await PostAsync(bad, MatchApi.Post(Sports["tennis"], Esteghlal));
        await NotificationApi.RegisterAsync(bad, "bad-phone");

        await SafetyApi.ActAsync(await Factory.AdminClientAsync(), badId, "Ban", "کلاهبرداری");

        (await bad.GetApiAsync<MyProfileView>(CommunityApi.MyProfile)).ErrorCode.Should().Be("ACCOUNT_BANNED");
        await CommunityApi.EventuallyAsync(async () => (await friend.GetApiAsync<PlayerProfileView>($"/api/v1/players/{badId}")).Status == HttpStatusCode.NotFound);
        await CommunityApi.EventuallyAsync(async () => (await friend.GetApiAsync<MatchView>($"{MatchApi.Matches}/{hosted.Id}")).Status == HttpStatusCode.NotFound
                                                        || (await GetAsync(friend, hosted.Id)).Status == "Cancelled");
        await CommunityApi.EventuallyAsync(async () => (await ChatApi.SendAsync(friend, conversation.Id, "هستی؟")).ErrorCode == "CANNOT_REPLY");
        await CommunityApi.EventuallyAsync(async () =>
        {
            await using var scope = Factory.Services.CreateAsyncScope();
            var db = scope.ServiceProvider.GetRequiredService<Rallyto.Notifications.Infrastructure.Persistence.NotificationsDbContext>();
            return await db.DeviceTokens.AnyAsync(t => t.Token == "bad-phone" && t.RevokedAt != null);
        });
    }
}
