using Rallyto.Core.Domain.Abstractions;

namespace Rallyto.Core.Domain.Base;

public abstract class Entity<TId> : IEntity<TId>, IAuditableEntity, IEquatable<Entity<TId>>
    where TId : notnull
{
    public TId Id { get; protected set; } = default!;
    public DateTime CreatedAt { get; private set; }
    public string? CreatedBy { get; private set; }
    public DateTime? LastModifiedAt { get; private set; }
    public string? LastModifiedBy { get; private set; }

    protected Entity() { }

    protected Entity(TId id) => Id = id;

    public bool IsTransient() => EqualityComparer<TId>.Default.Equals(Id, default!);

    void IAuditableEntity.MarkCreated(DateTime utcNow, string? by)
    {
        CreatedAt = utcNow;
        CreatedBy = by;
    }

    void IAuditableEntity.MarkModified(DateTime utcNow, string? by)
    {
        LastModifiedAt = utcNow;
        LastModifiedBy = by;
    }

    public bool Equals(Entity<TId>? other)
    {
        if (other is null) return false;
        if (ReferenceEquals(this, other)) return true;
        if (GetType() != other.GetType() || IsTransient() || other.IsTransient()) return false;
        return EqualityComparer<TId>.Default.Equals(Id, other.Id);
    }

    public override bool Equals(object? obj) => obj is Entity<TId> other && Equals(other);

    // Transient entities fall back to reference identity, like AsanRezerve's Entity.
    public override int GetHashCode() => IsTransient() ? base.GetHashCode() : HashCode.Combine(GetType(), Id);

    public static bool operator ==(Entity<TId>? left, Entity<TId>? right) => left?.Equals(right) ?? right is null;

    public static bool operator !=(Entity<TId>? left, Entity<TId>? right) => !(left == right);

    public override string ToString() => $"{GetType().Name} [Id={Id}]";
}
