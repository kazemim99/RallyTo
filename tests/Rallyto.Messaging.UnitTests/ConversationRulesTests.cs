using Rallyto.Core.Domain.Exceptions;
using Rallyto.Messaging.Domain.Conversations;

namespace Rallyto.Messaging.UnitTests;

public sealed class ConversationRulesTests
{
    private static readonly DateTime Now = new(2026, 10, 23, 9, 0, 0, DateTimeKind.Utc);
    private static readonly Guid A = Guid.NewGuid();
    private static readonly Guid B = Guid.NewGuid();

    [Fact]
    public void A_pair_has_one_key_whoever_starts()
    {
        Conversation.KeyOf(A, B).Should().Be(Conversation.KeyOf(B, A));
    }

    [Fact]
    public void A_request_allows_one_message_of_500_characters()
    {
        var conversation = Conversation.Direct(A, B, shareMatch: false, Now);

        conversation.RecordSend(A).Should().Be(Conversation.RequestMaxLength);
        var second = () => conversation.RecordSend(A);

        second.Should().Throw<InvalidAggregateStateException>().Which.ErrorCode.Should().Be("REQUEST_NOT_ACCEPTED");
        conversation.AllowsSendBy(A).Should().BeFalse();
    }

    [Fact]
    public void A_reply_from_the_recipient_accepts_the_request()
    {
        var conversation = Conversation.Direct(A, B, shareMatch: false, Now);
        conversation.RecordSend(A);

        conversation.RecordSend(B).Should().Be(Conversation.MaxLength);

        conversation.IsPendingRequest.Should().BeFalse();
        conversation.AllowsSendBy(A).Should().BeTrue();
    }

    [Fact]
    public void Players_who_share_a_match_skip_the_request()
    {
        Conversation.Direct(A, B, shareMatch: true, Now).IsPendingRequest.Should().BeFalse();
    }

    [Fact]
    public void Only_the_recipient_can_accept_or_ignore()
    {
        var conversation = Conversation.Direct(A, B, shareMatch: false, Now);

        var accept = () => conversation.AcceptRequest(A);
        var ignore = () => conversation.IgnoreRequest(A);

        accept.Should().Throw<InvalidAggregateStateException>().Which.ErrorCode.Should().Be("NOT_THE_RECIPIENT");
        ignore.Should().Throw<InvalidAggregateStateException>();
    }

    [Fact]
    public void Nobody_can_send_to_an_inactive_account_in_a_direct_conversation()
    {
        var conversation = Conversation.Direct(A, B, shareMatch: true, Now);
        typeof(ConversationMember).GetProperty(nameof(ConversationMember.AccountInactive))!.SetValue(conversation.MemberOf(B), true);

        conversation.AllowsSendBy(A).Should().BeFalse();
    }

    [Fact]
    public void A_player_who_leaves_a_match_chat_keeps_history_up_to_that_point()
    {
        Guid host = Guid.NewGuid(), c = Guid.NewGuid();
        var conversation = Conversation.ForMatch(Guid.NewGuid(), "پدل", [host, A, B], Now);

        conversation.SyncMembers([host, B, c], lastSeq: 7, Now);

        var left = conversation.MemberOf(A)!;
        left.IsCurrent.Should().BeFalse();
        left.CanSee(7).Should().BeTrue();
        left.CanSee(8).Should().BeFalse();
        conversation.AllowsSendBy(A).Should().BeFalse();
        conversation.MemberOf(c)!.IsCurrent.Should().BeTrue();
    }

    [Fact]
    public void A_player_accepted_again_rejoins_the_match_chat()
    {
        var conversation = Conversation.ForMatch(Guid.NewGuid(), "پدل", [A, B], Now);
        conversation.SyncMembers([A], 3, Now);

        conversation.SyncMembers([A, B], 5, Now);

        conversation.MemberOf(B)!.IsCurrent.Should().BeTrue();
    }

    [Fact]
    public void The_read_cursor_only_moves_forward()
    {
        var member = Conversation.Direct(A, B, true, Now).MemberOf(A)!;

        member.MarkReadUpTo(10);
        member.MarkReadUpTo(4);

        member.LastReadSeq.Should().Be(10);
    }

    [Theory]
    [InlineData("   ", "MESSAGE_EMPTY")]
    [InlineData(null, "MESSAGE_EMPTY")]
    public void Blank_messages_are_rejected(string? body, string code)
    {
        var write = () => Message.Write(Guid.NewGuid(), A, "c1", body, Conversation.MaxLength, Now);
        write.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be(code);
    }

    [Fact]
    public void Messages_are_trimmed_and_limited()
    {
        Message.Write(Guid.NewGuid(), A, "c1", "  سلام  ", 1000, Now).Body.Should().Be("سلام");
        var tooLong = () => Message.Write(Guid.NewGuid(), A, "c1", new string('ب', 1001), 1000, Now);
        tooLong.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("MESSAGE_TOO_LONG");
    }

    [Fact]
    public void Only_the_sender_deletes_a_message_and_its_text_is_gone()
    {
        var message = Message.Write(Guid.NewGuid(), A, "c1", "اشتباه", 1000, Now);

        var byOther = () => message.Delete(B, Now);
        message.Delete(A, Now);

        byOther.Should().Throw<InvalidAggregateStateException>();
        message.IsDeleted.Should().BeTrue();
        message.Body.Should().BeNull();
    }
}
