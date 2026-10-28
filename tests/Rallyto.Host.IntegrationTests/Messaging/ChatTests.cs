using System.Net;
using Microsoft.AspNetCore.SignalR.Client;
using Rallyto.Host.IntegrationTests.Community;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Messaging;

/// <summary>spec chat.</summary>
public sealed class ChatTests(RallytoHostFactory factory) : MatchTestBase(factory)
{
    private const string OfflineTopic = "rallyto.messaging.message-received-offline";

    [Fact]
    public async Task Offline_members_get_a_push_unless_they_muted_the_conversation()
    {
        var (a, _) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهزاد");
        var conversation = await ChatApi.OpenDirectAsync(a, bId);
        await b.PostApiAsync<ConversationSummary>($"{ChatApi.Conversations}/{conversation.Id}/accept");

        var loud = (await ChatApi.SendAsync(a, conversation.Id, "یک")).Data!;
        await b.PostApiAsync<ConversationSummary>($"{ChatApi.Conversations}/{conversation.Id}/mute", new { muted = true });
        var quiet = (await ChatApi.SendAsync(a, conversation.Id, "دو")).Data!;
        var published = await Factory.PublishedAsync(OfflineTopic);

        published.Should().Contain(p => p.Contains(loud.Id.ToString()) && p.Contains(bId.ToString()));
        published.Should().NotContain(p => p.Contains(quiet.Id.ToString()));
        (await b.GetApiAsync<UnreadCounts>($"{ChatApi.Conversations}/unread")).Data!.Conversations.Should().Be(1);
    }

    [Fact]
    public async Task Message_requests_are_counted_apart_from_conversations()
    {
        var (a, _) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهزاد");
        var conversation = await ChatApi.OpenDirectAsync(a, bId);
        await ChatApi.SendAsync(a, conversation.Id, "سلام");

        var unread = (await b.GetApiAsync<UnreadCounts>($"{ChatApi.Conversations}/unread")).Data!;

        unread.Should().Be(new UnreadCounts(0, 1));
    }

    [Fact]
    public async Task At_most_20_new_direct_conversations_a_day()
    {
        var (a, _) = await PlayerAsync("علی");
        var targets = new List<Guid>();
        for (var i = 0; i < 21; i++)
            targets.Add((await Factory.OnboardedPlayerAsync($"0935{i:0000000}", $"بازیکن {i}")).UserId);
        foreach (var target in targets.Take(20))
            await ChatApi.OpenDirectAsync(a, target);

        var reopen = await a.PostApiAsync<ConversationSummary>($"{ChatApi.Conversations}/direct", new { playerId = targets[0] });
        var tooMany = await a.PostApiAsync<ConversationSummary>($"{ChatApi.Conversations}/direct", new { playerId = targets[20] });

        reopen.Status.Should().Be(HttpStatusCode.OK);
        tooMany.Status.Should().Be(HttpStatusCode.TooManyRequests);
    }

