using Rallyto.Core.Application.Abstractions;

namespace Rallyto.Contracts.Messaging;

public static class MessagingTopics
{
    public const string MessageReceivedOffline = "rallyto.messaging.message-received-offline";
}

/// <summary>A member with no live connection got a message in a conversation they have not muted. Notifications sends the push.</summary>
public sealed record MessageReceivedOffline(
    Guid ConversationId,
    Guid MessageId,
    Guid RecipientId,
    Guid SenderId,
    string SenderName,
    string Preview,
    bool IsRequest,
    bool IsGroup) : IntegrationEvent
{
    public override string Topic => MessagingTopics.MessageReceivedOffline;
}
