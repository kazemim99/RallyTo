using DotNetCore.CAP;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Domain.Abstractions;
using Rallyto.Infrastructure.Core.Events;

namespace Rallyto.Infrastructure.Core.Persistence;

/// <summary>
/// Unit of work of one bounded context. Each context derives a class that also implements its marker
/// interface (for example <c>CommunityUnitOfWork : EfUnitOfWork&lt;CommunityDbContext&gt;, ICommunityUnitOfWork</c>).
/// </summary>
public abstract class EfUnitOfWork<TContext>(
    TContext dbContext,
    DomainEventDispatcher dispatcher,
    IntegrationEventBuffer integrationEvents,
    ICapPublisher capPublisher,
    ILogger logger) : IUnitOfWork
    where TContext : DbContext
{
    private const int MaxDispatchRounds = 10;

    protected TContext DbContext { get; } = dbContext;

    public async Task SaveAndPublishEventsAsync(CancellationToken cancellationToken = default)
    {
        await DispatchDomainEventsAsync(cancellationToken);

        var pending = integrationEvents.Drain();
        if (pending.Count == 0)
        {
            await DbContext.SaveChangesAsync(cancellationToken);
            return;
        }

        // CAP enlists the outbox rows in this transaction, so the events exist if and only if the changes do.
        await using var transaction = await DbContext.Database.BeginTransactionAsync(capPublisher, autoCommit: false, cancellationToken);
        foreach (var integrationEvent in pending)
            await capPublisher.PublishAsync(integrationEvent.Topic, (object)integrationEvent, cancellationToken: cancellationToken);
        await DbContext.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        logger.LogDebug("Saved changes and published {Count} integration events", pending.Count);
    }

    private async Task DispatchDomainEventsAsync(CancellationToken cancellationToken)
    {
        // Handlers may change other aggregates and raise further events, so dispatch until none are left.
        for (var round = 0; round < MaxDispatchRounds; round++)
        {
            var sources = DbContext.ChangeTracker.Entries<IHasDomainEvents>()
                .Select(e => e.Entity)
                .Where(e => e.DomainEvents.Count > 0)
                .ToList();
            if (sources.Count == 0)
                return;

            var events = sources.SelectMany(s => s.DomainEvents).ToList();
            sources.ForEach(s => s.ClearDomainEvents());
            foreach (var domainEvent in events)
                await dispatcher.DispatchAsync(domainEvent, cancellationToken);
        }

        throw new InvalidOperationException($"Domain events were still being raised after {MaxDispatchRounds} rounds.");
    }
}
