using System.Text.Json.Serialization;
using Asp.Versioning;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.EntityFrameworkCore;
using Rallyto.Catalog.Api;
using Rallyto.Catalog.Infrastructure;
using Rallyto.Catalog.Infrastructure.Persistence;
using Rallyto.Community.Api;
using Rallyto.Community.Infrastructure;
using Rallyto.Community.Infrastructure.Persistence;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Identity.Api;
using Rallyto.Identity.Infrastructure;
using Rallyto.Identity.Infrastructure.Persistence;
using Rallyto.Infrastructure.Core.Caching;
using Rallyto.Infrastructure.Core.DependencyInjection;
using Rallyto.Infrastructure.Web.Api;
using Rallyto.Infrastructure.Web.RateLimiting;
using Rallyto.Infrastructure.Web.Security;
using Rallyto.Messaging.Api;
using Rallyto.Messaging.Infrastructure;
using Rallyto.Messaging.Infrastructure.Persistence;
using Rallyto.Notifications.Api;
using Rallyto.Notifications.Infrastructure;
using Rallyto.Notifications.Infrastructure.Persistence;

namespace Rallyto.Host.Composition;

public static class HostRegistration
{
    public const string CorsPolicy = "rallyto-clients";

    /// <summary>Registration order mirrors AsanRezerve's Program.cs: web stack, security, shared core, contexts, then host-level composition.</summary>
    public static IServiceCollection AddRallytoHost(this IServiceCollection services, IConfiguration configuration, IWebHostEnvironment environment)
    {
        services.AddControllers()
            .AddApplicationPart(typeof(IdentityApiMarker).Assembly)
            .AddApplicationPart(typeof(CatalogApiMarker).Assembly)
            .AddApplicationPart(typeof(CommunityApiMarker).Assembly)
            .AddApplicationPart(typeof(MessagingApiMarker).Assembly)
            .AddApplicationPart(typeof(NotificationsApiMarker).Assembly)
            .AddJsonOptions(o =>
            {
                o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
                o.JsonSerializerOptions.Encoder = JsonDefaults.Encoder;
            });
        services.Configure<ApiResponseOptions>(configuration.GetSection("ApiResponse"));
        services.AddApiVersioning(o =>
            {
                o.DefaultApiVersion = new ApiVersion(1, 0);
                o.AssumeDefaultVersionWhenUnspecified = true;
                o.ReportApiVersions = true;
                o.ApiVersionReader = ApiVersionReader.Combine(
                    new UrlSegmentApiVersionReader(),
                    new HeaderApiVersionReader("X-Api-Version"),
                    new QueryStringApiVersionReader("api-version"));
            })
            .AddMvc()
            .AddApiExplorer(o =>
            {
                o.GroupNameFormat = "'v'VVV";
                o.SubstituteApiVersionInUrl = true;
            });
        services.AddEndpointsApiExplorer();
        services.AddSwaggerGen();

        services.AddRallytoAuthentication(configuration);
        services.AddCors(o => o.AddPolicy(CorsPolicy, policy =>
        {
            var origins = configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
            policy.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod().AllowCredentials();
        }));
        services.AddRallytoRateLimiting(configuration);

        services.AddRallytoCore(configuration);
        services.AddIdentityModule(configuration);
        services.AddCatalogModule(configuration);
        services.AddCommunityModule(configuration);
        services.AddMessagingModule(configuration);
        services.AddNotificationsModule(configuration);
        services.AddScoped<Rallyto.Community.Application.Abstractions.ICatalogReader, InProcessCatalogReader>();
        services.AddScoped<Rallyto.Catalog.Application.Abstractions.IFutureMatchReader, InProcessFutureMatchReader>();
        services.AddScoped<Rallyto.Messaging.Application.Abstractions.IPlayerRelationshipReader, InProcessPlayerRelationshipReader>();
        services.AddScoped<Rallyto.Messaging.Application.Abstractions.IBlockReader, InProcessBlockReader>();
        services.AddScoped<Rallyto.Messaging.Application.Abstractions.IMatchRosterReader, InProcessMatchRosterReader>();
        services.AddScoped<Rallyto.Community.Application.Safety.IMessageEvidenceReader, InProcessMessageEvidenceReader>();
        services.AddScoped<Rallyto.Community.Application.Safety.IAccountModeration, InProcessAccountModeration>();
        services.AddScoped<Rallyto.Notifications.Application.Abstractions.INotificationContextReader, InProcessNotificationContextReader>();

        // Host-level composition: realtime hub and presence, shared by every context (design D8).
        // Same wire format as the REST API: enums as strings, Persian text unescaped.
        var signalR = services.AddSignalR().AddJsonProtocol(o =>
        {
            o.PayloadSerializerOptions.Converters.Add(new JsonStringEnumConverter());
            o.PayloadSerializerOptions.Encoder = JsonDefaults.Encoder;
        });
        if (configuration.GetValue<bool>("SignalR:UseRedisBackplane") && CachingRegistration.ResolveRedisConnectionString(configuration) is { } redis)
            signalR.AddStackExchangeRedis(redis, o => o.Configuration.ChannelPrefix = StackExchange.Redis.RedisChannel.Literal("rallyto"));
        services.AddSingleton<ConnectionRegistry>();
        services.AddSingleton<IUserPresence>(sp => sp.GetRequiredService<ConnectionRegistry>());
        services.AddScoped<IRealtimePublisher, SignalRRealtimePublisher>();

        var health = services.AddHealthChecks()
            .AddNpgSql(configuration.GetConnectionString("DefaultConnection")!, name: "postgres", tags: ["ready"]);
        if (CachingRegistration.ResolveRedisConnectionString(configuration) is { } redisHealth)
            health.AddRedis(redisHealth, name: "redis", tags: ["ready"]);
        return services;
    }

