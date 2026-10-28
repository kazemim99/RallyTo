using System.Reflection;
using Rallyto.Core.Application.Cqrs;

namespace Rallyto.ArchitectureTests;

public sealed class PipelineTests
{
    /// <summary>
    /// Queries allowed to be cached (design D12). Only catalog reference data belongs here; search results and
    /// anything player-specific must never be cached.
    /// </summary>
    private static readonly HashSet<string> CacheAllowlist = new(StringComparer.Ordinal)
    {
        "GetSportsQuery", "GetProvincesQuery", "GetCitiesQuery", "ListVenuesQuery",
    };

    private static IEnumerable<Assembly> AllAssemblies() =>
        Assemblies.All().Append(typeof(IQuery<>).Assembly);

    [Fact]
    public void No_generic_transaction_behavior_exists()
    {
        // AsanRezerve's generic TransactionBehavior committed whichever unit of work was registered last.
        // Handlers save through their own context's unit-of-work marker instead (design D12).
        var offenders = AllAssemblies()
            .SelectMany(a => a.GetTypes())
            .Where(t => t.Name.StartsWith("TransactionBehavior", StringComparison.Ordinal))
            .Select(t => t.FullName)
            .ToList();

        offenders.Should().BeEmpty();
    }

    [Fact]
    public void Only_allowlisted_queries_are_cacheable()
    {
        var cacheable = AllAssemblies()
            .SelectMany(a => a.GetTypes())
            .Where(t => t is { IsClass: true, IsAbstract: false } && ImplementsQuery(t) && OverridesIsCacheable(t))
            .Select(t => t.Name)
            .ToList();

        cacheable.Where(name => !CacheAllowlist.Contains(name)).Should().BeEmpty(
            "only catalog reference queries may be cached; add new ones to the allowlist deliberately");
    }

    private static bool ImplementsQuery(Type type) =>
        type.GetInterfaces().Any(i => i.IsGenericType && i.GetGenericTypeDefinition() == typeof(IQuery<>));

    private static bool OverridesIsCacheable(Type type) =>
        type.GetProperty("IsCacheable", BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic) is not null
        || type.GetInterfaceMap(type.GetInterfaces().First(i => i.IsGenericType && i.GetGenericTypeDefinition() == typeof(IQuery<>)))
            .TargetMethods.Any(m => m.Name.Contains("get_IsCacheable", StringComparison.Ordinal) && m.DeclaringType == type);
}
