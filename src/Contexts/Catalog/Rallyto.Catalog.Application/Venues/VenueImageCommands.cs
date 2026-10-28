using Rallyto.Catalog.Application.Abstractions;
using Rallyto.Catalog.Application.Sports;
using Rallyto.Catalog.Domain.Venues;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;

namespace Rallyto.Catalog.Application.Venues;

public sealed record AddVenueImageCommand(Guid VenueId, Stream Content, long Length) : ICommand<VenueDto>;

public sealed record RemoveVenueImageCommand(Guid VenueId, string Path) : ICommand<VenueDto>;

/// <summary>Recognises JPEG, PNG and WebP by their first bytes, so the declared content type is never trusted.</summary>
public static class VenueImageFile
{
    public const long MaxBytes = 10 * 1024 * 1024;

    /// <returns>The file extension, or null when the bytes are not a supported image.</returns>
    public static string? Sniff(ReadOnlySpan<byte> bytes)
    {
        if (bytes.Length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF)
            return "jpg";
        if (bytes.Length >= 8 && bytes[..8].SequenceEqual(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }))
            return "png";
        if (bytes.Length >= 12 && bytes[..4].SequenceEqual("RIFF"u8) && bytes[8..12].SequenceEqual("WEBP"u8))
            return "webp";
        return null;
    }
}

internal sealed class AddVenueImageHandler(IVenueRepository venues, IFileStorage storage, VenueAssembler assembler, CatalogAdminSession session)
    : ICommandHandler<AddVenueImageCommand, VenueDto>
{
    public async Task<VenueDto> Handle(AddVenueImageCommand request, CancellationToken cancellationToken)
    {
        if (request.Length > VenueImageFile.MaxBytes)
            throw new ValidationFailedException("PHOTO_TOO_LARGE", "حجم عکس حداکثر ۱۰ مگابایت است.");
        var venue = await venues.GetByIdAsync(request.VenueId, cancellationToken) ?? throw new NotFoundException();
        if (venue.Images.Count >= Venue.MaxImages)
            throw new ValidationFailedException("VENUE_PHOTO_LIMIT", $"هر باشگاه حداکثر {Venue.MaxImages} عکس می‌تواند داشته باشد.");

        using var buffer = new MemoryStream();
        await request.Content.CopyToAsync(buffer, cancellationToken);
        if (buffer.Length > VenueImageFile.MaxBytes)
            throw new ValidationFailedException("PHOTO_TOO_LARGE", "حجم عکس حداکثر ۱۰ مگابایت است.");
        var extension = VenueImageFile.Sniff(buffer.GetBuffer().AsSpan(0, (int)buffer.Length))
                        ?? throw new ValidationFailedException("PHOTO_TYPE_NOT_ALLOWED", "فقط عکس JPEG، PNG یا WebP پذیرفته می‌شود.");

        buffer.Position = 0;
        var path = await storage.SaveAsync("venues", extension, buffer, cancellationToken);
        try
        {
            venue.AddImage(path);
            await session.CommitAsync("venue.image.add", "Venue", venue.Id.ToString(), null, cancellationToken);
        }
        catch
        {
            await storage.DeleteAsync(path, CancellationToken.None);
            throw;
        }

        return await assembler.ToDtoAsync(venue, cancellationToken);
    }
}

internal sealed class RemoveVenueImageHandler(IVenueRepository venues, IFileStorage storage, VenueAssembler assembler, CatalogAdminSession session)
    : ICommandHandler<RemoveVenueImageCommand, VenueDto>
{
    public async Task<VenueDto> Handle(RemoveVenueImageCommand request, CancellationToken cancellationToken)
    {
        var venue = await venues.GetByIdAsync(request.VenueId, cancellationToken) ?? throw new NotFoundException();
        if (!venue.RemoveImage(request.Path))
            throw new NotFoundException("عکس پیدا نشد.");
        await session.CommitAsync("venue.image.remove", "Venue", venue.Id.ToString(), null, cancellationToken);
        await storage.DeleteAsync(request.Path, cancellationToken);
        return await assembler.ToDtoAsync(venue, cancellationToken);
    }
}
