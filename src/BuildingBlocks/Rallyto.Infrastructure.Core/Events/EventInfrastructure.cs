using System.Collections.Concurrent;
using DotNetCore.CAP;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Savorboard.CAP.InMemoryMessageQueue;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Domain.Abstractions;

namespace Rallyto.Infrastructure.Core.Events;

/// <summary>Request-scoped buffer drained by the unit of work that commits the request's changes.</summary>
public sealed class IntegrationEventBuffer : IIntegrationEventPublisher
{
    private readonly List<IntegrationEvent> _events = [];

    public void Enqueue(IntegrationEvent integrationEvent) => _events.Add(integrationEvent);

    public IReadOnlyList<IntegrationEvent> Drain()
    {
        var drained = _events.ToList();
        _events.Clear();
        return drained;
    }
}

/// <summary>Resolves every <see cref="IDomainEventHandler{TEvent}"/> for an event and runs them in order.</summary>
public sealed class DomainEventDispatcher(IServiceProvider services)
{
    private static readonly ConcurrentDictionary<Type, Type> HandlerTypes = new();

    public async Task DispatchAsync(IDomainEvent domainEvent, CancellationToken cancellationToken)
    {
        var handlerType = HandlerTypes.GetOrAdd(domainEvent.GetType(), t => typeof(IDomainEventHandler<>).MakeGenericType(t));
        var handleMethod = handlerType.GetMethod(nameof(IDomainEventHandler<IDomainEvent>.HandleAsync))!;
        foreach (var handler in services.GetServices(handlerType))
        {
            if (handler is not null)
                await (Task)handleMethod.Invoke(handler, [domainEvent, cancellationToken])!;
        }
    }
}

public static class CapRegistration
{
    public const string ConsumerGroup = "rallyto";

    /// <summary>
    /// Registers CAP once per process: PostgreSQL outbox in schema <c>cap</c>, in-memory transport, no broker
    /// (design D3). Calling it again is a no-op, like AsanRezerve's guard.
    /// </summary>
    public static IServiceCollection AddRallytoCap(this IServiceCollection services, IConfiguration configuration)
    {
        if (services.Any(d => d.ServiceType == typeof(ICapPublisher)))
            return services;

        var connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection is required for CAP.");

        services.AddCap(options =>
        {
            options.UsePostgreSql(pg =>
            {
                pg.ConnectionString = connectionString;
                pg.Schema = "cap";
            });
            options.UseInMemoryMessageQueue();
            options.DefaultGroupName = ConsumerGroup;
            options.Version = "v1";
            options.ConsumerThreadCount = 1;
            options.FailedRetryInterval = 60;
            options.FailedRetryCount = 3;
            options.SucceedMessageExpiredAfter = 3600;
            options.FailedMessageExpiredAfter = 7 * 24 * 3600;
        });
        return services;
    }
}
