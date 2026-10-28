using System.Reflection;
using MediatR;

namespace Rallyto.ArchitectureTests;

/// <summary>Privacy rules of design D11 that the compiler cannot enforce on its own.</summary>
public sealed class PrivacyTests
{
    [Fact]
    public void Only_identity_knows_phone_numbers()
    {
        var assemblies = Assemblies.Contexts.Where(c => c != "Identity")
            .SelectMany(c => Assemblies.Layers.Select(l => Assemblies.Load(c, l)))
            .Append(Assembly.Load("Rallyto.Contracts"));

        var offenders = assemblies
            .SelectMany(a => a.GetTypes())
            .Where(t => !t.Name.StartsWith('<')) // compiler-generated (migration column lists)
            .SelectMany(t => t.GetProperties(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.DeclaredOnly)
                .Where(p => p.Name.Contains("Phone", StringComparison.OrdinalIgnoreCase) || p.PropertyType.Name == "PhoneNumber")
                .Select(p => $"{t.FullName}.{p.Name}"))
            // A club's public phone number is business data, not a player's.
            .Where(name => !name.StartsWith("Rallyto.Catalog.", StringComparison.Ordinal))
            .ToList();

        offenders.Should().BeEmpty("phone numbers must never leave the Identity context");
    }

    [Fact]
    public void Community_handlers_that_return_another_players_data_check_visibility()
    {
        var community = Assemblies.Load("Community", "Application");
        var visibilityService = community.GetType("Rallyto.Community.Application.Players.VisibilityService", throwOnError: true)!;

        var offenders = community.GetTypes()
            .Where(t => t is { IsClass: true, IsAbstract: false })
            .Where(t => t.GetInterfaces().Any(i => i.IsGenericType && i.GetGenericTypeDefinition() == typeof(IRequestHandler<,>)
                                                   && TargetsAnotherPlayer(i.GetGenericArguments()[0])))
            .Where(t => !t.GetConstructors().Any(c => c.GetParameters().Any(p => p.ParameterType == visibilityService)))
            .Select(t => t.Name)
            .ToList();

        offenders.Should().BeEmpty("every read of another player's data goes through VisibilityPolicy (design D11)");
    }

    /// <summary>Player-facing queries that name another player by <c>UserId</c>; admin queries are exempt.</summary>
    private static bool TargetsAnotherPlayer(Type request) =>
        request.Name.EndsWith("Query", StringComparison.Ordinal)
        && !request.Name.StartsWith("Admin", StringComparison.Ordinal)
        && request.GetProperty("UserId") is not null;
}
