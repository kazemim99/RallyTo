using Rallyto.Core.Domain.Base;
using Rallyto.Core.Domain.Exceptions;

namespace Rallyto.Messaging.Domain.Conversations;

public enum ConversationKind
{
    Direct = 1,
    Match = 2,
}

/// <summary>Message-request state of a direct conversation; the recipient is the member who did not start it (spec chat › Message requests).</summary>
public enum RequestState
{
    None = 0,
    Pending = 1,
    Ignored = 2,
}

public sealed class ConversationMember
{
    private ConversationMember() { }

    internal ConversationMember(Guid conversationId, Guid userId, DateTime now)
    {
        ConversationId = conversationId;
        UserId = userId;
        JoinedAt = now;
    }

    public Guid ConversationId { get; private set; }
    public Guid UserId { get; private set; }
    public DateTime JoinedAt { get; private set; }

    /// <summary>Read cursor: the sequence number of the last message this member has read (design D8).</summary>
    public long LastReadSeq { get; private set; }

    public bool Muted { get; private set; }

    /// <summary>Set when the member left a match chat: they keep the history up to this message and nothing after it.</summary>
    public long? LeftAfterSeq { get; private set; }

    /// <summary>The member's account is suspended, banned or deleted: nobody can send to them in a direct conversation.</summary>
    public bool AccountInactive { get; private set; }

    public bool IsCurrent => LeftAfterSeq is null;

    public bool CanSee(long seq) => LeftAfterSeq is not { } last || seq <= last;

    public void MarkReadUpTo(long seq)
    {
        if (seq > LastReadSeq)
            LastReadSeq = seq;
    }

    public void Mute(bool muted) => Muted = muted;

    internal void Leave(long lastSeq) => LeftAfterSeq ??= lastSeq;

    internal void Rejoin() => LeftAfterSeq = null;
}

/// <summary>
/// A direct conversation between two players, or the group conversation of a match (design D8). Messages are a
/// separate aggregate; the conversation owns membership, the request state and per-member read state.
/// </summary>
public sealed class Conversation : AggregateRoot<Guid>
{
    public const int MaxLength = 1000;
    public const int RequestMaxLength = 500;

    private readonly List<ConversationMember> _members = [];

    private Conversation() { }

    public ConversationKind Kind { get; private set; }
    public Guid? MatchId { get; private set; }
    public string? Title { get; private set; }

    /// <summary>The player who opened a direct conversation; the other member is the request recipient.</summary>
    public Guid? InitiatorId { get; private set; }

    /// <summary>"smaller-id:larger-id", unique, so each pair has one direct conversation.</summary>
    public string? DirectKey { get; private set; }

    public RequestState RequestState { get; private set; }
    public bool RequestMessageSent { get; private set; }
    public DateTime StartedAt { get; private set; }
    public uint Version { get; private set; }

    public IReadOnlyList<ConversationMember> Members => _members;

    public bool IsPendingRequest => RequestState != RequestState.None;

    public static string KeyOf(Guid a, Guid b) => a.CompareTo(b) < 0 ? $"{a:N}:{b:N}" : $"{b:N}:{a:N}";

    /// <param name="shareMatch">Whether the two players already share a game; then no request is needed.</param>
    public static Conversation Direct(Guid initiatorId, Guid otherId, bool shareMatch, DateTime now)
    {
        if (initiatorId == otherId)
            throw new BusinessRuleViolationException("CANNOT_MESSAGE_SELF", "نمی‌توانید به خودتان پیام بدهید.");
        var conversation = new Conversation
        {
            Id = Guid.NewGuid(),
            Kind = ConversationKind.Direct,
            InitiatorId = initiatorId,
            DirectKey = KeyOf(initiatorId, otherId),
            RequestState = shareMatch ? RequestState.None : RequestState.Pending,
            StartedAt = now,
        };
        conversation._members.Add(new ConversationMember(conversation.Id, initiatorId, now));
        conversation._members.Add(new ConversationMember(conversation.Id, otherId, now));
        return conversation;
    }

