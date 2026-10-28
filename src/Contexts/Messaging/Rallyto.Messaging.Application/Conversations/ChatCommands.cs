using Rallyto.Contracts.Messaging;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Messaging.Application.Abstractions;
using Rallyto.Messaging.Domain.Conversations;

namespace Rallyto.Messaging.Application.Conversations;

public sealed record OpenDirectConversationCommand(Guid PlayerId) : ICommand<ConversationSummary>;

public sealed record SendMessageCommand(Guid ConversationId, string ClientMessageId, string? Body) : ICommand<MessageView>;

public sealed record AcceptRequestCommand(Guid ConversationId) : ICommand<ConversationSummary>;

public sealed record IgnoreRequestCommand(Guid ConversationId) : ICommand<ConversationSummary>;

public sealed record MarkReadCommand(Guid ConversationId, Guid UpToMessageId) : ICommand;

public sealed record DeleteMessageCommand(Guid ConversationId, Guid MessageId) : ICommand;

public sealed record MuteConversationCommand(Guid ConversationId, bool Muted) : ICommand<ConversationSummary>;

/// <summary>Loads a conversation for its member; anyone else gets "not found".</summary>
public sealed class ChatSession(ICurrentUserService currentUser, IConversationRepository conversations)
{
    public Guid UserId => currentUser.RequireUserId();

    public async Task<(Conversation Conversation, ConversationMember Member)> RequireMembershipAsync(Guid conversationId, CancellationToken cancellationToken)
    {
        var conversation = await conversations.GetAsync(conversationId, cancellationToken);
        return conversation?.MemberOf(UserId) is { } member ? (conversation, member) : throw ChatErrors.ConversationNotFound();
    }
}

internal sealed class OpenDirectConversationHandler(
    ChatSession session,
    IConversationRepository conversations,
    IPlayerRelationshipReader players,
    ConversationAssembler assembler,
    IMessagingUnitOfWork unitOfWork,
    TimeProvider clock) : ICommandHandler<OpenDirectConversationCommand, ConversationSummary>
{
    public const int MaxNewPerDay = 20;

    public async Task<ConversationSummary> Handle(OpenDirectConversationCommand request, CancellationToken cancellationToken)
    {
        var me = session.UserId;
        if (request.PlayerId == me)
            throw new ValidationFailedException("CANNOT_MESSAGE_SELF", "نمی‌توانید به خودتان پیام بدهید.");
        var contact = await players.FindContactAsync(me, request.PlayerId, cancellationToken);
        if (!contact.ViewerHasProfile)
            throw ChatErrors.ProfileRequired();
        if (contact.DisplayName is null)
            throw ChatErrors.PlayerNotFound();

        var now = clock.GetUtcNow().UtcDateTime;
        var conversation = await conversations.GetDirectAsync(me, request.PlayerId, cancellationToken);
        if (conversation is null)
        {
            if (await conversations.CountStartedSinceAsync(me, now.AddDays(-1), cancellationToken) >= MaxNewPerDay)
                throw new TooManyRequestsException("امروز گفتگوی جدید زیادی شروع کرده‌اید. فردا دوباره تلاش کنید.", TimeSpan.FromHours(1));
            conversation = Conversation.Direct(me, request.PlayerId, await players.ShareMatchAsync(me, request.PlayerId, cancellationToken), now);
            conversations.Add(conversation);
            await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        }
        else if (conversation.IsPendingRequest && await players.ShareMatchAsync(me, request.PlayerId, cancellationToken))
        {
            conversation.AcceptBecauseOfSharedMatch();
            await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        }

        return await assembler.SummaryAsync(me, conversation, cancellationToken);
    }
}

/// <summary>
/// Sends a message: idempotent on the client id, then pushed in real time to online members and announced for push
/// to offline members who have not muted the conversation (design D8).
/// </summary>
internal sealed class SendMessageHandler(
    ChatSession session,
    IMessageRepository messages,
    IPlayerRelationshipReader players,
    IBlockReader blocks,
    IUserPresence presence,
    IRealtimePublisher realtime,
    IIntegrationEventPublisher events,
    IMessagingUnitOfWork unitOfWork,
    TimeProvider clock) : ICommandHandler<SendMessageCommand, MessageView>
{
    private const int PreviewLength = 80;

    public async Task<MessageView> Handle(SendMessageCommand request, CancellationToken cancellationToken)
    {
        var me = session.UserId;
        var (conversation, member) = await session.RequireMembershipAsync(request.ConversationId, cancellationToken);
        var names = await players.DisplayNamesAsync([me], cancellationToken);
        var myName = names.GetValueOrDefault(me, ChatErrors.DeletedUserName);
        if (await messages.FindByClientIdAsync(conversation.Id, me, request.ClientMessageId?.Trim() ?? string.Empty, cancellationToken) is { } existing)
            return ConversationAssembler.View(conversation, existing, myName);

        if (!member.IsCurrent)
            throw ChatErrors.CannotReply();
        var other = conversation.OtherMember(me);
        if (other is not null && (other.AccountInactive || await blocks.IsBlockedEitherWayAsync(me, other.UserId, cancellationToken)))
            throw ChatErrors.CannotReply();
        if (other is not null && conversation.IsPendingRequest && conversation.InitiatorId == me
            && await players.ShareMatchAsync(me, other.UserId, cancellationToken))
            conversation.AcceptBecauseOfSharedMatch();

        var wasRequest = conversation.IsPendingRequest;
        var maxLength = conversation.RecordSend(me);
        var message = Message.Write(conversation.Id, me, request.ClientMessageId!, request.Body, maxLength, clock.GetUtcNow().UtcDateTime);
        messages.Add(message);

        var recipients = await RecipientsAsync(conversation, me, cancellationToken);
        foreach (var recipient in recipients.Where(r => !r.Muted && !presence.IsOnline(r.UserId)))
            events.Enqueue(new MessageReceivedOffline(conversation.Id, message.Id, recipient.UserId, me, myName, Preview(message.Body!), wasRequest,
                conversation.Kind == ConversationKind.Match));
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);

        var view = ConversationAssembler.View(conversation, message, myName);
        await realtime.PublishToUsersAsync([me, .. recipients.Select(r => r.UserId)], ChatEvents.MessageReceived, view, cancellationToken);
        return view;
    }

    /// <summary>Current members other than the sender, without those who blocked the sender (their copy hides it anyway).</summary>
    private async Task<IReadOnlyList<ConversationMember>> RecipientsAsync(Conversation conversation, Guid me, CancellationToken cancellationToken)
    {
        var others = conversation.Members.Where(m => m.UserId != me && m.IsCurrent).ToList();
        if (conversation.Kind == ConversationKind.Direct)
            return others;
        var blockSets = await blocks.BlocksOfAsync(me, cancellationToken);
        return others.Where(m => !blockSets.BlockedMe.Contains(m.UserId)).ToList();
    }

    private static string Preview(string body) => body.Length <= PreviewLength ? body : body[..PreviewLength] + "…";
}

