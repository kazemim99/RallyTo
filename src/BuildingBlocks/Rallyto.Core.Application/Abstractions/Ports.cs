using Rallyto.Core.Domain.Abstractions;

namespace Rallyto.Core.Application.Abstractions;

/// <summary>
/// A bounded context's unit of work. Each context registers its own marker interface deriving from this one
/// (for example <c>ICommunityUnitOfWork</c>) and handlers save through that marker only (design D12).
/// </summary>
public interface IUnitOfWork
{
    /// <summary>
    /// Dispatches pending domain events in-process, then saves the changes and the buffered integration events
    /// in one transaction (CAP outbox).
    /// </summary>
    Task SaveAndPublishEventsAsync(CancellationToken cancellationToken = default);
}

public interface ICurrentUserService
{
    Guid? UserId { get; }
    bool IsAuthenticated { get; }
    IReadOnlyCollection<string> Roles { get; }
    bool IsInRole(string role);
    string? IpAddress { get; }
    string? UserAgent { get; }

    /// <summary>The signed-in user's id, or <see cref="Exceptions.UnauthorizedException"/>.</summary>
    Guid RequireUserId();
}

public interface IDomainEventHandler<in TEvent> where TEvent : IDomainEvent
{
    Task HandleAsync(TEvent domainEvent, CancellationToken cancellationToken);
}

/// <summary>
/// Pushes events to connected clients over the realtime hub. Contexts depend on this interface, never on
/// SignalR (design D8).
/// </summary>
public interface IRealtimePublisher
{
    Task PublishToUsersAsync(IReadOnlyCollection<Guid> userIds, string eventName, object payload, CancellationToken cancellationToken = default);

    Task DisconnectUserAsync(Guid userId, CancellationToken cancellationToken = default);
}

public interface ICacheInvalidator
{
    Task InvalidateTagsAsync(IEnumerable<string> tags, CancellationToken cancellationToken = default);
}