    public static IApplicationBuilder UseRallytoAccountEnforcement(this IApplicationBuilder app) =>
        app.ApplicationServices.GetService<IAccountStatusReader>() is null ? app : app.UseMiddleware<ActiveAccountMiddleware>();

    /// <summary>Health probes stay anonymous, or container probes would get 401 from the fallback policy.</summary>
    public static void MapRallytoHealthChecks(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapHealthChecks("/health").AllowAnonymous().DisableRateLimiting();
        endpoints.MapHealthChecks("/health/ready", new HealthCheckOptions { Predicate = c => c.Tags.Contains("ready") }).AllowAnonymous().DisableRateLimiting();
        endpoints.MapHealthChecks("/health/live", new HealthCheckOptions { Predicate = _ => false }).AllowAnonymous().DisableRateLimiting();
    }

    /// <summary>Applies migrations at startup in a fixed order. EF Core takes a database lock, so concurrent starts are safe.</summary>
    public static async Task MigrateRallytoDatabasesAsync(this WebApplication app)
    {
        if (!app.Configuration.GetValue("Database:MigrateOnStartup", true))
            return;
        await using var scope = app.Services.CreateAsyncScope();
        DbContext[] contexts =
        [
            scope.ServiceProvider.GetRequiredService<IdentityDbContext>(),
            scope.ServiceProvider.GetRequiredService<CatalogDbContext>(),
            scope.ServiceProvider.GetRequiredService<CommunityDbContext>(),
            scope.ServiceProvider.GetRequiredService<MessagingDbContext>(),
            scope.ServiceProvider.GetRequiredService<NotificationsDbContext>(),
        ];
        foreach (var context in contexts)
            await context.Database.MigrateAsync();
        await SeedRallytoDataAsync(scope.ServiceProvider);
    }

    /// <summary>Reference data every context needs (idempotent). Also used by the integration tests after each reset.</summary>
    public static async Task SeedRallytoDataAsync(IServiceProvider services, CancellationToken cancellationToken = default)
    {
        foreach (var seeder in services.GetServices<Rallyto.Infrastructure.Core.Persistence.IDataSeeder>())
            await seeder.SeedAsync(cancellationToken);
    }
}