internal sealed class AcceptRequestHandler(ChatSession session, ConversationAssembler assembler, IMessagingUnitOfWork unitOfWork)
    : ICommandHandler<AcceptRequestCommand, ConversationSummary>
{
    public async Task<ConversationSummary> Handle(AcceptRequestCommand request, CancellationToken cancellationToken)
    {
        var (conversation, _) = await session.RequireMembershipAsync(request.ConversationId, cancellationToken);
        conversation.AcceptRequest(session.UserId);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return await assembler.SummaryAsync(session.UserId, conversation, cancellationToken);
    }
}

internal sealed class IgnoreRequestHandler(ChatSession session, ConversationAssembler assembler, IMessagingUnitOfWork unitOfWork)
    : ICommandHandler<IgnoreRequestCommand, ConversationSummary>
{
    public async Task<ConversationSummary> Handle(IgnoreRequestCommand request, CancellationToken cancellationToken)
    {
        var (conversation, _) = await session.RequireMembershipAsync(request.ConversationId, cancellationToken);
        conversation.IgnoreRequest(session.UserId);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return await assembler.SummaryAsync(session.UserId, conversation, cancellationToken);
    }
}

/// <summary>Moves the member's read cursor and tells the other members, who show their messages as read.</summary>
internal sealed class MarkReadHandler(ChatSession session, IMessageRepository messages, IRealtimePublisher realtime, IMessagingUnitOfWork unitOfWork)
    : ICommandHandler<MarkReadCommand>
{
    public async Task Handle(MarkReadCommand request, CancellationToken cancellationToken)
    {
        var (conversation, member) = await session.RequireMembershipAsync(request.ConversationId, cancellationToken);
        var message = await messages.GetAsync(conversation.Id, request.UpToMessageId, cancellationToken);
        if (message is null || !member.CanSee(message.Seq))
            throw new NotFoundException("پیام پیدا نشد.", "MESSAGE_NOT_FOUND");
        if (message.Seq <= member.LastReadSeq)
            return;
        member.MarkReadUpTo(message.Seq);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        var others = conversation.Members.Where(m => m.UserId != member.UserId && m.IsCurrent).Select(m => m.UserId).ToList();
        await realtime.PublishToUsersAsync(others, ChatEvents.ConversationRead,
            new { conversationId = conversation.Id, userId = member.UserId, upToMessageId = message.Id }, cancellationToken);
    }
}

internal sealed class DeleteMessageHandler(ChatSession session, IMessageRepository messages, IRealtimePublisher realtime, IMessagingUnitOfWork unitOfWork, TimeProvider clock)
    : ICommandHandler<DeleteMessageCommand>
{
    public async Task Handle(DeleteMessageCommand request, CancellationToken cancellationToken)
    {
        var (conversation, _) = await session.RequireMembershipAsync(request.ConversationId, cancellationToken);
        var message = await messages.GetAsync(conversation.Id, request.MessageId, cancellationToken);
        if (message is null || message.SenderId != session.UserId)
            throw new NotFoundException("پیام پیدا نشد.", "MESSAGE_NOT_FOUND");
        if (message.IsDeleted)
            return;
        message.Delete(session.UserId, clock.GetUtcNow().UtcDateTime);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        var members = conversation.Members.Where(m => m.IsCurrent).Select(m => m.UserId).ToList();
        await realtime.PublishToUsersAsync(members, ChatEvents.MessageDeleted, new { conversationId = conversation.Id, messageId = message.Id }, cancellationToken);
    }
}

internal sealed class MuteConversationHandler(ChatSession session, ConversationAssembler assembler, IMessagingUnitOfWork unitOfWork)
    : ICommandHandler<MuteConversationCommand, ConversationSummary>
{
    public async Task<ConversationSummary> Handle(MuteConversationCommand request, CancellationToken cancellationToken)
    {
        var (conversation, member) = await session.RequireMembershipAsync(request.ConversationId, cancellationToken);
        member.Mute(request.Muted);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return await assembler.SummaryAsync(session.UserId, conversation, cancellationToken);
    }
}
