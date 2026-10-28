using System.Reflection;

namespace Rallyto.ArchitectureTests;

public static class Assemblies
{
    public static readonly string[] Contexts = ["Identity", "Catalog", "Community", "Messaging", "Notifications"];
    public static readonly string[] Layers = ["Domain", "Application", "Infrastructure", "Api"];

    public static Assembly Load(string context, string layer) => Assembly.Load($"Rallyto.{context}.{layer}");

    public static IEnumerable<Assembly> All() =>
        Contexts.SelectMany(c => Layers.Select(l => Load(c, l)));

    public static IEnumerable<object[]> ContextNames() => Contexts.Select(c => new object[] { c });
}
