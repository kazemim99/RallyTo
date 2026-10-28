using System.Reflection;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Routing;
using Microsoft.AspNetCore.RateLimiting;
using Rallyto.Infrastructure.Web.RateLimiting;
using Rallyto.Infrastructure.Web.Security;

namespace Rallyto.ArchitectureTests;

/// <summary>Launch security pass (tasks 11.2): authorization and rate limits that a forgotten attribute would silently break.</summary>
public sealed class SecurityTests
{
    private static IEnumerable<(Type Controller, MethodInfo Action, string Route)> Endpoints() =>
        Assemblies.Contexts
            .SelectMany(c => Assemblies.Load(c, "Api").GetTypes())
            .Where(t => typeof(ControllerBase).IsAssignableFrom(t) && !t.IsAbstract)
            .SelectMany(t => t.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly)
                .Where(m => m.GetCustomAttributes<HttpMethodAttribute>().Any())
                .Select(m => (t, m, Route(t, m))));

    private static string Route(Type controller, MethodInfo action)
    {
        var prefix = controller.GetCustomAttribute<RouteAttribute>()?.Template ?? string.Empty;
        var template = action.GetCustomAttributes<HttpMethodAttribute>().First().Template ?? string.Empty;
        return $"{prefix}/{template}".TrimEnd('/');
    }

    /// <summary>Admin features live directly under <c>api/v{version}/admin</c>; <c>auth/admin/sign-in</c> is the public way in.</summary>
    private static bool IsAdminRoute(string route) => route.Contains("{version:apiVersion}/admin", StringComparison.OrdinalIgnoreCase);

    private static bool RequiresAdmin(Type controller, MethodInfo action) =>
        controller.GetCustomAttributes<AuthorizeAttribute>().Concat(action.GetCustomAttributes<AuthorizeAttribute>()).Any(a => a.Policy == Policies.AdminOnly);

    private static bool IsAnonymous(Type controller, MethodInfo action) =>
        controller.GetCustomAttribute<AllowAnonymousAttribute>() is not null || action.GetCustomAttribute<AllowAnonymousAttribute>() is not null;

    [Fact]
    public void Every_admin_endpoint_requires_the_admin_policy()
    {
        var admin = Endpoints().Where(e => IsAdminRoute(e.Route)).ToList();

        admin.Should().NotBeEmpty();
        admin.Where(e => !RequiresAdmin(e.Controller, e.Action) || IsAnonymous(e.Controller, e.Action))
            .Select(e => $"{e.Controller.Name}.{e.Action.Name} ({e.Route})")
            .Should().BeEmpty("admin endpoints must use Policies.AdminOnly and never allow anonymous access");
    }

    [Fact]
    public void The_admin_policy_is_only_used_under_admin_routes()
    {
        Endpoints().Where(e => RequiresAdmin(e.Controller, e.Action) && !IsAdminRoute(e.Route))
            .Select(e => $"{e.Controller.Name}.{e.Action.Name} ({e.Route})")
            .Should().BeEmpty("admin features live under /admin so they are easy to audit and to block at the edge");
    }

    [Fact]
    public void Anonymous_endpoints_are_the_known_public_ones()
    {
        var anonymous = Endpoints().Where(e => IsAnonymous(e.Controller, e.Action)).Select(e => e.Route).Distinct().Order().ToList();

        // Sign-in, the public catalog and share links. Anything new here needs a deliberate review.
        anonymous.Should().OnlyContain(r => r.Contains("/auth/") || r.Contains("/sports") || r.Contains("/provinces") || r.Contains("/venues")
                                            || r.Contains("/share/") || r.StartsWith("/m/", StringComparison.Ordinal));
    }

    [Fact]
    public void Every_rate_limit_policy_in_use_has_a_default()
    {
        var used = Endpoints()
            .SelectMany(e => e.Action.GetCustomAttributes<EnableRateLimitingAttribute>().Concat(e.Controller.GetCustomAttributes<EnableRateLimitingAttribute>()))
            .Select(a => a.PolicyName!)
            .Distinct()
            .ToList();
        var declared = typeof(RateLimitPolicies).GetFields(BindingFlags.Public | BindingFlags.Static).Select(f => (string)f.GetValue(null)!).ToList();

        used.Should().OnlyContain(p => RateLimitingOptions.Defaults.ContainsKey(p));
        declared.Should().BeEquivalentTo(used, "a declared policy that no endpoint uses is a limit someone believes exists");
    }

    [Theory]
    [InlineData("/otp/send", RateLimitPolicies.PhoneVerification)]
    [InlineData("/otp/verify", RateLimitPolicies.CodeVerification)]
    [InlineData("search/partners", RateLimitPolicies.Search)]
    [InlineData("{id:guid}/messages", RateLimitPolicies.ChatSend)]
    [InlineData("reports", RateLimitPolicies.Reports)]
    [InlineData("admin/sign-in", RateLimitPolicies.AdminSignIn)]
    public void Abuse_prone_endpoints_are_rate_limited(string routeSuffix, string policy)
    {
        Endpoints().Where(e => e.Route.EndsWith(routeSuffix, StringComparison.Ordinal)
                               && e.Action.GetCustomAttributes<HttpMethodAttribute>().Any(h => h.HttpMethods.Contains("POST") || h.HttpMethods.Contains("GET")))
            .Should().Contain(e => e.Action.GetCustomAttributes<EnableRateLimitingAttribute>().Any(a => a.PolicyName == policy));
    }
}
