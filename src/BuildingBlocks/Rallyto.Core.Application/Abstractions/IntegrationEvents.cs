namespace Rallyto.Core.Application.Abstractions;

/// <summary>
/// A fact published to other bounded contexts through CAP. <see cref="Topic"/> follows
/// <c>rallyto.&lt;context&gt;.&lt;event&gt;</c> (design D3); subscribers are idempotent on <see cref="EventId"/>.
/// </summary>
public abstract record IntegrationEvent
{
    public Guid EventId { get; init; } = Guid.NewGuid();
    public DateTime OccurredAt { get; init; } = DateTime.UtcNow;

    public abstract string Topic { get; }
}

public interface IIntegrationEventPublisher
{
    /// <summary>
    /// Buffers the event; it is written to the outbox in the same transaction as the next
    /// <see cref="IUnitOfWork.SaveAndPublishEventsAsync"/> of the current request.
    /// </summary>
    void Enqueue(IntegrationEvent integrationEvent);
}
