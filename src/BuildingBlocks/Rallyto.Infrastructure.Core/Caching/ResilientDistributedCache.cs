using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;

namespace Rallyto.Infrastructure.Core.Caching;

/// <summary>
/// Wraps the Redis cache with a circuit breaker: after a few consecutive failures every call is a cache miss
/// for a while instead of a timeout, so a Redis outage slows nothing down. Rewritten after AsanRezerve's
/// <c>ResilientDistributedCache</c>.
/// </summary>
public sealed class ResilientDistributedCache(
    IDistributedCache inner,
    CacheSettings settings,
    ILogger<ResilientDistributedCache> logger,
    TimeProvider clock) : IDistributedCache
{
    private readonly object _gate = new();
    private int _consecutiveFailures;
    private DateTimeOffset? _openUntil;

    public byte[]? Get(string key) => Guard(() => inner.Get(key), default);

    public Task<byte[]?> GetAsync(string key, CancellationToken token = default) =>
        GuardAsync(() => inner.GetAsync(key, token), default);

    public void Set(string key, byte[] value, DistributedCacheEntryOptions options) =>
        Guard(() => { inner.Set(key, value, options); return true; }, false);

    public Task SetAsync(string key, byte[] value, DistributedCacheEntryOptions options, CancellationToken token = default) =>
        GuardAsync(async () => { await inner.SetAsync(key, value, options, token); return true; }, false);

    public void Refresh(string key) => Guard(() => { inner.Refresh(key); return true; }, false);

    public Task RefreshAsync(string key, CancellationToken token = default) =>
        GuardAsync(async () => { await inner.RefreshAsync(key, token); return true; }, false);

    public void Remove(string key) => Guard(() => { inner.Remove(key); return true; }, false);

    public Task RemoveAsync(string key, CancellationToken token = default) =>
        GuardAsync(async () => { await inner.RemoveAsync(key, token); return true; }, false);

    private T Guard<T>(Func<T> action, T fallback)
    {
        if (IsOpen())
            return fallback;
        try
        {
            var result = action();
            Succeeded();
            return result;
        }
        catch (Exception ex)
        {
            Failed(ex);
            return fallback;
        }
    }

    private async Task<T> GuardAsync<T>(Func<Task<T>> action, T fallback)
    {
        if (IsOpen())
            return fallback;
        try
        {
            var result = await action();
            Succeeded();
            return result;
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            Failed(ex);
            return fallback;
        }
    }

    private bool IsOpen()
    {
        lock (_gate)
        {
            if (_openUntil is null)
                return false;
            if (clock.GetUtcNow() < _openUntil)
                return true;
            _openUntil = null; // half-open: let the next call try Redis again
            return false;
        }
    }

    private void Succeeded()
    {
        lock (_gate)
            _consecutiveFailures = 0;
    }

    private void Failed(Exception ex)
    {
        lock (_gate)
        {
            _consecutiveFailures++;
            if (_consecutiveFailures < settings.CircuitBreakerFailureThreshold)
                return;
            _openUntil = clock.GetUtcNow().AddSeconds(settings.CircuitBreakerResetSeconds);
            _consecutiveFailures = 0;
        }

        logger.LogWarning(ex, "Distributed cache unavailable; serving from memory for {Seconds} s", settings.CircuitBreakerResetSeconds);
    }
}
