using Rallyto.Core.Application.Abstractions;

namespace Rallyto.Contracts.Community;

public static class SafetyTopics
{
    public const string PlayerWarned = "rallyto.community.player-warned";
    public const string MessageRemovalRequested = "rallyto.community.message-removal-requested";
}

/// <summary>An admin warned the player; Notifications delivers the text (spec trust-safety › Admin actions).</summary>
public sealed record PlayerWarned(Guid UserId, string Text, string Reason) : IntegrationEvent
{
    public override string Topic => SafetyTopics.PlayerWarned;
}

/// <summary>An admin deleted a message for everyone as a moderation action; Messaging owns the message and deletes it.</summary>
public sealed record MessageRemovalRequested(Guid MessageId, Guid AdminId) : IntegrationEvent
{
    public override string Topic => SafetyTopics.MessageRemovalRequested;
}
