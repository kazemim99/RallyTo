using Rallyto.Catalog.Application.Abstractions;
using Rallyto.Catalog.Application.Locations;
using Rallyto.Catalog.Domain.Venues;
using Rallyto.Core.Application.Cqrs;

namespace Rallyto.Catalog.Application.Venues;

/// <summary>
/// The public club directory the landing site is built from: every active club with its active sports (in the
/// catalog's order), province and city, sorted by province, city and name in Persian order. Owner decision 2026-11-01:
/// a visitor gets what it takes to find and reach a club (address, phone, position, hours, its own links, description),
/// but no id, import reference or copied rating.
/// </summary>
public sealed record ListPublicVenuesQuery : IQuery<IReadOnlyList<PublicVenueDto>>
{
    public bool IsCacheable => true;
    public IReadOnlyCollection<string>? CacheTags => [CatalogMapping.CacheTag];
}

internal sealed class ListPublicVenuesHandler(IVenueRepository venues, ISportRepository sports, ILocationRepository locations)
    : IQueryHandler<ListPublicVenuesQuery, IReadOnlyList<PublicVenueDto>>
{
    public async Task<IReadOnlyList<PublicVenueDto>> Handle(ListPublicVenuesQuery request, CancellationToken cancellationToken)
    {
        var active = (await sports.ListAsync(includeInactive: false, cancellationToken)).OrderBy(s => s.SortOrder).ToList();
        var list = await venues.ListAsync(new VenueFilter(null, null, null, VenueStatus.Active), cancellationToken);
        var cities = (await locations.GetCitiesAsync(list.Select(v => v.CityId).Distinct(), cancellationToken)).ToDictionary(c => c.Id);
        var provinces = (await locations.ListProvincesAsync(cancellationToken)).ToDictionary(p => p.Id, p => p.Name);

        return list
            .Select(v =>
            {
                var city = cities[v.CityId];
                var offered = active.Where(s => v.Sports.Any(vs => vs.SportId == s.Id)).Select(s => s.Code).ToList();
                return new PublicVenueDto(
                    v.Name,
                    city.ProvinceId,
                    provinces.GetValueOrDefault(city.ProvinceId, string.Empty),
                    city.Id,
                    city.Name,
                    offered,
                    v.Address,
                    v.Phone,
                    v.Latitude,
                    v.Longitude,
                    v.GooglePlaceId,
                    v.Profile.WorkingHours,
                    v.Profile.Website,
                    v.Profile.Instagram,
                    v.Profile.Telegram,
                    v.Profile.Description);
            })
            .Where(v => v.Sports.Count > 0)
            .OrderBy(v => v.ProvinceName, PersianOrder.Comparer)
            .ThenBy(v => v.CityName, PersianOrder.Comparer)
            .ThenBy(v => v.Name, PersianOrder.Comparer)
            .ToList();
    }
}
