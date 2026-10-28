using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Caching.Hybrid;
using Microsoft.Extensions.Caching.StackExchangeRedis;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;
using StackExchange.Redis;
using Rallyto.Core.Application.Abstractions;

namespace Rallyto.Infrastructure.Core.Caching;

public sealed class CacheSettings
{
    public string Provider { get; set; } = "Redis";
    public string KeyPrefix { get; set; } = "rallyto";
    public int DefaultExpirationMinutes { get; set; } = 5;
    public int LocalExpirationSeconds { get; set; } = 60;
    public int CircuitBreakerFailureThreshold { get; set; } = 3;
    public int CircuitBreakerResetSeconds { get; set; } = 30;
}

/// <summary>One lazily opened Redis connection, shared by the distributed cache and anything else that needs Redis.</summary>
public sealed class RedisConnection(string connectionString) : IAsyncDisposable
{
    private readonly Lazy<Task<IConnectionMultiplexer>> _connection = new(async () =>
    {
        var options = ConfigurationOptions.Parse(connectionString);
        options.AbortOnConnectFail = false;
        return await ConnectionMultiplexer.ConnectAsync(options);
    });

    public Task<IConnectionMultiplexer> GetAsync() => _connection.Value;

    public async ValueTask DisposeAsync()
    {
        if (_connection.IsValueCreated && _connection.Value.IsCompletedSuccessfully)
            await _connection.Value.Result.DisposeAsync();
    }
}

public static class CachingRegistration
{
    public const string HybridSecondLevelKey = "rallyto:hybrid-l2";

    public static string? ResolveRedisConnectionString(IConfiguration configuration)
    {
        if (string.Equals(configuration["Cache:Provider"], "InMemory", StringComparison.OrdinalIgnoreCase))
            return null;
        var redis = configuration.GetConnectionString("Redis");
        return string.IsNullOrWhiteSpace(redis) ? null : redis;
    }

    /// <summary>HybridCache: in-process L1 over a Redis L2 guarded by a circuit breaker (as in AsanRezerve).</summary>
    public static IServiceCollection AddRallytoCaching(this IServiceCollection services, IConfiguration configuration)
    {
        var section = configuration.GetSection("Cache");
        services.Configure<CacheSettings>(section);
        var settings = section.Get<CacheSettings>() ?? new CacheSettings();

        var redis = ResolveRedisConnectionString(configuration);
        if (redis is not null)
        {
            services.TryAddSingleton(new RedisConnection(redis));
            services.AddStackExchangeRedisCache(options => options.InstanceName = $"{settings.KeyPrefix}:");
            services.AddOptions<RedisCacheOptions>()
                .Configure<RedisConnection>((options, connection) => options.ConnectionMultiplexerFactory = connection.GetAsync);
        }
        else
        {
            services.AddDistributedMemoryCache();
        }

        services.TryAddKeyedSingleton<IDistributedCache>(HybridSecondLevelKey, (sp, _) => new ResilientDistributedCache(
            sp.GetRequiredService<IDistributedCache>(),
            settings,
            sp.GetRequiredService<ILogger<ResilientDistributedCache>>(),
            sp.GetRequiredService<TimeProvider>()));

        services.AddHybridCache(options =>
        {
            options.DistributedCacheServiceKey = HybridSecondLevelKey;
            options.DefaultEntryOptions = new HybridCacheEntryOptions
            {
                Expiration = TimeSpan.FromMinutes(Math.Max(1, settings.DefaultExpirationMinutes)),
                LocalCacheExpiration = TimeSpan.FromSeconds(Math.Max(1, settings.LocalExpirationSeconds)),
            };
        });
        services.TryAddScoped<ICacheInvalidator, HybridCacheInvalidator>();
        return services;
    }
}

public sealed class HybridCacheInvalidator(HybridCache cache, ILogger<HybridCacheInvalidator> logger) : ICacheInvalidator
{
    public async Task InvalidateTagsAsync(IEnumerable<string> tags, CancellationToken cancellationToken = default)
    {
        var list = tags.Where(t => !string.IsNullOrWhiteSpace(t)).Distinct(StringComparer.Ordinal).ToArray();
        if (list.Length == 0)
            return;
        try
        {
            await cache.RemoveByTagAsync(list, cancellationToken);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            logger.LogWarning(ex, "Cache invalidation failed for tags {Tags}; entries expire on their own", list);
        }
    }
}
