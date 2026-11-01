using System.Net;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.HttpOverrides;

namespace Rallyto.Host.Composition;

/// <summary>
/// The client's address and scheme behind a reverse proxy. In production nginx reaches the API through the Docker
/// bridge, so every request would otherwise come from the bridge gateway and share one per-IP rate limit.
/// X-Forwarded-For/-Proto are believed only from <c>ForwardedHeaders:KnownNetworks</c> (CIDR, e.g. 172.16.0.0/12) and
/// loopback, one hop deep; with no networks configured only loopback is trusted.
/// </summary>
public static class ProxyHeaders
{
    public static void Configure(ForwardedHeadersOptions options, IConfiguration configuration)
    {
        options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
        options.ForwardLimit = 1;
        foreach (var cidr in configuration.GetSection("ForwardedHeaders:KnownNetworks").Get<string[]>() ?? [])
            options.KnownIPNetworks.Add(System.Net.IPNetwork.Parse(cidr));
    }
}
