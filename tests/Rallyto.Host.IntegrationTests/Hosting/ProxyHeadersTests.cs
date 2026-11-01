using System.Net;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Rallyto.Host.Composition;

namespace Rallyto.Host.IntegrationTests.Hosting;

/// <summary>
/// Behind the host's nginx every request reaches the API from the Docker bridge, so the client's address comes from
/// X-Forwarded-For. It is believed only from the proxy networks in configuration: per-IP rate limits (sign-in codes)
/// must see each visitor, and nobody else may claim an address.
/// </summary>
public sealed class ProxyHeadersTests
{
    private static readonly IConfiguration Config = new ConfigurationBuilder()
        .AddInMemoryCollection(new Dictionary<string, string?> { ["ForwardedHeaders:KnownNetworks:0"] = "172.16.0.0/12" })
        .Build();

    [Fact]
    public async Task The_client_address_comes_from_the_trusted_proxy()
    {
        var context = await RunAsync(from: "172.18.0.1", forwardedFor: "5.160.20.7", forwardedProto: "https");

        context.Connection.RemoteIpAddress.Should().Be(IPAddress.Parse("5.160.20.7"));
        context.Request.Scheme.Should().Be("https");
    }

    [Fact]
    public async Task A_caller_outside_the_proxy_networks_cannot_claim_another_address()
    {
        var context = await RunAsync(from: "8.8.8.8", forwardedFor: "5.160.20.7", forwardedProto: "https");

        context.Connection.RemoteIpAddress.Should().Be(IPAddress.Parse("8.8.8.8"));
    }

    [Fact]
    public async Task Only_the_address_nginx_saw_is_used_when_a_client_sends_its_own_header()
    {
        // nginx overwrites X-Forwarded-For, but with one hop trusted a forged leading entry is ignored either way.
        var context = await RunAsync(from: "172.18.0.1", forwardedFor: "1.1.1.1, 5.160.20.7", forwardedProto: "https");

        context.Connection.RemoteIpAddress.Should().Be(IPAddress.Parse("5.160.20.7"));
    }

    private static async Task<HttpContext> RunAsync(string from, string forwardedFor, string forwardedProto)
    {
        var options = new ForwardedHeadersOptions();
        ProxyHeaders.Configure(options, Config);
        var context = new DefaultHttpContext();
        context.Connection.RemoteIpAddress = IPAddress.Parse(from);
        context.Request.Headers["X-Forwarded-For"] = forwardedFor;
        context.Request.Headers["X-Forwarded-Proto"] = forwardedProto;
        var middleware = new ForwardedHeadersMiddleware(_ => Task.CompletedTask, NullLoggerFactory.Instance, Options.Create(options));
        await middleware.Invoke(context);
        return context;
    }
}