    public static Conversation ForMatch(Guid matchId, string title, IEnumerable<Guid> playerIds, DateTime now)
    {
        var conversation = new Conversation
        {
            Id = Guid.NewGuid(),
            Kind = ConversationKind.Match,
            MatchId = matchId,
            Title = title,
            StartedAt = now,
        };
        foreach (var playerId in playerIds.Distinct())
            conversation._members.Add(new ConversationMember(conversation.Id, playerId, now));
        return conversation;
    }

    public ConversationMember? MemberOf(Guid userId) => _members.FirstOrDefault(m => m.UserId == userId);

    /// <summary>The other member of a direct conversation.</summary>
    public ConversationMember? OtherMember(Guid userId) =>
        Kind == ConversationKind.Direct ? _members.FirstOrDefault(m => m.UserId != userId) : null;

    public bool IsRequestRecipient(Guid userId) => Kind == ConversationKind.Direct && InitiatorId != userId && MemberOf(userId) is not null;

    public void AcceptRequest(Guid userId)
    {
        if (!IsRequestRecipient(userId))
            throw new InvalidAggregateStateException("NOT_THE_RECIPIENT", "فقط گیرندهٔ درخواست می‌تواند آن را بپذیرد.");
        RequestState = RequestState.None;
    }

    /// <summary>Ignoring is silent: the sender sees no change (spec chat › Recipient ignores).</summary>
    public void IgnoreRequest(Guid userId)
    {
        if (!IsRequestRecipient(userId))
            throw new InvalidAggregateStateException("NOT_THE_RECIPIENT", "فقط گیرندهٔ درخواست می‌تواند آن را نادیده بگیرد.");
        if (RequestState == RequestState.Pending)
            RequestState = RequestState.Ignored;
    }

    /// <summary>The two players now share a game, so the request is no longer needed.</summary>
    public void AcceptBecauseOfSharedMatch() => RequestState = RequestState.None;

    /// <summary>
    /// Applies the message-request rules to a send by a current member and returns the length limit for it. While
    /// the conversation is a request the initiator may send one message of up to 500 characters; a reply from the
    /// recipient accepts the request.
    /// </summary>
    public int RecordSend(Guid senderId)
    {
        if (!IsPendingRequest)
            return MaxLength;
        if (senderId != InitiatorId)
        {
            RequestState = RequestState.None;
            return MaxLength;
        }

        if (RequestMessageSent)
            throw new InvalidAggregateStateException("REQUEST_NOT_ACCEPTED", "تا پذیرفته شدن درخواستتان صبر کنید.");
        RequestMessageSent = true;
        return RequestMaxLength;
    }

    /// <summary>Whether the member could send right now, from this aggregate's point of view (blocks are checked by the caller).</summary>
    public bool AllowsSendBy(Guid userId)
    {
        var member = MemberOf(userId);
        if (member is null || !member.IsCurrent)
            return false;
        if (Kind == ConversationKind.Match)
            return true;
        if (OtherMember(userId) is { AccountInactive: true })
            return false;
        return !IsPendingRequest || userId != InitiatorId || !RequestMessageSent;
    }

    /// <summary>Makes the match chat's members follow the match roster (spec chat › Match group conversations).</summary>
    public void SyncMembers(IReadOnlyCollection<Guid> playerIds, long lastSeq, DateTime now)
    {
        if (Kind != ConversationKind.Match)
            throw new InvalidAggregateStateException("NOT_A_MATCH_CHAT", "این گفتگو مربوط به بازی نیست.");
        foreach (var member in _members)
        {
            if (playerIds.Contains(member.UserId))
                member.Rejoin();
            else
                member.Leave(lastSeq);
        }

        foreach (var playerId in playerIds.Where(id => MemberOf(id) is null))
            _members.Add(new ConversationMember(Id, playerId, now));
    }
}
