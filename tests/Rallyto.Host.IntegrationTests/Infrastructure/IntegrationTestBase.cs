using Rallyto.Tests.Commons;

namespace Rallyto.Host.IntegrationTests.Infrastructure;

[CollectionDefinition(Name)]
public sealed class HostCollection : ICollectionFixture<RallytoHostFactory>
{
    public const string Name = "host";
}

/// <summary>Every integration test shares one host and starts from empty tables.</summary>
[Collection(HostCollection.Name)]
public abstract class IntegrationTestBase(RallytoHostFactory factory) : IAsyncLifetime
{
    protected RallytoHostFactory Factory { get; } = factory;

    public virtual Task InitializeAsync() => Factory.ResetStateAsync();

    public virtual Task DisposeAsync() => Task.CompletedTask;
}
