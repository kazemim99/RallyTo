namespace Rallyto.Core.Domain.Abstractions;

public interface IEntity<out TId> where TId : notnull
{
    TId Id { get; }
}

public interface IAuditableEntity
{
    DateTime CreatedAt { get; }
    string? CreatedBy { get; }
    DateTime? LastModifiedAt { get; }
    string? LastModifiedBy { get; }

    void MarkCreated(DateTime utcNow, string? by);
    void MarkModified(DateTime utcNow, string? by);
}

public interface IDomainEvent
{
    Guid EventId { get; }
    DateTime OccurredAt { get; }
}

/// <summary>Implemented by aggregates so the unit of work can collect their events.</summary>
public interface IHasDomainEvents
{
    IReadOnlyList<IDomainEvent> DomainEvents { get; }
    void ClearDomainEvents();
}

public interface IBusinessRule
{
    string ErrorCode { get; }
    string Message { get; }
    bool IsBroken();
}
