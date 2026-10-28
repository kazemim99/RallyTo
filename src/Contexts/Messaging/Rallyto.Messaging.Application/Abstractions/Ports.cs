using Rallyto.Messaging.Domain.Conversations;

namespace Rallyto.Messaging.Application.Abstractions;

/// <summary>Whether a player may be contacted by the viewer, answered by Community (design D3).</summary>
/// <param name="ViewerHasProfile">False when the viewer has not created a player profile yet.</param>
/// <param name="DisplayName">The player's name, or null when they do not exist or are hidden from the viewer.</param>
public sealed record PlayerContact(bool ViewerHasProfile, string? DisplayName);

/// <summary>Community's answers about two players, in-process (design D3). Implemented in the host.</summary>
public interface IPlayerRelationshipReader
{
    /// <summary>Applies the visibility rule (blocks both ways, same-gender visibility, inactive profiles).</summary>
    Task<PlayerContact> FindContactAsync(Guid viewerId, Guid playerId, CancellationToken cancellationToken);

    /// <summary>Whether both players hold a place in the same live or played game.</summary>
    Task<bool> ShareMatchAsync(Guid a, Guid b, CancellationToken cancellationToken);

    /// <summary>Display names; a deleted account's profile already carries the «کاربر حذف‌شده» placeholder.</summary>
    Task<IReadOnlyDictionary<Guid, string>> DisplayNamesAsync(IReadOnlyCollection<Guid> userIds, CancellationToken cancellationToken);
}

/// <summary>The blocks one player is part of.</summary>
public sealed record BlockSets(IReadOnlySet<Guid> BlockedByMe, IReadOnlySet<Guid> BlockedMe)
{
    public bool EitherWay(Guid other) => BlockedByMe.Contains(other) || BlockedMe.Contains(other);
}

public interface IBlockReader
{
    Task<bool> IsBlockedEitherWayAsync(Guid a, Guid b, CancellationToken cancellationToken);

    Task<BlockSets> BlocksOfAsync(Guid userId, CancellationToken cancellationToken);
}

/// <summary>The players holding a place in a match, for its group conversation.</summary>
public sealed record MatchRoster(Guid MatchId, int Capacity, string Title, IReadOnlyList<Guid> PlayerIds);

public interface IMatchRosterReader
{
    Task<MatchRoster?> GetAsync(Guid matchId, CancellationToken cancellationToken);
}

public interface IConversationRepository
{
    Task<Conversation?> GetAsync(Guid id, CancellationToken cancellationToken);
    Task<Conversation?> GetDirectAsync(Guid a, Guid b, CancellationToken cancellationToken);
    Task<Conversation?> GetForMatchAsync(Guid matchId, CancellationToken cancellationToken);
    Task<IReadOnlyList<Conversation>> ListForMemberAsync(Guid userId, CancellationToken cancellationToken);
    Task<int> CountStartedSinceAsync(Guid initiatorId, DateTime since, CancellationToken cancellationToken);
    void Add(Conversation conversation);
}

/// <summary>Last visible message of a conversation for one member.</summary>
public sealed record LastMessage(Guid ConversationId, string? Body, bool Deleted, DateTime SentAt);

public interface IMessageRepository
{
    Task<Message?> GetAsync(Guid conversationId, Guid messageId, CancellationToken cancellationToken);
    Task<Message?> FindByClientIdAsync(Guid conversationId, Guid senderId, string clientMessageId, CancellationToken cancellationToken);
    Task<long> LastSeqAsync(Guid conversationId, CancellationToken cancellationToken);

    /// <summary>Newest first, older than <paramref name="beforeSeq"/>, up to the member's leave point, without hidden senders.</summary>
    Task<IReadOnlyList<Message>> HistoryAsync(Guid conversationId, long? beforeSeq, long? upToSeq, IReadOnlySet<Guid> hiddenSenders, int take, CancellationToken cancellationToken);

    Task<IReadOnlyDictionary<Guid, LastMessage>> LastMessagesAsync(Guid userId, IReadOnlyCollection<Guid> conversationIds, IReadOnlySet<Guid> hiddenSenders, CancellationToken cancellationToken);
    Task<IReadOnlyDictionary<Guid, int>> UnreadCountsAsync(Guid userId, IReadOnlyCollection<Guid> conversationIds, IReadOnlySet<Guid> hiddenSenders, CancellationToken cancellationToken);
    void Add(Message message);
}
