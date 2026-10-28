using Rallyto.Catalog.Application.Abstractions;
using Rallyto.Catalog.Application.Sports;
using Rallyto.Catalog.Domain.Venues;
using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Core.Application.Results;

namespace Rallyto.Catalog.Application.Venues;

public sealed record CandidateInput(string PlaceId, string Name, string? Address, double? Latitude, double? Longitude, int CityId, string? Keyword);

public sealed record ImportResultDto(int Created, int SkippedInCatalog, int SkippedKnown);

public sealed record ImportCandidatesCommand(IReadOnlyList<CandidateInput> Items) : ICommand<ImportResultDto>;

public sealed record ListCandidatesQuery(int? ProvinceId, int? CityId, CandidateStatus? Status, string? Keyword, int Page = 1, int PageSize = 20)
    : IQuery<PagedResult<VenueCandidateDto>>;

public sealed record ApproveCandidateCommand(
    Guid CandidateId,
    string Name,
    string? Address,
    string? Phone,
    double? Latitude,
    double? Longitude,
    IReadOnlyList<VenueSportInput> Sports) : ICommand<VenueDto>;

public sealed record MergeCandidateCommand(Guid CandidateId, Guid VenueId) : ICommand;

public sealed record RejectCandidateCommand(Guid CandidateId, string Reason) : ICommand;

public sealed record BulkApproveCandidatesCommand(IReadOnlyList<Guid> CandidateIds, IReadOnlyList<VenueSportInput> Sports) : ICommand;

/// <summary>
/// Idempotent import (design D15): a place already in the catalog, or already imported in any state, is skipped,
/// so re-running the import tool never duplicates and rejected places stay away.
/// </summary>
internal sealed class ImportCandidatesHandler(
    IVenueRepository venues,
    IVenueCandidateRepository candidates,
    VenueAssembler assembler,
    CatalogAdminSession session) : ICommandHandler<ImportCandidatesCommand, ImportResultDto>
{
    private const int MaxBatch = 500;

    public async Task<ImportResultDto> Handle(ImportCandidatesCommand request, CancellationToken cancellationToken)
    {
        if (request.Items.Count > MaxBatch)
            throw new ValidationFailedException("IMPORT_TOO_LARGE", $"هر بار حداکثر {MaxBatch} مورد.");

        var items = request.Items.Where(i => !string.IsNullOrWhiteSpace(i.PlaceId)).GroupBy(i => i.PlaceId.Trim()).Select(g => g.First()).ToList();
        var placeIds = items.Select(i => i.PlaceId.Trim()).ToList();
        var inCatalog = await venues.PlaceIdsInCatalogAsync(placeIds, cancellationToken);
        var known = await candidates.KnownPlaceIdsAsync(placeIds, cancellationToken);

        int created = 0, skippedInCatalog = 0, skippedKnown = 0;
        foreach (var item in items)
        {
            var placeId = item.PlaceId.Trim();
            if (inCatalog.Contains(placeId))
            {
                skippedInCatalog++;
                continue;
            }

            if (known.Contains(placeId))
            {
                skippedKnown++;
                continue;
            }

            await assembler.EnsureCityExistsAsync(item.CityId, cancellationToken);
            candidates.Add(VenueCandidate.Import(item.CityId, item.Name, item.Address, item.Latitude, item.Longitude, placeId, item.Keyword, session.Now));
            created++;
        }

        await session.CommitAsync("venue-candidates.import", "VenueCandidate", $"{created} created", null, cancellationToken);
        return new ImportResultDto(created, skippedInCatalog, skippedKnown);
    }
}

internal sealed class ListCandidatesHandler(IVenueCandidateRepository candidates) : IQueryHandler<ListCandidatesQuery, PagedResult<VenueCandidateDto>>
{
    public async Task<PagedResult<VenueCandidateDto>> Handle(ListCandidatesQuery request, CancellationToken cancellationToken)
    {
        var page = await candidates.PageAsync(request.ProvinceId, request.CityId, request.Status, request.Keyword,
            Math.Max(1, request.Page), Math.Clamp(request.PageSize, 1, 100), cancellationToken);
        return new PagedResult<VenueCandidateDto>(page.Items.Select(CatalogMapping.ToDto).ToList(), page.Page, page.PageSize, page.TotalCount);
    }
}

