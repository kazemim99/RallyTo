using Rallyto.Catalog.Domain.Locations;
using Rallyto.Catalog.Domain.Sports;
using Rallyto.Catalog.Domain.Venues;
using Rallyto.Core.Application.Results;

namespace Rallyto.Catalog.Application.Abstractions;

public interface ISportRepository
{
    Task<Sport?> GetByIdAsync(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyList<Sport>> ListAsync(bool includeInactive, CancellationToken cancellationToken);
    Task<bool> CodeExistsAsync(string code, CancellationToken cancellationToken);
    Task<int> MaxSortOrderAsync(CancellationToken cancellationToken);
    void Add(Sport sport);
}

public interface ILocationRepository
{
    Task<IReadOnlyList<Province>> ListProvincesAsync(CancellationToken cancellationToken);
    Task<IReadOnlyList<(City City, int ActiveVenues)>> ListCitiesAsync(int provinceId, CancellationToken cancellationToken);
    Task<City?> GetCityAsync(int cityId, CancellationToken cancellationToken);
    Task<IReadOnlyDictionary<int, string>> CityNamesAsync(IEnumerable<int> cityIds, CancellationToken cancellationToken);
}

public sealed record VenueFilter(int? CityId, Guid? SportId, string? NormalizedQuery, VenueStatus? Status);

public interface IVenueRepository
{
    Task<Venue?> GetByIdAsync(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyList<Venue>> ListAsync(VenueFilter filter, CancellationToken cancellationToken);
    Task<PagedResult<Venue>> PageAsync(VenueFilter filter, int page, int pageSize, CancellationToken cancellationToken);
    Task<IReadOnlySet<string>> PlaceIdsInCatalogAsync(IReadOnlyCollection<string> placeIds, CancellationToken cancellationToken);
    Task<IReadOnlyDictionary<string, Guid>> VenueIdsBySourceRefAsync(IReadOnlyCollection<string> sourceRefs, CancellationToken cancellationToken);
    Task<IReadOnlyDictionary<string, Guid>> VenueIdsByPlaceIdAsync(IReadOnlyCollection<string> placeIds, CancellationToken cancellationToken);
    void Add(Venue venue);
}

public interface IVenueCandidateRepository
{
    Task<VenueCandidate?> GetByIdAsync(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyList<VenueCandidate>> GetByIdsAsync(IReadOnlyCollection<Guid> ids, CancellationToken cancellationToken);
    Task<IReadOnlySet<string>> KnownPlaceIdsAsync(IReadOnlyCollection<string> placeIds, CancellationToken cancellationToken);
    Task<PagedResult<VenueCandidate>> PageAsync(int? provinceId, int? cityId, CandidateStatus? status, string? keyword, int page, int pageSize, CancellationToken cancellationToken);
    void Add(VenueCandidate candidate);
}
