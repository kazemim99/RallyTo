using System.Globalization;
using Rallyto.Catalog.Application.Abstractions;
using Rallyto.Core.Application.Cqrs;

namespace Rallyto.Catalog.Application.Locations;

public sealed record GetProvincesQuery : IQuery<IReadOnlyList<ProvinceDto>>
{
    public bool IsCacheable => true;
    public IReadOnlyCollection<string>? CacheTags => [CatalogMapping.CacheTag];
}

public sealed record GetCitiesQuery(int ProvinceId) : IQuery<IReadOnlyList<CityDto>>
{
    public bool IsCacheable => true;
    public IReadOnlyCollection<string>? CacheTags => [CatalogMapping.CacheTag];
}

internal static class PersianOrder
{
    public static readonly StringComparer Comparer = StringComparer.Create(new CultureInfo("fa-IR"), ignoreCase: false);
}

internal sealed class GetProvincesHandler(ILocationRepository locations) : IQueryHandler<GetProvincesQuery, IReadOnlyList<ProvinceDto>>
{
    public async Task<IReadOnlyList<ProvinceDto>> Handle(GetProvincesQuery request, CancellationToken cancellationToken) =>
        (await locations.ListProvincesAsync(cancellationToken))
            .OrderBy(p => p.Name, PersianOrder.Comparer)
            .Select(p => new ProvinceDto(p.Id, p.Name))
            .ToList();
}

/// <summary>Cities with at least one active club first, then the rest, each group in Persian order (spec venue-catalog).</summary>
internal sealed class GetCitiesHandler(ILocationRepository locations) : IQueryHandler<GetCitiesQuery, IReadOnlyList<CityDto>>
{
    public async Task<IReadOnlyList<CityDto>> Handle(GetCitiesQuery request, CancellationToken cancellationToken) =>
        (await locations.ListCitiesAsync(request.ProvinceId, cancellationToken))
            .OrderBy(c => c.ActiveVenues > 0 ? 0 : 1)
            .ThenBy(c => c.City.Name, PersianOrder.Comparer)
            .Select(c => new CityDto(c.City.Id, c.City.ProvinceId, c.City.Name, c.ActiveVenues))
            .ToList();
}
