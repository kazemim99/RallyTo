using NetArchTest.Rules;

namespace Rallyto.ArchitectureTests;

/// <summary>Layer rules inside every bounded context (design D1, D2).</summary>
public sealed class LayerTests
{
    public static IEnumerable<object[]> Contexts => Assemblies.ContextNames();

    [Theory]
    [MemberData(nameof(Contexts))]
    public void Domain_depends_on_no_other_layer_or_framework(string context)
    {
        var result = Types.InAssembly(Assemblies.Load(context, "Domain"))
            .ShouldNot()
            .HaveDependencyOnAny(
                $"Rallyto.{context}.Application", $"Rallyto.{context}.Infrastructure", $"Rallyto.{context}.Api",
                "Microsoft.EntityFrameworkCore", "Microsoft.AspNetCore", "MediatR", "DotNetCore.CAP")
            .GetResult();

        result.IsSuccessful.Should().BeTrue(Failures(result));
    }

    [Theory]
    [MemberData(nameof(Contexts))]
    public void Application_does_not_know_persistence_web_or_messaging(string context)
    {
        var result = Types.InAssembly(Assemblies.Load(context, "Application"))
            .ShouldNot()
            .HaveDependencyOnAny(
                $"Rallyto.{context}.Infrastructure", $"Rallyto.{context}.Api",
                "Microsoft.EntityFrameworkCore", "Microsoft.AspNetCore", "DotNetCore.CAP", "Npgsql")
            .GetResult();

        result.IsSuccessful.Should().BeTrue(Failures(result));
    }

    [Theory]
    [MemberData(nameof(Contexts))]
    public void Api_does_not_reach_into_infrastructure(string context)
    {
        var result = Types.InAssembly(Assemblies.Load(context, "Api"))
            .ShouldNot()
            .HaveDependencyOnAny($"Rallyto.{context}.Infrastructure", "Microsoft.EntityFrameworkCore")
            .GetResult();

        result.IsSuccessful.Should().BeTrue(Failures(result));
    }

    [Theory]
    [MemberData(nameof(Contexts))]
    public void A_context_never_references_another_context(string context)
    {
        var others = Assemblies.Contexts.Where(c => c != context).Select(c => $"Rallyto.{c}.").ToArray();
        foreach (var layer in Assemblies.Layers)
        {
            var result = Types.InAssembly(Assemblies.Load(context, layer))
                .ShouldNot()
                .HaveDependencyOnAny(others)
                .GetResult();

            result.IsSuccessful.Should().BeTrue($"{context}.{layer}: {Failures(result)}");
        }
    }

    internal static string Failures(TestResult result) =>
        result.FailingTypeNames is null ? string.Empty : "offending types: " + string.Join(", ", result.FailingTypeNames);
}