    [Fact]
    public async Task In_a_group_a_blocked_players_messages_are_hidden_from_the_blocker_only()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["padel"], Esteghlal, "Doubles"));
        var (a, aId) = await PlayerAsync("اول");
        var (b, bId) = await PlayerAsync("دوم");
        await JoinAsync(a, post.Id);
        await JoinAsync(b, post.Id);
        await AcceptAsync(host, post.Id, aId);
        await AcceptAsync(host, post.Id, bId);
        ConversationSummary? group = null;
        await CommunityApi.EventuallyAsync(async () => (group = (await ChatApi.ListAsync(a)).FirstOrDefault(c => c.MatchId == post.Id)) is not null);

        await a.PostApiAsync<Empty>($"{CommunityApi.Blocks}/{bId}");
        await ChatApi.SendAsync(b, group!.Id, "سلام همه");

        (await ChatApi.HistoryAsync(a, group.Id)).Items.Should().NotContain(m => m.SenderId == bId);
        (await ChatApi.HistoryAsync(host, group.Id)).Items.Should().Contain(m => m.Body == "سلام همه");
    }

    [Fact]
    public async Task One_direct_conversation_per_pair()
    {
        var (a, _) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهزاد");

        var first = await ChatApi.OpenDirectAsync(a, bId);
        var again = await ChatApi.OpenDirectAsync(a, bId);

        again.Id.Should().Be(first.Id);
        first.Title.Should().Be("بهزاد");
    }

    [Fact]
    public async Task Opening_a_conversation_with_a_hidden_player_looks_like_not_found()
    {
        var (sara, saraId) = await PlayerAsync("سارا", gender: "Female", visibility: "SameGender");
        var (man, _) = await PlayerAsync("رضا");

        var response = await man.PostApiAsync<ConversationSummary>($"{ChatApi.Conversations}/direct", new { playerId = saraId });

        response.Status.Should().Be(HttpStatusCode.NotFound);
        response.ErrorCode.Should().Be("PLAYER_NOT_FOUND");
    }

    [Fact]
    public async Task First_contact_from_a_stranger_is_a_request_with_one_message()
    {
        var (a, _) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهزاد");
        var conversation = await ChatApi.OpenDirectAsync(a, bId);

        var first = await ChatApi.SendAsync(a, conversation.Id, "سلام، شنبه‌ها استقلال بازی می‌کنی؟");
        var second = await ChatApi.SendAsync(a, conversation.Id, "؟");
        var requests = await ChatApi.ListAsync(b, "requests");
        var inbox = await ChatApi.ListAsync(b);

        first.Status.Should().Be(HttpStatusCode.OK);
        second.Status.Should().Be(HttpStatusCode.Conflict);
        second.ErrorCode.Should().Be("REQUEST_NOT_ACCEPTED");
        requests.Should().ContainSingle(c => c.Id == conversation.Id && c.IsRequest && c.Title == "علی");
        inbox.Should().NotContain(c => c.Id == conversation.Id);
    }

    [Fact]
    public async Task A_request_message_is_at_most_500_characters()
    {
        var (a, _) = await PlayerAsync("علی");
        var (_, bId) = await PlayerAsync("بهزاد");
        var conversation = await ChatApi.OpenDirectAsync(a, bId);

        var response = await ChatApi.SendAsync(a, conversation.Id, new string('ب', 501));

        response.Status.Should().Be(HttpStatusCode.BadRequest);
        response.ErrorCode.Should().Be("MESSAGE_TOO_LONG");
    }

    [Fact]
    public async Task Accepting_a_request_lets_both_sides_talk()
    {
        var (a, _) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهزاد");
        var conversation = await ChatApi.OpenDirectAsync(a, bId);
        await ChatApi.SendAsync(a, conversation.Id, "سلام");

        var accept = await b.PostApiAsync<ConversationSummary>($"{ChatApi.Conversations}/{conversation.Id}/accept");
        var reply = await ChatApi.SendAsync(b, conversation.Id, "سلام، بله");
        var more = await ChatApi.SendAsync(a, conversation.Id, "عالی");

        accept.Status.Should().Be(HttpStatusCode.OK);
        reply.Status.Should().Be(HttpStatusCode.OK);
        more.Status.Should().Be(HttpStatusCode.OK);
        (await ChatApi.ListAsync(b)).Should().Contain(c => c.Id == conversation.Id && !c.IsRequest);
    }

    [Fact]
    public async Task Ignoring_a_request_is_silent_and_keeps_the_sender_limited()
    {
        var (a, _) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهزاد");
        var conversation = await ChatApi.OpenDirectAsync(a, bId);
        await ChatApi.SendAsync(a, conversation.Id, "سلام");

        await b.PostApiAsync<ConversationSummary>($"{ChatApi.Conversations}/{conversation.Id}/ignore");
        var senderView = (await ChatApi.ListAsync(a)).Single(c => c.Id == conversation.Id);
        var again = await ChatApi.SendAsync(a, conversation.Id, "؟");

        (await ChatApi.ListAsync(b, "requests")).Should().BeEmpty();
        senderView.CanSend.Should().BeFalse();
        again.ErrorCode.Should().Be("REQUEST_NOT_ACCEPTED");
    }

    [Fact]
    public async Task A_shared_match_skips_the_request()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var (guest, guestId) = await PlayerAsync("مهمان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal));
        await JoinAsync(guest, post.Id);
        await AcceptAsync(host, post.Id, guestId);
        var hostId = await IdentityApi.UserIdOf(host);

        var conversation = await ChatApi.OpenDirectAsync(guest, hostId);
        await ChatApi.SendAsync(guest, conversation.Id, "سلام");
        var second = await ChatApi.SendAsync(guest, conversation.Id, "ساعت ۷ می‌بینمت");

        second.Status.Should().Be(HttpStatusCode.OK);
        (await ChatApi.ListAsync(host)).Should().Contain(c => c.Id == conversation.Id && !c.IsRequest);
    }

    [Fact]
    public async Task Doubles_matches_get_a_group_chat_that_follows_the_roster()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["padel"], Esteghlal, "Doubles"));
        var (a, aId) = await PlayerAsync("اول");
        var (b, bId) = await PlayerAsync("دوم");
        await JoinAsync(a, post.Id);
        await JoinAsync(b, post.Id);
        await AcceptAsync(host, post.Id, aId);
        await AcceptAsync(host, post.Id, bId);

        ConversationSummary? group = null;
        await CommunityApi.EventuallyAsync(async () => (group = (await ChatApi.ListAsync(b)).FirstOrDefault(c => c.MatchId == post.Id)) is not null);
        await ChatApi.SendAsync(host, group!.Id, "توپ با من");
        await a.PostApiAsync<MatchView>($"{MatchApi.Matches}/{post.Id}/leave");

        await CommunityApi.EventuallyAsync(async () => !(await ChatApi.ListAsync(a)).Any(c => c.MatchId == post.Id && c.CanSend));
        var history = await ChatApi.HistoryAsync(b, group.Id);
        history.Items.Should().Contain(m => m.Body == "توپ با من");
        (await ChatApi.SendAsync(a, group.Id, "من هم")).Status.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Whitespace_only_messages_are_rejected_and_retries_do_not_duplicate()
    {
        var (a, _) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهزاد");
        var conversation = await ChatApi.OpenDirectAsync(a, bId);
        await b.PostApiAsync<ConversationSummary>($"{ChatApi.Conversations}/{conversation.Id}/accept");

        var blank = await ChatApi.SendAsync(a, conversation.Id, "   ");
        await ChatApi.SendAsync(a, conversation.Id, "  سلام  ", "client-1");
        await ChatApi.SendAsync(a, conversation.Id, "  سلام  ", "client-1");
        var history = await ChatApi.HistoryAsync(b, conversation.Id);

        blank.Status.Should().Be(HttpStatusCode.BadRequest);
        history.Items.Should().ContainSingle(m => m.Body == "سلام");
    }

    [Fact]
    public async Task Messages_arrive_in_real_time()
    {
        var (a, _) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهزاد");
        var bToken = b.DefaultRequestHeaders.Authorization!.Parameter!;
        var conversation = await ChatApi.OpenDirectAsync(a, bId);
        var received = new TaskCompletionSource<string>();
        await using var hub = new HubConnectionBuilder()
            .WithUrl(new Uri(Factory.Server.BaseAddress, "/hubs/realtime"), o =>
            {
                o.HttpMessageHandlerFactory = _ => Factory.Server.CreateHandler();
                o.AccessTokenProvider = () => Task.FromResult<string?>(bToken);
                o.Transports = Microsoft.AspNetCore.Http.Connections.HttpTransportType.LongPolling;
            })
            .Build();
        hub.On<MessageView>("message.received", m => received.TrySetResult(m.Body ?? string.Empty));
        await hub.StartAsync();

        await ChatApi.SendAsync(a, conversation.Id, "سلام زنده");

        (await received.Task.WaitAsync(TimeSpan.FromSeconds(10))).Should().Be("سلام زنده");
    }

    [Fact]
    public async Task Read_receipts_and_unread_counts()
    {
        var (a, _) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهزاد");
        var conversation = await ChatApi.OpenDirectAsync(a, bId);
        await b.PostApiAsync<ConversationSummary>($"{ChatApi.Conversations}/{conversation.Id}/accept");
        var m1 = (await ChatApi.SendAsync(a, conversation.Id, "یک")).Data!;
        var m2 = (await ChatApi.SendAsync(a, conversation.Id, "دو")).Data!;

        var unreadBefore = (await b.GetApiAsync<UnreadCounts>($"{ChatApi.Conversations}/unread")).Data!;
        await b.PostApiAsync<Empty>($"{ChatApi.Conversations}/{conversation.Id}/read", new { upToMessageId = m2.Id });
        var unreadAfter = (await b.GetApiAsync<UnreadCounts>($"{ChatApi.Conversations}/unread")).Data!;
        var senderHistory = await ChatApi.HistoryAsync(a, conversation.Id);

        unreadBefore.Conversations.Should().Be(1);
        unreadAfter.Conversations.Should().Be(0);
        senderHistory.Items.Where(m => m.Id == m1.Id || m.Id == m2.Id).Should().OnlyContain(m => m.ReadByOthers);
    }

    [Fact]
    public async Task Non_members_cannot_read_a_conversation()
    {
        var (a, _) = await PlayerAsync("علی");
        var (_, bId) = await PlayerAsync("بهزاد");
        var (outsider, _) = await PlayerAsync("غریبه");
        var conversation = await ChatApi.OpenDirectAsync(a, bId);

        var response = await outsider.GetApiAsync<MessagePage>($"{ChatApi.Conversations}/{conversation.Id}/messages");

        response.Status.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task History_pages_newest_first_fifty_at_a_time()
    {
        var (a, _) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهزاد");
        var conversation = await ChatApi.OpenDirectAsync(a, bId);
        await b.PostApiAsync<ConversationSummary>($"{ChatApi.Conversations}/{conversation.Id}/accept");
        for (var i = 0; i < 55; i++)
            await ChatApi.SendAsync(a, conversation.Id, $"پیام {i}");

        var first = await ChatApi.HistoryAsync(b, conversation.Id);
        var second = await ChatApi.HistoryAsync(b, conversation.Id, first.NextCursor);

        first.Items.Should().HaveCount(50);
        first.Items[0].Body.Should().Be("پیام 54");
        second.Items.Should().HaveCount(5);
        second.NextCursor.Should().BeNull();
    }

    [Fact]
    public async Task After_a_block_neither_side_can_send_and_the_blocker_no_longer_sees_it()
    {
        var (a, _) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهزاد");
        var conversation = await ChatApi.OpenDirectAsync(a, bId);
        await b.PostApiAsync<ConversationSummary>($"{ChatApi.Conversations}/{conversation.Id}/accept");
        await ChatApi.SendAsync(a, conversation.Id, "سلام");

        await a.PostApiAsync<Empty>($"{CommunityApi.Blocks}/{bId}");
        var fromBlocked = await ChatApi.SendAsync(b, conversation.Id, "چرا؟");
        var fromBlocker = await ChatApi.SendAsync(a, conversation.Id, "خداحافظ");

        fromBlocked.Status.Should().Be(HttpStatusCode.Forbidden);
        fromBlocked.ErrorCode.Should().Be("CANNOT_REPLY");
        fromBlocker.Status.Should().Be(HttpStatusCode.Forbidden);
        (await ChatApi.ListAsync(a)).Should().NotContain(c => c.Id == conversation.Id);
        (await ChatApi.ListAsync(b)).Single(c => c.Id == conversation.Id).CanSend.Should().BeFalse();
    }

    [Fact]
    public async Task A_deleted_message_shows_as_deleted()
    {
        var (a, _) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهزاد");
        var conversation = await ChatApi.OpenDirectAsync(a, bId);
        var message = (await ChatApi.SendAsync(a, conversation.Id, "اشتباه شد")).Data!;

        var delete = await a.DeleteApiAsync<Empty>($"{ChatApi.Conversations}/{conversation.Id}/messages/{message.Id}");
        var seen = (await ChatApi.HistoryAsync(b, conversation.Id)).Items.Single();

        delete.Status.Should().Be(HttpStatusCode.NoContent);
        seen.Deleted.Should().BeTrue();
        seen.Body.Should().BeNull();
    }

    [Fact]
    public async Task Only_the_sender_can_delete_a_message()
    {
        var (a, _) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهزاد");
        var conversation = await ChatApi.OpenDirectAsync(a, bId);
        var message = (await ChatApi.SendAsync(a, conversation.Id, "پیام")).Data!;

        var delete = await b.DeleteApiAsync<Empty>($"{ChatApi.Conversations}/{conversation.Id}/messages/{message.Id}");

        delete.Status.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Conversation_with_a_deleted_user_keeps_their_messages_under_a_placeholder()
    {
        var (a, _) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهزاد");
        var bPhone = LastPhone;
        var conversation = await ChatApi.OpenDirectAsync(a, bId);
        await b.PostApiAsync<ConversationSummary>($"{ChatApi.Conversations}/{conversation.Id}/accept");
        await ChatApi.SendAsync(b, conversation.Id, "خداحافظ");
        Factory.Advance(TimeSpan.FromSeconds(61));
        await b.PostApiAsync<SendCodeResponse>(IdentityApi.DeletionCode);
        await b.PostApiAsync<Empty>(IdentityApi.Deletion, new { code = Factory.Sms.LastCodeFor(bPhone) });

        await CommunityApi.EventuallyAsync(async () => (await ChatApi.HistoryAsync(a, conversation.Id)).Items.Any(m => m.SenderName == "کاربر حذف‌شده"));
        (await ChatApi.SendAsync(a, conversation.Id, "هستی؟")).ErrorCode.Should().Be("CANNOT_REPLY");
    }

    private sealed record RecipientShape(Guid Id, bool IsRequest, bool IsRequestRecipient);

    [Fact]
    public async Task Each_side_knows_whether_it_is_the_request_recipient()
    {
        var (a, _) = await PlayerAsync("علی");
        var (b, bId) = await PlayerAsync("بهزاد");
        var conversation = await ChatApi.OpenDirectAsync(a, bId);
        await ChatApi.SendAsync(a, conversation.Id, "سلام");

        var forSender = (await a.GetApiAsync<RecipientShape>($"{ChatApi.Conversations}/{conversation.Id}")).Data!;
        var forRecipient = (await b.GetApiAsync<RecipientShape>($"{ChatApi.Conversations}/{conversation.Id}")).Data!;

        forSender.IsRequestRecipient.Should().BeFalse();
        forRecipient.Should().Be(new RecipientShape(conversation.Id, true, true));
    }

    [Fact]
    public async Task A_match_group_chat_can_be_found_by_its_match()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var post = await PostAsync(host, MatchApi.Post(Sports["padel"], Esteghlal, "Doubles"));
        var (a, aId) = await PlayerAsync("اول");
        var (b, bId) = await PlayerAsync("دوم");
        var (outsider, _) = await PlayerAsync("غریبه");
        await JoinAsync(a, post.Id);
        await JoinAsync(b, post.Id);
        await AcceptAsync(host, post.Id, aId);
        await AcceptAsync(host, post.Id, bId);

        ApiResponse<ConversationSummary>? found = null;
        await CommunityApi.EventuallyAsync(async () => (found = await a.GetApiAsync<ConversationSummary>($"{ChatApi.Conversations}/match/{post.Id}")).Status == HttpStatusCode.OK);

        found!.Data!.MatchId.Should().Be(post.Id);
        (await outsider.GetApiAsync<ConversationSummary>($"{ChatApi.Conversations}/match/{post.Id}")).Status.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Muting_a_conversation_is_remembered()
    {
        var (a, _) = await PlayerAsync("علی");
        var (_, bId) = await PlayerAsync("بهزاد");
        var conversation = await ChatApi.OpenDirectAsync(a, bId);

        var muted = await a.PostApiAsync<ConversationSummary>($"{ChatApi.Conversations}/{conversation.Id}/mute", new { muted = true });

        muted.Data!.Muted.Should().BeTrue();
        (await ChatApi.ListAsync(a)).Single(c => c.Id == conversation.Id).Muted.Should().BeTrue();
    }
}
