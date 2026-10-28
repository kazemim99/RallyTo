using Rallyto.Core.Application.Abstractions;

namespace Rallyto.Contracts.Community;

public static class MatchTopics
{
    public const string InvitationReceived = "rallyto.community.invitation-received";
    public const string InvitationAnswered = "rallyto.community.invitation-answered";
    public const string JoinRequestReceived = "rallyto.community.join-request-received";
    public const string JoinRequestAnswered = "rallyto.community.join-request-answered";
    public const string MatchConfirmed = "rallyto.community.match-confirmed";
    public const string MatchCancelled = "rallyto.community.match-cancelled";
    public const string MatchExpired = "rallyto.community.match-expired";
    public const string ParticipantLeft = "rallyto.community.participant-left";
    public const string ParticipantRemoved = "rallyto.community.participant-removed";
    public const string AttendanceOpened = "rallyto.community.attendance-opened";
    public const string MatchResolved = "rallyto.community.match-resolved";
    public const string RatingReminderDue = "rallyto.community.rating-reminder-due";
}

public sealed record InvitationReceived(Guid MatchId, Guid HostId, Guid PlayerId) : IntegrationEvent
{
    public override string Topic => MatchTopics.InvitationReceived;
}

public sealed record InvitationAnswered(Guid MatchId, Guid HostId, Guid PlayerId, bool Accepted) : IntegrationEvent
{
    public override string Topic => MatchTopics.InvitationAnswered;
}

public sealed record JoinRequestReceived(Guid MatchId, Guid HostId, Guid PlayerId) : IntegrationEvent
{
    public override string Topic => MatchTopics.JoinRequestReceived;
}

public sealed record JoinRequestAnswered(Guid MatchId, Guid PlayerId, bool Accepted) : IntegrationEvent
{
    public override string Topic => MatchTopics.JoinRequestAnswered;
}

/// <summary>A match is on. Messaging opens chats between its players; Notifications tells them.</summary>
public sealed record MatchConfirmed(Guid MatchId, Guid HostId, IReadOnlyList<Guid> PlayerIds, int Capacity) : IntegrationEvent
{
    public override string Topic => MatchTopics.MatchConfirmed;
}

public sealed record MatchCancelled(Guid MatchId, Guid HostId, IReadOnlyList<Guid> PlayerIds, string? Reason, DateTime StartsAt) : IntegrationEvent
{
    public override string Topic => MatchTopics.MatchCancelled;
}

public sealed record MatchExpired(Guid MatchId, Guid HostId) : IntegrationEvent
{
    public override string Topic => MatchTopics.MatchExpired;
}

public sealed record ParticipantLeft(Guid MatchId, Guid HostId, Guid PlayerId, IReadOnlyList<Guid> RemainingPlayerIds) : IntegrationEvent
{
    public override string Topic => MatchTopics.ParticipantLeft;
}

public sealed record ParticipantRemoved(Guid MatchId, Guid PlayerId, IReadOnlyList<Guid> RemainingPlayerIds) : IntegrationEvent
{
    public override string Topic => MatchTopics.ParticipantRemoved;
}

/// <summary>A Confirmed game ended; its players are asked whether it was played.</summary>
public sealed record AttendanceOpened(Guid MatchId, IReadOnlyList<Guid> PlayerIds) : IntegrationEvent
{
    public override string Topic => MatchTopics.AttendanceOpened;
}

/// <summary>Attendance was resolved. For a Completed match, every Played player is asked to rate the others.</summary>
public sealed record MatchResolved(Guid MatchId, Guid SportId, string Outcome, IReadOnlyList<Guid> PlayedIds, IReadOnlyList<Guid> NoShowIds) : IntegrationEvent
{
    public override string Topic => MatchTopics.MatchResolved;
}

/// <summary>Day 5 after resolution: the player has not rated these partners yet (sent once).</summary>
public sealed record RatingReminderDue(Guid MatchId, Guid PlayerId, IReadOnlyList<Guid> PendingRateeIds) : IntegrationEvent
{
    public override string Topic => MatchTopics.RatingReminderDue;
}
