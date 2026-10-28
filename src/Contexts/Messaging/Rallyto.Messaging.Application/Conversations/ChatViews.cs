using Rallyto.Core.Application.Exceptions;
using Rallyto.Messaging.Application.Abstractions;
using Rallyto.Messaging.Domain.Conversations;

namespace Rallyto.Messaging.Application.Conversations;

public sealed record ConversationSummary(
    Guid Id,
    ConversationKind Kind,
    Guid? MatchId,
    string Title,
    Guid? OtherUserId,
    string? LastMessage,
    DateTime? LastMessageAt,
    int UnreadCount,
    bool IsRequest,
    bool CanSend,
    bool Muted,
    bool IsRequestRecipient);

public sealed record MessageView(
    Guid Id,
    Guid ConversationId,
    Guid SenderId,
    string SenderName,
    string? Body,
    bool Deleted,
    DateTime SentAt,
    bool ReadByOthers,
    string ClientMessageId);

public sealed record MessagePage(IReadOnlyList<MessageView> Items, string? NextCursor);

public sealed record UnreadCountsView(int Conversations, int Requests);

/// <summary>Realtime event names on <c>/hubs/realtime</c> (design D8).</summary>
public static class ChatEvents
{
    public const string MessageReceived = "message.received";
    public const string MessageDeleted = "message.deleted";
    public const string ConversationRead = "conversation.read";
}

public static class ChatErrors
{
    public const string DeletedUserName = "کاربر حذف‌شده";
    public const string DeletedMessage = "پیام حذف شد";

    /// <summary>A conversation the caller is not a member of looks exactly like a missing one.</summary>
    public static NotFoundException ConversationNotFound() => new("گفتگو پیدا نشد.", "CONVERSATION_NOT_FOUND");

    /// <summary>The same answer for a block, a deleted account and a left match chat, so a block is never revealed.</summary>
    public static ForbiddenException CannotReply() => new("دیگر نمی‌توانید در این گفتگو پیام بفرستید.", "CANNOT_REPLY");

    public static NotFoundException PlayerNotFound() => new("بازیکن پیدا نشد.", "PLAYER_NOT_FOUND");

    public static ForbiddenException ProfileRequired() => new("ابتدا پروفایل خود را کامل کنید.", "PROFILE_REQUIRED");
}

/// <summary>Builds conversation and message views for one member.</summary>
public sealed class ConversationAssembler(IPlayerRelationshipReader players, IBlockReader blocks, IMessageRepository messages)
{
    public async Task<ConversationSummary> SummaryAsync(Guid me, Conversation conversation, CancellationToken cancellationToken) =>
        (await SummariesAsync(me, [conversation], await blocks.BlocksOfAsync(me, cancellationToken), cancellationToken)).Single();

    public async Task<IReadOnlyList<ConversationSummary>> SummariesAsync(Guid me, IReadOnlyList<Conversation> conversations, BlockSets blockSets, CancellationToken cancellationToken)
    {
        if (conversations.Count == 0)
            return [];
        var ids = conversations.Select(c => c.Id).ToList();
        var others = conversations.Select(c => c.OtherMember(me)?.UserId).OfType<Guid>().Distinct().ToList();
        var names = await players.DisplayNamesAsync(others, cancellationToken);
        var last = await messages.LastMessagesAsync(me, ids, blockSets.BlockedByMe, cancellationToken);
        var unread = await messages.UnreadCountsAsync(me, ids, blockSets.BlockedByMe, cancellationToken);
        return conversations.Select(c =>
        {
            var member = c.MemberOf(me)!;
            var other = c.OtherMember(me)?.UserId;
            var lastMessage = last.GetValueOrDefault(c.Id);
            return new ConversationSummary(
                c.Id,
                c.Kind,
                c.MatchId,
                other is { } otherId ? names.GetValueOrDefault(otherId, ChatErrors.DeletedUserName) : c.Title ?? string.Empty,
                other,
                lastMessage is null ? null : lastMessage.Deleted ? ChatErrors.DeletedMessage : lastMessage.Body,
                lastMessage?.SentAt,
                unread.GetValueOrDefault(c.Id),
                c.IsPendingRequest,
                c.AllowsSendBy(me) && (other is not { } o || !blockSets.EitherWay(o)),
                member.Muted,
                c.IsPendingRequest && c.IsRequestRecipient(me));
        }).ToList();
    }

    public async Task<IReadOnlyList<MessageView>> MessagesAsync(Conversation conversation, IReadOnlyList<Message> list, CancellationToken cancellationToken)
    {
        var names = await players.DisplayNamesAsync(list.Select(m => m.SenderId).Distinct().ToList(), cancellationToken);
        return list.Select(m => View(conversation, m, names.GetValueOrDefault(m.SenderId, ChatErrors.DeletedUserName))).ToList();
    }

    public static MessageView View(Conversation conversation, Message message, string senderName)
    {
        var readers = conversation.Members.Where(m => m.UserId != message.SenderId && m.IsCurrent).ToList();
        return new MessageView(
            message.Id,
            message.ConversationId,
            message.SenderId,
            senderName,
            message.Body,
            message.IsDeleted,
            message.SentAt,
            readers.Count > 0 && readers.All(m => m.LastReadSeq >= message.Seq),
            message.ClientMessageId);
    }
}
