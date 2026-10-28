using System.Globalization;
using System.Security.Claims;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Rallyto.Infrastructure.Web.Api;

namespace Rallyto.Infrastructure.Web.RateLimiting;

public sealed record RateLimitPolicyOptions(int PermitLimit = 60, int WindowSeconds = 60);

public static class RateLimitPolicies
{
    public const string PhoneVerification = "phone-verification";
    public const string CodeVerification = "code-verification";
    public const string Search = "search";
    public const string ChatSend = "chat-send";
    public const string Reports = "reports";
    public const string AdminSignIn = "admin-sign-in";
}

public sealed class RateLimitingOptions
{
    public const string SectionName = "RateLimiting";
    public bool Enabled { get; set; } = true;
    public RateLimitPolicyOptions Global { get; set; } = new(PermitLimit: 300, WindowSeconds: 60);
    public Dictionary<string, RateLimitPolicyOptions> Policies { get; set; } = new(StringComparer.OrdinalIgnoreCase);

    /// <summary>Defaults taken from the specs; configuration may override any of them.</summary>
    public static IReadOnlyDictionary<string, RateLimitPolicyOptions> Defaults { get; } =
        new Dictionary<string, RateLimitPolicyOptions>(StringComparer.OrdinalIgnoreCase)
        {
            [RateLimitPolicies.PhoneVerification] = new(5, 300),
            [RateLimitPolicies.CodeVerification] = new(10, 300),
            [RateLimitPolicies.Search] = new(60, 60),
            [RateLimitPolicies.ChatSend] = new(30, 60),
            [RateLimitPolicies.Reports] = new(20, 3_600),
            [RateLimitPolicies.AdminSignIn] = new(10, 300),
        };
}

public static class RateLimitingRegistration
{
    /// <summary>
    /// ASP.NET Core's built-in limiter: a global fixed window per user (or IP when anonymous) plus the named policies.
    /// Replaces AsanRezerve's two layers (AspNetCoreRateLimit + built-in) with one; see the design's deviations table.
    /// </summary>
    public static IServiceCollection AddRallytoRateLimiting(this IServiceCollection services, IConfiguration configuration)
    {
        var options = new RateLimitingOptions();
        configuration.GetSection(RateLimitingOptions.SectionName).Bind(options);

        services.AddRateLimiter(limiter =>
        {
            limiter.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
            limiter.OnRejected = async (context, _) =>
            {
                if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
                    context.HttpContext.Response.Headers.RetryAfter = ((int)Math.Ceiling(retryAfter.TotalSeconds)).ToString(CultureInfo.InvariantCulture);
                await ExceptionHandlingMiddleware.WriteErrorAsync(context.HttpContext, StatusCodes.Status429TooManyRequests, "TOO_MANY_REQUESTS", "تعداد درخواست‌ها زیاد است. کمی بعد دوباره تلاش کنید.");
            };

            limiter.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(httpContext =>
                options.Enabled && !httpContext.Request.Path.StartsWithSegments("/health")
                    ? FixedWindow(PartitionKey(httpContext, "global"), options.Global)
                    : RateLimitPartition.GetNoLimiter("unlimited"));

            foreach (var (name, defaults) in RateLimitingOptions.Defaults)
            {
                var policy = options.Policies.TryGetValue(name, out var configured) ? configured : defaults;
                limiter.AddPolicy(name, httpContext => options.Enabled
                    ? FixedWindow(PartitionKey(httpContext, name), policy)
                    : RateLimitPartition.GetNoLimiter(name));
            }
        });
        return services;
    }

    private static RateLimitPartition<string> FixedWindow(string key, RateLimitPolicyOptions policy) =>
        RateLimitPartition.GetFixedWindowLimiter(key, _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = policy.PermitLimit,
            Window = TimeSpan.FromSeconds(policy.WindowSeconds),
            QueueLimit = 0,
            AutoReplenishment = true,
        });

    private static string PartitionKey(HttpContext httpContext, string policyName)
    {
        var userId = httpContext.User.FindFirstValue(ClaimTypes.NameIdentifier);
        var caller = string.IsNullOrWhiteSpace(userId) ? $"ip:{httpContext.Connection.RemoteIpAddress}" : $"user:{userId}";
        return $"{policyName}|{caller}";
    }
}
