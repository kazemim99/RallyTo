using Rallyto.Core.Domain.Abstractions;

namespace Rallyto.Core.Domain.Base;

public abstract record DomainEvent : IDomainEvent
{
    public Guid EventId { get; init; } = Guid.NewGuid();
    public DateTime OccurredAt { get; init; } = DateTime.UtcNow;
}