internal sealed class ApproveCandidateHandler(
    IVenueRepository venues,
    IVenueCandidateRepository candidates,
    VenueAssembler assembler,
    CatalogAdminSession session) : ICommandHandler<ApproveCandidateCommand, VenueDto>
{
    public async Task<VenueDto> Handle(ApproveCandidateCommand request, CancellationToken cancellationToken)
    {
        var candidate = await candidates.GetByIdAsync(request.CandidateId, cancellationToken) ?? throw new NotFoundException();
        var venue = Venue.Create(candidate.CityId,
            new VenueDetails(request.Name, request.Address, request.Phone, request.Latitude, request.Longitude),
            await assembler.ToVenueSportsAsync(request.Sports, cancellationToken), candidate.PlaceId);
        venues.Add(venue);
        candidate.MarkApproved(venue.Id, session.AdminId, session.Now);
        await session.CommitAsync("venue-candidate.approve", "VenueCandidate", candidate.Id.ToString(), null, cancellationToken);
        return await assembler.ToDtoAsync(venue, cancellationToken);
    }
}

internal sealed class MergeCandidateHandler(IVenueRepository venues, IVenueCandidateRepository candidates, CatalogAdminSession session) : ICommandHandler<MergeCandidateCommand>
{
    public async Task Handle(MergeCandidateCommand request, CancellationToken cancellationToken)
    {
        var candidate = await candidates.GetByIdAsync(request.CandidateId, cancellationToken) ?? throw new NotFoundException();
        var venue = await venues.GetByIdAsync(request.VenueId, cancellationToken) ?? throw new NotFoundException("باشگاه پیدا نشد.");
        venue.AttachPlace(candidate.PlaceId);
        candidate.MarkMerged(venue.Id, session.AdminId, session.Now);
        await session.CommitAsync("venue-candidate.merge", "VenueCandidate", candidate.Id.ToString(), null, cancellationToken);
    }
}

internal sealed class RejectCandidateHandler(IVenueCandidateRepository candidates, CatalogAdminSession session) : ICommandHandler<RejectCandidateCommand>
{
    public async Task Handle(RejectCandidateCommand request, CancellationToken cancellationToken)
    {
        var candidate = await candidates.GetByIdAsync(request.CandidateId, cancellationToken) ?? throw new NotFoundException();
        candidate.Reject(string.IsNullOrWhiteSpace(request.Reason) ? "rejected" : request.Reason.Trim(), session.AdminId, session.Now);
        await session.CommitAsync("venue-candidate.reject", "VenueCandidate", candidate.Id.ToString(), request.Reason, cancellationToken);
    }
}

/// <summary>Approves several candidates at once with the same sports; court details can be filled in later (spec venue-catalog).</summary>
internal sealed class BulkApproveCandidatesHandler(
    IVenueRepository venues,
    IVenueCandidateRepository candidates,
    VenueAssembler assembler,
    CatalogAdminSession session) : ICommandHandler<BulkApproveCandidatesCommand>
{
    public async Task Handle(BulkApproveCandidatesCommand request, CancellationToken cancellationToken)
    {
        var selected = await candidates.GetByIdsAsync(request.CandidateIds.Distinct().ToList(), cancellationToken);
        if (selected.Count == 0)
            throw new ValidationFailedException("NO_CANDIDATES", "هیچ موردی انتخاب نشده است.");
        var sports = await assembler.ToVenueSportsAsync(request.Sports, cancellationToken);

        foreach (var candidate in selected.Where(c => c.Status == CandidateStatus.Pending))
        {
            var venue = Venue.Create(candidate.CityId,
                new VenueDetails(candidate.Name, candidate.Address, null, candidate.Latitude, candidate.Longitude), sports, candidate.PlaceId);
            venues.Add(venue);
            candidate.MarkApproved(venue.Id, session.AdminId, session.Now);
        }

        await session.CommitAsync("venue-candidates.bulk-approve", "VenueCandidate", $"{selected.Count} selected", null, cancellationToken);
    }
}
