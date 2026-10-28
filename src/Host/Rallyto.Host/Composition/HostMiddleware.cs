using Microsoft.Extensions.FileProviders;
using Rallyto.Community.Infrastructure.Players;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Infrastructure.Core.Storage;

namespace Rallyto.Host.Composition;

/// <summary>Records the signed-in player's activity (throttled) after authentication.</summary>
public sealed class ActivityTrackingMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context, ICurrentUserService currentUser, PlayerActivityTracker tracker)
    {
        if (currentUser.UserId is { } userId)
            await tracker.TouchAsync(userId, context.RequestAborted);
        await next(context);
    }
}

public static class MediaFiles
{
    /// <summary>Serves uploaded files read-only under <c>/media</c>; names are random, so listing is not possible.</summary>
    public static IApplicationBuilder UseRallytoMedia(this IApplicationBuilder app, IConfiguration configuration)
    {
        var root = StorageOptions.ResolveRoot(configuration);
        Directory.CreateDirectory(root);
        return app.UseStaticFiles(new StaticFileOptions
        {
            FileProvider = new PhysicalFileProvider(root),
            RequestPath = StorageOptions.PublicPrefix,
            ServeUnknownFileTypes = false,
            OnPrepareResponse = ctx => ctx.Context.Response.Headers.CacheControl = "public, max-age=604800, immutable",
        });
    }
}
