using Microsoft.EntityFrameworkCore;
using Rallyto.Catalog.Application.Abstractions;
using Rallyto.Catalog.Domain.Locations;
using Rallyto.Catalog.Domain.Sports;
using Rallyto.Catalog.Domain.Venues;
using Rallyto.Core.Application.Results;

namespace Rallyto.Catalog.Infrastructure.Persistence;

internal sealed class SportRepository(CatalogDbContext db) : ISportRepository
{
    public Task<Sport?> GetByIdAsync(Guid id, CancellationToken cancellationToken) => db.Sports.FirstOrDefaultAsync(s => s.Id == id, cancellationToken);

    public async Task<IReadOnlyList<Sport>> ListAsync(bool includeInactive, CancellationToken cancellationToken) =>
        await db.Sports.Where(s => includeInactive || s.IsActive).OrderBy(s => s.SortOrder).ToListAsync(cancellationToken);

    public Task<bool> CodeExistsAsync(string code, CancellationToken cancellationToken) => db.Sports.AnyAsync(s => s.Code == code, cancellationToken);

    public async Task<int> MaxSortOrderAsync(CancellationToken cancellationToken) =>
        await db.Sports.Select(s => (int?)s.SortOrder).MaxAsync(cancellationToken) ?? 0;

    public void Add(Sport sport) => db.Sports.Add(sport);
}

internal sealed class LocationRepository(CatalogDbContext db) : ILocationRepository
{
    public async Task<IReadOnlyList<Province>> ListProvincesAsync(CancellationToken cancellationToken) =>
        await db.Provinces.AsNoTracking().ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<(City City, int ActiveVenues)>> ListCitiesAsync(int provinceId, CancellationToken cancellationToken)
    {
        var rows = await db.Cities.AsNoTracking()
            .Where(c => c.ProvinceId == provinceId)
            .Select(c => new { City = c, Count = db.Venues.Count(v => v.CityId == c.Id && v.Status == VenueStatus.Active) })
            .ToListAsync(cancellationToken);
        return rows.Select(r => (r.City, r.Count)).ToList();
    }

    public Task<City?> GetCityAsync(int cityId, CancellationToken cancellationToken) =>
        db.Cities.AsNoTracking().FirstOrDefaultAsync(c => c.Id == cityId, cancellationToken);

    public async Task<IReadOnlyDictionary<int, string>> CityNamesAsync(IEnumerable<int> cityIds, CancellationToken cancellationToken)
    {
        var ids = cityIds.ToList();
        return await db.Cities.AsNoTracking().Where(c => ids.Contains(c.Id)).ToDictionaryAsync(c => c.Id, c => c.Name, cancellationToken);
    }
}

internal sealed class VenueRepository(CatalogDbContext db) : IVenueRepository
{
    public Task<Venue?> GetByIdAsync(Guid id, CancellationToken cancellationToken) => db.Venues.FirstOrDefaultAsync(v => v.Id == id, cancellationToken);

    public async Task<IReadOnlyList<Venue>> ListAsync(VenueFilter filter, CancellationToken cancellationToken) =>
        await Filtered(filter).OrderBy(v => v.Name).ToListAsync(cancellationToken);

    public async Task<PagedResult<Venue>> PageAsync(VenueFilter filter, int page, int pageSize, CancellationToken cancellationToken)
    {
        var query = Filtered(filter);
        var total = await query.CountAsync(cancellationToken);
        var items = await query.OrderBy(v => v.Name).Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(cancellationToken);
        return new PagedResult<Venue>(items, page, pageSize, total);
    }

    public async Task<IReadOnlySet<string>> PlaceIdsInCatalogAsync(IReadOnlyCollection<string> placeIds, CancellationToken cancellationToken) =>
        (await db.Venues.Where(v => v.GooglePlaceId != null && placeIds.Contains(v.GooglePlaceId)).Select(v => v.GooglePlaceId!).ToListAsync(cancellationToken))
        .ToHashSet(StringComparer.Ordinal);

    public async Task<IReadOnlyDictionary<string, Guid>> VenueIdsBySourceRefAsync(IReadOnlyCollection<string> sourceRefs, CancellationToken cancellationToken) =>
        await db.Venues.Where(v => v.SourceRef != null && sourceRefs.Contains(v.SourceRef)).ToDictionaryAsync(v => v.SourceRef!, v => v.Id, cancellationToken);

    public async Task<IReadOnlyDictionary<string, Guid>> VenueIdsByPlaceIdAsync(IReadOnlyCollection<string> placeIds, CancellationToken cancellationToken) =>
        await db.Venues.Where(v => v.GooglePlaceId != null && placeIds.Contains(v.GooglePlaceId)).ToDictionaryAsync(v => v.GooglePlaceId!, v => v.Id, cancellationToken);

    public void Add(Venue venue) => db.Venues.Add(venue);

    private IQueryable<Venue> Filtered(VenueFilter filter)
    {
        var query = db.Venues.AsQueryable();
        if (filter.CityId is { } cityId)
            query = query.Where(v => v.CityId == cityId);
        if (filter.Status is { } status)
            query = query.Where(v => v.Status == status);
        if (filter.SportId is { } sportId)
            query = query.Where(v => v.Sports.Any(s => s.SportId == sportId));
        if (filter.NormalizedQuery is { } text)
            query = query.Where(v => v.NormalizedName.Contains(text));
        return query;
    }
}

internal sealed class VenueCandidateRepository(CatalogDbContext db) : IVenueCandidateRepository
{
    public Task<VenueCandidate?> GetByIdAsync(Guid id, CancellationToken cancellationToken) => db.VenueCandidates.FirstOrDefaultAsync(c => c.Id == id, cancellationToken);

    public async Task<IReadOnlyList<VenueCandidate>> GetByIdsAsync(IReadOnlyCollection<Guid> ids, CancellationToken cancellationToken) =>
        await db.VenueCandidates.Where(c => ids.Contains(c.Id)).ToListAsync(cancellationToken);

    public async Task<IReadOnlySet<string>> KnownPlaceIdsAsync(IReadOnlyCollection<string> placeIds, CancellationToken cancellationToken) =>
        (await db.VenueCandidates.Where(c => placeIds.Contains(c.PlaceId)).Select(c => c.PlaceId).ToListAsync(cancellationToken)).ToHashSet(StringComparer.Ordinal);

    public async Task<PagedResult<VenueCandidate>> PageAsync(int? provinceId, int? cityId, CandidateStatus? status, string? keyword, int page, int pageSize, CancellationToken cancellationToken)
    {
        var query = db.VenueCandidates.AsNoTracking();
        if (cityId is { } city)
            query = query.Where(c => c.CityId == city);
        else if (provinceId is { } province)
            query = query.Where(c => db.Cities.Any(x => x.Id == c.CityId && x.ProvinceId == province));
        if (status is { } s)
            query = query.Where(c => c.Status == s);
        if (!string.IsNullOrWhiteSpace(keyword))
            query = query.Where(c => c.Keyword == keyword);
        var total = await query.CountAsync(cancellationToken);
        var items = await query.OrderBy(c => c.ImportedAt).ThenBy(c => c.Name).Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(cancellationToken);
        return new PagedResult<VenueCandidate>(items, page, pageSize, total);
    }

    public void Add(VenueCandidate candidate) => db.VenueCandidates.Add(candidate);
}
