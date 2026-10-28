using Rallyto.Catalog.Application.Abstractions;
using Rallyto.Catalog.Application.Sports;
using Rallyto.Catalog.Domain.Venues;
using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Core.Domain.Exceptions;

namespace Rallyto.Catalog.Application.Venues;

public sealed record VenueProfileInput(
    string? Tagline,
    string? Description,
    string? Website,
    string? Instagram,
    string? Telegram,
    string? WorkingHours,
    IReadOnlyList<string>? Amenities,
    IReadOnlyList<string>? CourtTypes);

/// <summary>One club from an outside listing. <paramref name="SourceRef"/> identifies it across re-imports.</summary>
public sealed record VenueImportItem(
    string SourceRef,
    string? SourceUrl,
    int CityId,
    string Name,
    string? Address,
    string? Phone,
    double? Latitude,
    double? Longitude,
    IReadOnlyList<VenueSportInput> Sports,
    VenueProfileInput? Profile,
    string? GooglePlaceId = null,
    double? GoogleRating = null,
    int? GoogleReviewCount = null);

public static class VenueImportOutcomes
{
    public const string Created = "Created";
    public const string Existing = "Existing";
    public const string Similar = "Similar";
    public const string Invalid = "Invalid";
}

public sealed record VenueImportOutcome(string SourceRef, string Outcome, Guid? VenueId, string? Message);

public sealed record VenueImportResultDto(int Created, int Existing, int Skipped, IReadOnlyList<VenueImportOutcome> Items);

public sealed record UpdateVenueProfileCommand(Guid VenueId, VenueProfileInput Profile) : ICommand<VenueDto>;

public sealed record ImportVenuesCommand(IReadOnlyList<VenueImportItem> Items, bool AllowSimilar) : ICommand<VenueImportResultDto>;

/// <summary>
/// Bulk, idempotent creation of clubs with their profile. A club whose source reference is already in the catalog is
/// left as it is (an admin may have edited it); a club similar to one already in the catalog (clubs of the same
/// import are not compared with each other) is skipped unless <c>AllowSimilar</c> is set; an invalid club is reported without failing the rest of the batch.
/// </summary>
internal sealed class ImportVenuesHandler(IVenueRepository venues, VenueAssembler assembler, CatalogAdminSession session)
    : ICommandHandler<ImportVenuesCommand, VenueImportResultDto>
{
    private const int MaxBatch = 100;

    public async Task<VenueImportResultDto> Handle(ImportVenuesCommand request, CancellationToken cancellationToken)
    {
        if (request.Items.Count > MaxBatch)
            throw new ValidationFailedException("IMPORT_TOO_LARGE", $"هر بار حداکثر {MaxBatch} مورد.");

        var refs = request.Items.Where(i => !string.IsNullOrWhiteSpace(i.SourceRef)).Select(i => i.SourceRef.Trim()).Distinct().ToList();
        var known = await venues.VenueIdsBySourceRefAsync(refs, cancellationToken);
        var placeIds = request.Items.Select(i => i.GooglePlaceId?.Trim()).OfType<string>().Where(p => p.Length > 0).Distinct().ToList();
        var knownPlaces = await venues.VenueIdsByPlaceIdAsync(placeIds, cancellationToken);
        var namesByCity = new Dictionary<int, List<string>>();
        var seen = new HashSet<string>();
        var outcomes = new List<VenueImportOutcome>();
        var created = new List<Venue>();

        foreach (var item in request.Items)
        {
            var sourceRef = item.SourceRef?.Trim() ?? string.Empty;
            var placeId = string.IsNullOrWhiteSpace(item.GooglePlaceId) ? null : item.GooglePlaceId.Trim();
            if ((sourceRef.Length > 0 && known.TryGetValue(sourceRef, out var existingId)) || (placeId is not null && knownPlaces.TryGetValue(placeId, out existingId)))
            {
                outcomes.Add(new VenueImportOutcome(sourceRef, VenueImportOutcomes.Existing, existingId, null));
                continue;
            }

            if ((sourceRef.Length > 0 && !seen.Add(sourceRef)) || (placeId is not null && !seen.Add("place:" + placeId)))
            {
                outcomes.Add(new VenueImportOutcome(sourceRef, VenueImportOutcomes.Invalid, null, "منبع تکراری در همین درخواست."));
                continue;
            }

            try
            {
                await assembler.EnsureCityExistsAsync(item.CityId, cancellationToken);
                if (!namesByCity.TryGetValue(item.CityId, out var names))
                {
                    var inCity = await venues.ListAsync(new VenueFilter(item.CityId, null, null, VenueStatus.Active), cancellationToken);
                    namesByCity[item.CityId] = names = inCity.Select(v => v.Name).ToList();
                }

                if (!request.AllowSimilar && names.FirstOrDefault(n => VenueNameSimilarity.AreSimilar(n, item.Name)) is { } similar)
                {
                    outcomes.Add(new VenueImportOutcome(sourceRef, VenueImportOutcomes.Similar, null, $"مشابه «{similar}»"));
                    continue;
                }

                var venue = Venue.Create(item.CityId,
                    new VenueDetails(item.Name, item.Address, item.Phone, item.Latitude, item.Longitude),
                    await assembler.ToVenueSportsAsync(item.Sports ?? [], cancellationToken), placeId);
                venue.SetGoogleRating(item.GoogleRating, item.GoogleReviewCount);
                var p = item.Profile;
                if (p is not null)
                    venue.SetProfile(new VenueProfile(p.Tagline, p.Description, p.Website, p.Instagram, p.Telegram, p.WorkingHours, p.Amenities ?? [], p.CourtTypes ?? []));
                venue.SetSource(sourceRef, item.SourceUrl);

                venues.Add(venue);
                created.Add(venue);
                outcomes.Add(new VenueImportOutcome(sourceRef, VenueImportOutcomes.Created, venue.Id, null));
            }
            catch (Exception e) when (e is DomainException or AppException)
            {
                outcomes.Add(new VenueImportOutcome(sourceRef, VenueImportOutcomes.Invalid, null, e.Message));
            }
        }

        if (created.Count > 0)
            await session.CommitAsync("venue.import", "Venue", $"batch:{created.Count}", null, cancellationToken);

        return new VenueImportResultDto(
            created.Count,
            outcomes.Count(o => o.Outcome == VenueImportOutcomes.Existing),
            outcomes.Count(o => o.Outcome is VenueImportOutcomes.Similar or VenueImportOutcomes.Invalid),
            outcomes);
    }
}

internal sealed class UpdateVenueProfileHandler(IVenueRepository venues, VenueAssembler assembler, CatalogAdminSession session)
    : ICommandHandler<UpdateVenueProfileCommand, VenueDto>
{
    public async Task<VenueDto> Handle(UpdateVenueProfileCommand request, CancellationToken cancellationToken)
    {
        var venue = await venues.GetByIdAsync(request.VenueId, cancellationToken) ?? throw new NotFoundException();
        var p = request.Profile;
        venue.SetProfile(new VenueProfile(p.Tagline, p.Description, p.Website, p.Instagram, p.Telegram, p.WorkingHours, p.Amenities ?? [], p.CourtTypes ?? []));
        await session.CommitAsync("venue.profile.update", "Venue", venue.Id.ToString(), null, cancellationToken);
        return await assembler.ToDtoAsync(venue, cancellationToken);
    }
}
