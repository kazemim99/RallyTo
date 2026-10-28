using System.Reflection;
using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Application.Behaviors;
using Rallyto.Infrastructure.Core.Caching;
using Rallyto.Infrastructure.Core.Events;
using Rallyto.Infrastructure.Core.Persistence;
using Rallyto.Infrastructure.Core.Services;

namespace Rallyto.Infrastructure.Core.DependencyInjection;

public static class CoreRegistration
{
    /// <summary>Shared services every context relies on: clock, current user, events, CAP, caching, the MediatR pipeline.</summary>
    public static IServiceCollection AddRallytoCore(this IServiceCollection services, IConfiguration configuration)
    {
        services.TryAddSingleton(TimeProvider.System);
        services.AddHttpContextAccessor();
        services.TryAddScoped<ICurrentUserService, CurrentUserService>();
        services.TryAddScoped<IntegrationEventBuffer>();
        services.TryAddScoped<IIntegrationEventPublisher>(sp => sp.GetRequiredService<IntegrationEventBuffer>());
        services.TryAddScoped<DomainEventDispatcher>();
        services.TryAddScoped<AuditingInterceptor>();
        services.TryAddSingleton<IFileStorage, Storage.LocalFileStorage>();
        services.AddRallytoCaching(configuration);
        services.AddRallytoCap(configuration);
        return services;
    }

    /// <summary>
    /// Registers a context's application assembly: MediatR handlers with the shared pipeline, validators and
    /// domain event handlers. Behaviors are added once, in the order of design D1.
    /// </summary>
    public static IServiceCollection AddContextApplication(this IServiceCollection services, Assembly applicationAssembly)
    {
        services.AddMediatR(cfg =>
        {
            cfg.RegisterServicesFromAssembly(applicationAssembly);
            if (!services.Any(d => d.ImplementationType == typeof(LoggingBehavior<,>)))
            {
                cfg.AddOpenBehavior(typeof(LoggingBehavior<,>));
                cfg.AddOpenBehavior(typeof(ValidationBehavior<,>));
                cfg.AddOpenBehavior(typeof(PerformanceBehavior<,>));
                cfg.AddOpenBehavior(typeof(CachingBehavior<,>));
            }
        });
        services.AddValidatorsFromAssembly(applicationAssembly, includeInternalTypes: true);
        services.Scan(scan => scan.FromAssemblies(applicationAssembly)
            .AddClasses(c => c.AssignableTo(typeof(IDomainEventHandler<>)), publicOnly: false)
            .AsImplementedInterfaces()
            .WithScopedLifetime());
        return services;
    }

    /// <summary>
    /// Registers a context's DbContext on the shared connection string, in its own schema, with snake_case names
    /// and its migrations history table inside that schema.
    /// </summary>
    public static IServiceCollection AddContextDbContext<TContext>(
        this IServiceCollection services, IConfiguration configuration, string schema)
        where TContext : RallytoDbContext
    {
        var connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection is required.");
        services.AddDbContext<TContext>((sp, options) => options
            .UseNpgsql(connectionString, npgsql => npgsql.MigrationsHistoryTable("__ef_migrations_history", schema))
            .UseSnakeCaseNamingConvention()
            .AddInterceptors(sp.GetRequiredService<AuditingInterceptor>()));
        return services;
    }
}
