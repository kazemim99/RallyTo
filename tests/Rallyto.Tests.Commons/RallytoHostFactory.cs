using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Rallyto.Identity.Application.Abstractions;
using Rallyto.Tests.Commons.Fakes;
using Xunit;

namespace Rallyto.Tests.Commons;

/// <summary>
/// The real host in environment <c>Testing</c>, on its own database and a shared Redis, with a controllable clock
/// and fakes for external services. Settings are applied with <c>UseSetting</c> because Program reads
/// configuration before <c>Build()</c>.
/// </summary>
public class RallytoHostFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    public static readonly DateTimeOffset DefaultNow = new(2026, 10, 23, 9, 0, 0, TimeSpan.Zero); // 1405/08/01 12:30 Tehran
    public const string AdminEmail = "admin@rallyto.test";
    public const string AdminPassword = "Test-Admin-Pass-123";

    public string ConnectionString { get; private set; } = string.Empty;
    public string RedisConnectionString { get; private set; } = string.Empty;
    public TestClock Clock { get; } = new(DefaultNow);
    public FakeSmsSender Sms { get; } = new();
    public FakePushGateway Push { get; } = new();
    public string? AdminAccessToken { get; set; }
    public DateTimeOffset? AdminTokenIssuedAt { get; set; }

    public virtual async Task InitializeAsync()
    {
        ConnectionString = await TestContainers.CreateDatabaseAsync($"rallyto_test_{Guid.NewGuid():N}");
        RedisConnectionString = await TestContainers.RedisConnectionStringAsync();
        _ = Services; // start the host now: runs migrations once per factory
    }

    public new virtual async Task DisposeAsync() => await base.DisposeAsync();

    /// <summary>Called before every test: empty tables, reset the clock and the fakes.</summary>
    public virtual async Task ResetStateAsync()
    {
        // Provinces and cities are static reference data: kept, so 500 rows are not re-inserted before every test.
        await DatabaseReset.ResetAsync(ConnectionString, ["catalog.provinces", "catalog.cities"]);
        await using (var scope = Services.CreateAsyncScope())
            await Rallyto.Host.Composition.HostRegistration.SeedRallytoDataAsync(scope.ServiceProvider);
        Clock.SetUtcNow(DefaultNow);
        Sms.Reset();
        Push.Reset();
        AdminAccessToken = null;
        AdminTokenIssuedAt = null;
        await ClearCachesAsync();
    }

    public void Advance(TimeSpan by) => Clock.Advance(by);

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("ConnectionStrings:DefaultConnection", ConnectionString);
        builder.UseSetting("ConnectionStrings:Redis", RedisConnectionString);
        builder.UseSetting("Cache:KeyPrefix", $"test-{Guid.NewGuid():N}");
        builder.UseSetting("Identity:InitialAdmin:Email", AdminEmail);
        builder.UseSetting("Identity:InitialAdmin:Password", AdminPassword);
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<TimeProvider>();
            services.AddSingleton<TimeProvider>(Clock);
            services.RemoveAll<ISmsSender>();
            services.AddSingleton<ISmsSender>(Sms);
            services.RemoveAll<Rallyto.Notifications.Application.Abstractions.IPushGateway>();
            services.AddSingleton<Rallyto.Notifications.Application.Abstractions.IPushGateway>(Push);
            ConfigureTestServices(services);
        });
    }

    /// <summary>Hook for replacing further external services (push) with fakes.</summary>
    protected virtual void ConfigureTestServices(IServiceCollection services)
    {
    }

    private async Task ClearCachesAsync()
    {
        var cache = Services.GetService<Microsoft.Extensions.Caching.Hybrid.HybridCache>();
        if (cache is not null)
            await cache.RemoveByTagAsync("*");
    }
}
