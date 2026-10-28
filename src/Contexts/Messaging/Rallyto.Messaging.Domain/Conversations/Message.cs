using Rallyto.Core.Domain.Base;
using Rallyto.Core.Domain.Exceptions;

namespace Rallyto.Messaging.Domain.Conversations;

/// <summary>A text message. The client-generated id makes sending idempotent (spec chat › Retry does not duplicate).</summary>
public sealed class Message : AggregateRoot<Guid>
{
    public const int MaxClientIdLength = 64;

    private Message() { }

    /// <summary>Database-assigned order of messages; read cursors and history pages use it.</summary>
    public long Seq { get; private set; }

    public Guid ConversationId { get; private set; }
    public Guid SenderId { get; private set; }
    public string ClientMessageId { get; private set; } = string.Empty;

    /// <summary>Null once the sender deleted the message for everyone.</summary>
    public string? Body { get; private set; }

    public DateTime SentAt { get; private set; }
    public DateTime? DeletedAt { get; private set; }

    public bool IsDeleted => DeletedAt is not null;

    public static Message Write(Guid conversationId, Guid senderId, string clientMessageId, string? body, int maxLength, DateTime now)
    {
        var text = body?.Trim() ?? string.Empty;
        if (text.Length == 0)
            throw new BusinessRuleViolationException("MESSAGE_EMPTY", "پیام خالی است.");
        if (text.Length > maxLength)
            throw new BusinessRuleViolationException("MESSAGE_TOO_LONG", $"پیام حداکثر {maxLength} نویسه است.");
        var clientId = clientMessageId?.Trim() ?? string.Empty;
        if (clientId.Length is 0 or > MaxClientIdLength)
            throw new BusinessRuleViolationException("INVALID_CLIENT_MESSAGE_ID", "شناسهٔ پیام معتبر نیست.");
        return new Message
        {
            Id = Guid.NewGuid(),
            ConversationId = conversationId,
            SenderId = senderId,
            ClientMessageId = clientId,
            Body = text,
            SentAt = now,
        };
    }

    /// <summary>Deleted for everyone; a report filed earlier keeps its own snapshot of the text (spec chat › Deleting a message).</summary>
    public void Delete(Guid userId, DateTime now)
    {
        if (userId != SenderId)
            throw new InvalidAggregateStateException("NOT_THE_SENDER", "فقط فرستنده می‌تواند پیام را حذف کند.");
        if (IsDeleted)
            return;
        Body = null;
        DeletedAt = now;
    }

    /// <summary>Deleted for everyone by an admin as a moderation action (spec trust-safety › Admin actions).</summary>
    public void RemoveByModerator(DateTime now)
    {
        Body = null;
        DeletedAt ??= now;
    }
}
