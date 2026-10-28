using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Hybrid;
using Rallyto.Catalog.Application;
using Rallyto.Catalog.Domain.Venues;
using Rallyto.Catalog.Infrastructure.Persistence;
using Rallyto.Community.Application.Abstractions;

namespace Rallyto.Host.Composition;

/// <summary>
/// Community's view of Catalog, served in-process from Catalog's database (design D3, like AsanRezerve's
/// InProcessProviderInfoService). Sports are cached under Catalog's tag, so catalog admin changes evict them.
/// </summary>
public sealed class InProcessCatalogReader(CatalogDbContext catalog, HybridCache cache) : ICatalogReader
{
    private static readonly HybridCacheEntryOptions Entry = new() { Expiration = TimeSpan.FromMinutes(10), LocalCacheExpiration = TimeSpan.FromMinutes(1) };

    public async Task<IReadOnlyList<CatalogSport>> SportsAsync(CancellationToken cancellationToken) =>
        await cache.GetOrCreateAsync("community:catalog-sports", async ct =>
        {
            var sports = await catalog.Sports.AsNoTracking().OrderBy(s => s.SortOrder).ToListAsync(ct);
            return sports.Select(s => new CatalogSport(
                    s.Id, s.Code, s.NameFa, s.IsActive, s.DefaultSessionMinutes,
                    s.Formats.Select(f => new CatalogSportFormat(f.Format, f.Capacity)).ToList(),
                    s.Levels.Select(l => new CatalogLevel(l.Tier, LevelTierNames.Persian(l.Tier), l.Description)).ToList()))
                .ToList();
        }, Entry, [CatalogMapping.CacheTag], cancellationToken);

    public async Task<IReadOnlyDictionary<Guid, CatalogVenue>> VenuesAsync(IReadOnlyCollection<Guid> venueIds, CancellationToken cancellationToken)
    {
        if (venueIds.Count == 0)
            return new Dictionary<Guid, CatalogVenue>();
        var ids = venueIds.Distinct().ToList();
        var venues = await catalog.Venues.AsNoTracking().Where(v => ids.Contains(v.Id)).ToListAsync(cancellationToken);
        return venues.ToDictionary(v => v.Id, v => new CatalogVenue(v.Id, v.Name, v.CityId, v.Status == VenueStatus.Active, v.Sports.Select(s => s.SportId).ToList()));
    }

    public async Task<CatalogCity?> CityAsync(int cityId, CancellationToken cancellationToken)
    {
        var city = await catalog.Cities.AsNoTracking().FirstOrDefaultAsync(c => c.Id == cityId, cancellationToken);
        return city is null ? null : new CatalogCity(city.Id, city.ProvinceId, city.Name);
    }
}
