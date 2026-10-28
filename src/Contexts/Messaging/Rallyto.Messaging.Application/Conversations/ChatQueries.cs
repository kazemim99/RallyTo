using System.Globalization;
using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Messaging.Application.Abstractions;
using Rallyto.Messaging.Domain.Conversations;

namespace Rallyto.Messaging.Application.Conversations;

public enum ConversationBox
{
    Inbox = 1,
    Requests = 2,
}

public sealed record ListConversationsQuery(ConversationBox Box) : IQuery<IReadOnlyList<ConversationSummary>>;

public sealed record GetConversationQuery(Guid ConversationId) : IQuery<ConversationSummary>;

/// <summary>The group conversation of a match, for its members only.</summary>
public sealed record GetMatchConversationQuery(Guid MatchId) : IQuery<ConversationSummary>;

public sealed record GetHistoryQuery(Guid ConversationId, string? Before) : IQuery<MessagePage>;

public sealed record GetUnreadCountsQuery : IQuery<UnreadCountsView>;

/// <summary>Sorts a member's conversations into the inbox and the requests list (spec chat › Message requests, Blocking in chat).</summary>
public sealed class ConversationLists(ChatSession session, IConversationRepository conversations, IBlockReader blocks, ConversationAssembler assembler)
{
    public async Task<(IReadOnlyList<ConversationSummary> Inbox, IReadOnlyList<ConversationSummary> Requests)> LoadAsync(CancellationToken cancellationToken)
    {
        var me = session.UserId;
        var blockSets = await blocks.BlocksOfAsync(me, cancellationToken);
        // The blocker no longer sees the direct conversation; the blocked player still does, read-only.
        var mine = (await conversations.ListForMemberAsync(me, cancellationToken))
            .Where(c => c.OtherMember(me) is not { } other || !blockSets.BlockedByMe.Contains(other.UserId))
            .ToList();
        var summaries = await assembler.SummariesAsync(me, mine, blockSets, cancellationToken);
        var byId = mine.ToDictionary(c => c.Id);
        var inbox = new List<ConversationSummary>();
        var requests = new List<ConversationSummary>();
        foreach (var summary in summaries)
        {
            var conversation = byId[summary.Id];
            if (conversation.IsRequestRecipient(me) && conversation.IsPendingRequest)
            {
                // Ignored requests leave the list silently; an empty request is not shown yet.
                if (conversation.RequestState == RequestState.Pending && summary.LastMessageAt is not null)
                    requests.Add(summary);
            }
            else if (summary.LastMessageAt is not null || conversation.Kind == ConversationKind.Match || conversation.InitiatorId == me)
            {
                inbox.Add(summary);
            }
        }

        return (Newest(inbox, byId), Newest(requests, byId));
    }

    private static List<ConversationSummary> Newest(IEnumerable<ConversationSummary> list, IReadOnlyDictionary<Guid, Conversation> byId) =>
        list.OrderByDescending(s => s.LastMessageAt ?? byId[s.Id].StartedAt).ToList();
}

internal sealed class ListConversationsHandler(ConversationLists lists) : IQueryHandler<ListConversationsQuery, IReadOnlyList<ConversationSummary>>
{
    public async Task<IReadOnlyList<ConversationSummary>> Handle(ListConversationsQuery request, CancellationToken cancellationToken)
    {
        var (inbox, requests) = await lists.LoadAsync(cancellationToken);
        return request.Box == ConversationBox.Requests ? requests : inbox;
    }
}

internal sealed class GetConversationHandler(ChatSession session, ConversationAssembler assembler) : IQueryHandler<GetConversationQuery, ConversationSummary>
{
    public async Task<ConversationSummary> Handle(GetConversationQuery request, CancellationToken cancellationToken)
    {
        var (conversation, _) = await session.RequireMembershipAsync(request.ConversationId, cancellationToken);
        return await assembler.SummaryAsync(session.UserId, conversation, cancellationToken);
    }
}

internal sealed class GetMatchConversationHandler(ChatSession session, IConversationRepository conversations, ConversationAssembler assembler)
    : IQueryHandler<GetMatchConversationQuery, ConversationSummary>
{
    public async Task<ConversationSummary> Handle(GetMatchConversationQuery request, CancellationToken cancellationToken)
    {
        var conversation = await conversations.GetForMatchAsync(request.MatchId, cancellationToken);
        if (conversation?.MemberOf(session.UserId) is null)
            throw ChatErrors.ConversationNotFound();
        return await assembler.SummaryAsync(session.UserId, conversation, cancellationToken);
    }
}

/// <summary>Newest first, 50 per page; the cursor is the sequence number of the oldest message on the page.</summary>
internal sealed class GetHistoryHandler(ChatSession session, IMessageRepository messages, IBlockReader blocks, ConversationAssembler assembler)
    : IQueryHandler<GetHistoryQuery, MessagePage>
{
    public const int PageSize = 50;

    public async Task<MessagePage> Handle(GetHistoryQuery request, CancellationToken cancellationToken)
    {
        var (conversation, member) = await session.RequireMembershipAsync(request.ConversationId, cancellationToken);
        long? before = null;
        if (!string.IsNullOrEmpty(request.Before))
        {
            if (!long.TryParse(request.Before, NumberStyles.None, CultureInfo.InvariantCulture, out var seq))
                throw new ValidationFailedException("INVALID_CURSOR", "نشانگر صفحه معتبر نیست.");
            before = seq;
        }

        // In a group, a player the member blocked is hidden from them (spec chat › Blocking in chat).
        var hidden = conversation.Kind == ConversationKind.Match
            ? (await blocks.BlocksOfAsync(member.UserId, cancellationToken)).BlockedByMe
            : new HashSet<Guid>();
        var page = await messages.HistoryAsync(conversation.Id, before, member.LeftAfterSeq, hidden, PageSize + 1, cancellationToken);
        var items = page.Take(PageSize).ToList();
        var next = page.Count > PageSize ? items[^1].Seq.ToString(CultureInfo.InvariantCulture) : null;
        return new MessagePage(await assembler.MessagesAsync(conversation, items, cancellationToken), next);
    }
}

internal sealed class GetUnreadCountsHandler(ConversationLists lists) : IQueryHandler<GetUnreadCountsQuery, UnreadCountsView>
{
    public async Task<UnreadCountsView> Handle(GetUnreadCountsQuery request, CancellationToken cancellationToken)
    {
        var (inbox, requests) = await lists.LoadAsync(cancellationToken);
        return new UnreadCountsView(inbox.Count(c => c.UnreadCount > 0), requests.Count(c => c.UnreadCount > 0));
    }
}
