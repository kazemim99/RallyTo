using DotNetCore.CAP;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.DependencyInjection;
using SkiaSharp;
using Rallyto.Community.Application.Abstractions;
using Rallyto.Community.Infrastructure.Persistence;
using Rallyto.Contracts.Identity;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Application.Exceptions;

namespace Rallyto.Community.Infrastructure.Players;

/// <summary>
/// JPEG, PNG or WebP up to 5 MB, decoded and re-encoded as a JPEG of at most 512×512 (spec player-profile › Profile
/// photo). Re-encoding drops all metadata, including any GPS position in EXIF: no player location is ever stored.
/// </summary>
internal sealed class AvatarProcessor(IFileStorage storage) : IAvatarProcessor
{
    public const long MaxBytes = 5 * 1024 * 1024;
    private const int MaxSide = 512;
    private static readonly string[] AllowedTypes = ["image/jpeg", "image/png", "image/webp"];

    public async Task<string> ProcessAndStoreAsync(Stream upload, long length, string? contentType, CancellationToken cancellationToken)
    {
        if (length > MaxBytes)
            throw new ValidationFailedException("PHOTO_TOO_LARGE", "حجم عکس حداکثر ۵ مگابایت است.");
        if (contentType is null || !AllowedTypes.Contains(contentType, StringComparer.OrdinalIgnoreCase))
            throw new ValidationFailedException("PHOTO_TYPE_NOT_ALLOWED", "فقط عکس JPEG، PNG یا WebP پذیرفته می‌شود.");

        using var buffer = new MemoryStream();
        await upload.CopyToAsync(buffer, cancellationToken);
        buffer.Position = 0;

        using var codec = SKCodec.Create(buffer) ?? throw new ValidationFailedException("PHOTO_INVALID", "فایل عکس معتبر نیست.");
        using var decoded = SKBitmap.Decode(codec) ?? throw new ValidationFailedException("PHOTO_INVALID", "فایل عکس معتبر نیست.");
        using var oriented = Orient(decoded, codec.EncodedOrigin);

        var scale = Math.Min(1.0, (double)MaxSide / Math.Max(oriented.Width, oriented.Height));
        var info = new SKImageInfo(Math.Max(1, (int)(oriented.Width * scale)), Math.Max(1, (int)(oriented.Height * scale)), SKColorType.Rgba8888, SKAlphaType.Premul);
        using var resized = new SKBitmap(info);
        using (var canvas = new SKCanvas(resized))
        {
            canvas.Clear(SKColors.White); // JPEG has no transparency
            using var image = SKImage.FromBitmap(oriented);
            canvas.DrawImage(image, new SKRect(0, 0, info.Width, info.Height), new SKSamplingOptions(SKCubicResampler.Mitchell));
        }

        using var encoded = SKImage.FromBitmap(resized).Encode(SKEncodedImageFormat.Jpeg, 85);
        using var output = new MemoryStream(encoded.ToArray());
        return await storage.SaveAsync("avatars", "jpg", output, cancellationToken);
    }

    /// <summary>Applies the EXIF orientation, since the rotation tag itself is not kept.</summary>
    private static SKBitmap Orient(SKBitmap source, SKEncodedOrigin origin)
    {
        var (width, height, transform) = origin switch
        {
            SKEncodedOrigin.RightTop => (source.Height, source.Width, SKMatrix.CreateRotationDegrees(90).PostConcat(SKMatrix.CreateTranslation(source.Height, 0))),
            SKEncodedOrigin.BottomRight => (source.Width, source.Height, SKMatrix.CreateRotationDegrees(180).PostConcat(SKMatrix.CreateTranslation(source.Width, source.Height))),
            SKEncodedOrigin.LeftBottom => (source.Height, source.Width, SKMatrix.CreateRotationDegrees(270).PostConcat(SKMatrix.CreateTranslation(0, source.Width))),
            _ => (source.Width, source.Height, SKMatrix.Identity),
        };
        var result = new SKBitmap(width, height, source.ColorType, source.AlphaType);
        using var canvas = new SKCanvas(result);
        canvas.SetMatrix(transform);
        canvas.DrawBitmap(source, 0, 0);
        return result;
    }
}

/// <summary>Records a player's last activity at most once every 15 minutes (spec player-profile › Last-active tracking).</summary>
public sealed class PlayerActivityTracker(IMemoryCache throttle, IServiceProvider services, TimeProvider clock)
{
    private static readonly TimeSpan Interval = TimeSpan.FromMinutes(15);

    public async Task TouchAsync(Guid userId, CancellationToken cancellationToken)
    {
        var key = $"activity:{userId:N}";
        if (throttle.TryGetValue(key, out _))
            return;
        throttle.Set(key, true, Interval);
        var now = clock.GetUtcNow().UtcDateTime;
        await using var scope = services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<CommunityDbContext>();
        await db.PlayerProfiles.Where(p => p.Id == userId && p.LastActiveAt < now)
            .ExecuteUpdateAsync(s => s.SetProperty(p => p.LastActiveAt, now), cancellationToken);
    }
}

/// <summary>Keeps profiles in step with account status (design D3): hidden while suspended or banned, anonymised on deletion.</summary>
public sealed class AccountStatusSubscriber(CommunityDbContext db, ICommunityUnitOfWork unitOfWork, TimeProvider clock) : ICapSubscribe
{
    [CapSubscribe(IdentityTopics.AccountSuspended, Group = CommunityModule.CapGroup)]
    public async Task OnSuspended(AccountSuspended message)
    {
        await LeaveFutureMatchesAsync(message.UserId);
        await ChangeAsync(message.UserId, p => p.Hide());
    }

    [CapSubscribe(IdentityTopics.AccountBanned, Group = CommunityModule.CapGroup)]
    public async Task OnBanned(AccountBanned message)
    {
        await LeaveFutureMatchesAsync(message.UserId);
        await ChangeAsync(message.UserId, p => p.Hide());
    }

    /// <summary>
    /// A player who can no longer play is taken out of future games, and the games they host are cancelled. No late
    /// cancellation is recorded (spec match-lifecycle › Account changes affect future matches).
    /// </summary>
    private async Task LeaveFutureMatchesAsync(Guid userId)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var matches = await db.Matches.Where(m => m.StartsAt > now && m.Participants.Any(p => p.PlayerId == userId)).ToListAsync();
        foreach (var match in matches)
            match.RemoveForAccount(userId, now);
        await unitOfWork.SaveAndPublishEventsAsync();
    }

    [CapSubscribe(IdentityTopics.AccountReactivated, Group = CommunityModule.CapGroup)]
    public Task OnReactivated(AccountReactivated message) => ChangeAsync(message.UserId, p => p.Show());

    [CapSubscribe(IdentityTopics.AccountDeleted, Group = CommunityModule.CapGroup)]
    public async Task OnDeleted(AccountDeleted message)
    {
        // Windows and saved searches of a deleted account are removed (spec availability); the profile stays, anonymised, for match history.
        await LeaveFutureMatchesAsync(message.UserId);
        await db.Availability.Where(a => a.PlayerId == message.UserId).ExecuteDeleteAsync();
        await db.SavedSearches.Where(s => s.OwnerId == message.UserId).ExecuteDeleteAsync();
        await ChangeAsync(message.UserId, p => p.Anonymize());
    }

    private async Task ChangeAsync(Guid userId, Action<Domain.Players.PlayerProfile> change)
    {
        var profile = await db.PlayerProfiles.FirstOrDefaultAsync(p => p.Id == userId);
        if (profile is null)
            return;
        change(profile);
        await db.SaveChangesAsync();
    }
}
