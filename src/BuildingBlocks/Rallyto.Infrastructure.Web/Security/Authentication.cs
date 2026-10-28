using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;

namespace Rallyto.Infrastructure.Web.Security;

public sealed class JwtSettings
{
    public const string SectionName = "Jwt";
    public string SecretKey { get; set; } = string.Empty;
    public string Issuer { get; set; } = "rallyto";
    public string Audience { get; set; } = "rallyto-clients";
    public int AccessTokenMinutes { get; set; } = 60;
    public int RefreshTokenDays { get; set; } = 30;
}

public static class Roles
{
    public const string Player = "Player";
    public const string Admin = "Admin";
}

public static class Policies
{
    public const string AdminOnly = nameof(AdminOnly);
}

public static class AuthenticationRegistration
{
    /// <summary>
    /// JWT bearer validation (HS256, zero clock skew, <c>Token-Expired</c> header) and the authorization policies.
    /// Every endpoint requires an authenticated user unless it says <c>[AllowAnonymous]</c> (AsanRezerve's fallback policy).
    /// </summary>
    public static IServiceCollection AddRallytoAuthentication(this IServiceCollection services, IConfiguration configuration)
    {
        var settings = configuration.GetSection(JwtSettings.SectionName).Get<JwtSettings>() ?? new JwtSettings();
        services.Configure<JwtSettings>(configuration.GetSection(JwtSettings.SectionName));

        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.MapInboundClaims = true;
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidateAudience = true,
                    ValidateLifetime = true,
                    ValidateIssuerSigningKey = true,
                    ValidIssuer = settings.Issuer,
                    ValidAudience = settings.Audience,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(settings.SecretKey.PadRight(32))),
                    ClockSkew = TimeSpan.Zero,
                };
                options.Events = new JwtBearerEvents
                {
                    OnMessageReceived = context =>
                    {
                        var token = SignalRAccessTokenExtractor.Extract(context.Request);
                        if (!string.IsNullOrEmpty(token))
                            context.Token = token;
                        return Task.CompletedTask;
                    },
                    OnAuthenticationFailed = context =>
                    {
                        if (context.Exception is SecurityTokenExpiredException or SecurityTokenInvalidLifetimeException)
                            context.Response.Headers.Append("Token-Expired", "true");
                        context.HttpContext.RequestServices.GetService<ILoggerFactory>()?.CreateLogger("Rallyto.Authentication")
                            .LogInformation("Bearer token refused ({Reason}) for {Method} {Path}", context.Exception.GetType().Name, context.Request.Method, context.Request.Path.Value);
                        return Task.CompletedTask;
                    },
                };
            });

        // Token lifetime follows the injected clock, so expiry is testable with FakeTimeProvider.
        services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
            .Configure<TimeProvider>((options, clock) =>
            {
                options.TimeProvider = clock;
                options.TokenValidationParameters.LifetimeValidator = (notBefore, expires, _, _) =>
                {
                    var now = clock.GetUtcNow().UtcDateTime;
                    return (notBefore is null || notBefore <= now) && (expires is null || expires > now);
                };
            });

        services.AddAuthorizationBuilder()
            .SetFallbackPolicy(new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build())
            .AddPolicy(Policies.AdminOnly, policy => policy.RequireAuthenticatedUser().RequireRole(Roles.Admin));
        return services;
    }
}

/// <summary>Browsers and SignalR clients cannot set headers on WebSocket requests, so hubs take the token from the query string.</summary>
public static class SignalRAccessTokenExtractor
{
    public static string? Extract(HttpRequest request)
    {
        if (!request.Path.StartsWithSegments("/hubs"))
            return null;
        var fromQuery = request.Query["access_token"].ToString();
        return string.IsNullOrEmpty(fromQuery) ? null : fromQuery;
    }
}
