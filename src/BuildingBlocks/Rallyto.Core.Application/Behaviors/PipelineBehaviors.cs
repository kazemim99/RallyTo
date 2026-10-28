using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using FluentValidation;
using MediatR;
using Microsoft.Extensions.Caching.Hybrid;
using Microsoft.Extensions.Logging;
using Rallyto.Core.Application.Cqrs;

namespace Rallyto.Core.Application.Behaviors;

// Order of registration is the order of execution: Logging -> Validation -> Performance -> Caching (design D1).

public sealed class LoggingBehavior<TRequest, TResponse>(ILogger<LoggingBehavior<TRequest, TResponse>> logger)
    : IPipelineBehavior<TRequest, TResponse> where TRequest : notnull
{
    public async Task<TResponse> Handle(TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken cancellationToken)
    {
        var name = typeof(TRequest).Name;
        logger.LogDebug("Handling {RequestName}", name);
        try
        {
            return await next();
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            logger.LogDebug("{RequestName} failed with {ExceptionType}", name, ex.GetType().Name);
            throw;
        }
    }
}

public sealed class ValidationBehavior<TRequest, TResponse>(IEnumerable<IValidator<TRequest>> validators)
    : IPipelineBehavior<TRequest, TResponse> where TRequest : notnull
{
    public async Task<TResponse> Handle(TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken cancellationToken)
    {
        if (validators.Any())
        {
            var context = new ValidationContext<TRequest>(request);
            var results = await Task.WhenAll(validators.Select(v => v.ValidateAsync(context, cancellationToken)));
            var failures = results.SelectMany(r => r.Errors).Where(f => f is not null).ToList();
            if (failures.Count > 0)
                throw new ValidationException(failures);
        }

        return await next();
    }
}

public sealed class PerformanceBehavior<TRequest, TResponse>(ILogger<PerformanceBehavior<TRequest, TResponse>> logger)
    : IPipelineBehavior<TRequest, TResponse> where TRequest : notnull
{
    private const int SlowThresholdMs = 500;

    public async Task<TResponse> Handle(TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken cancellationToken)
    {
        var started = Stopwatch.GetTimestamp();
        var response = await next();
        var elapsed = Stopwatch.GetElapsedTime(started).TotalMilliseconds;
        if (elapsed > SlowThresholdMs)
            logger.LogWarning("Slow request {RequestName} took {ElapsedMs} ms", typeof(TRequest).Name, (long)elapsed);
        return response;
    }
}

public sealed class CachingBehavior<TRequest, TResponse>(HybridCache cache)
    : IPipelineBehavior<TRequest, TResponse> where TRequest : notnull
{
    private const int DefaultExpirationSeconds = 300;

    public async Task<TResponse> Handle(TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken cancellationToken)
    {
        if (request is not IQuery<TResponse> query || !query.IsCacheable)
            return await next();

        var typeName = typeof(TRequest).Name;
        var key = query.CacheKey ?? $"query:{typeName}:{Hash(request)}";
        var tags = new List<string> { QueryTag(typeName) };
        if (query.CacheTags is { } extra)
            tags.AddRange(extra);

        var expiration = TimeSpan.FromSeconds(query.CacheExpirationSeconds ?? DefaultExpirationSeconds);
        return await cache.GetOrCreateAsync(
            key,
            async _ => await next(),
            new HybridCacheEntryOptions { Expiration = expiration, LocalCacheExpiration = expiration },
            tags,
            cancellationToken);
    }

    public static string QueryTag(string queryTypeName) => $"query:{queryTypeName}";

    private static string Hash(TRequest request)
    {
        var json = JsonSerializer.SerializeToUtf8Bytes(request, request.GetType());
        return Convert.ToHexString(SHA256.HashData(json))[..32];
    }
}
