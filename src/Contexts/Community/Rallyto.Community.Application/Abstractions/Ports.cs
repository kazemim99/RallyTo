using Rallyto.Community.Domain.Players;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Community.Application.Abstractions;

public interface IPlayerProfileRepository
{
    Task<PlayerProfile?> GetAsync(Guid userId, CancellationToken cancellationToken);
    Task<bool> ExistsAsync(Guid userId, CancellationToken cancellationToken);
    Task<IReadOnlyDictionary<Guid, string>> DisplayNamesAsync(IReadOnlyCollection<Guid> userIds, CancellationToken cancellationToken);
    void Add(PlayerProfile profile);
}

public interface IBlockRepository
{
    Task<bool> IsBlockedEitherWayAsync(Guid a, Guid b, CancellationToken cancellationToken);
    Task<Block?> GetAsync(Guid blockerId, Guid blockedId, CancellationToken cancellationToken);
    Task<IReadOnlyList<Block>> ListByBlockerAsync(Guid blockerId, CancellationToken cancellationToken);
    void Add(Block block);
    void Remove(Block block);
}

public interface IAvailabilityRepository
{
    Task<Domain.Availabilities.Availability?> GetAsync(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyList<Domain.Availabilities.Availability>> ListByPlayerAsync(Guid playerId, CancellationToken cancellationToken);
    Task<IReadOnlyList<Domain.Availabilities.Availability>> ListByPlayerAndSportAsync(Guid playerId, Guid sportId, CancellationToken cancellationToken);
    Task<IReadOnlyList<Domain.Availabilities.Availability>> ListContainingVenueAsync(Guid venueId, CancellationToken cancellationToken);
    void Add(Domain.Availabilities.Availability availability);
    void Remove(Domain.Availabilities.Availability availability);
}

public sealed record CatalogSportFormat(PlayFormat Format, int Capacity);

public sealed record CatalogLevel(LevelTier Tier, string Name, string Description);

public sealed record CatalogSport(
    Guid Id,
    string Code,
    string NameFa,
    bool IsActive,
    int DefaultSessionMinutes,
    IReadOnlyList<CatalogSportFormat> Formats,
    IReadOnlyList<CatalogLevel> Levels)
{
    public bool Allows(PlayFormat format) => Formats.Any(f => f.Format == format);

    public int CapacityOf(PlayFormat format) => Formats.First(f => f.Format == format).Capacity;
}

public sealed record CatalogVenue(Guid Id, string Name, int CityId, bool IsActive, IReadOnlyCollection<Guid> SportIds)
{
    public bool Offers(Guid sportId) => IsActive && SportIds.Contains(sportId);
}

public sealed record CatalogCity(int Id, int ProvinceId, string Name);

/// <summary>
/// Read-only view of Catalog's reference data. Community never references Catalog; the host implements this
/// in-process (design D3).
/// </summary>
public interface ICatalogReader
{
    Task<IReadOnlyList<CatalogSport>> SportsAsync(CancellationToken cancellationToken);
    Task<IReadOnlyDictionary<Guid, CatalogVenue>> VenuesAsync(IReadOnlyCollection<Guid> venueIds, CancellationToken cancellationToken);
    Task<CatalogCity?> CityAsync(int cityId, CancellationToken cancellationToken);
}

/// <summary>Validates, resizes and stores profile photos.</summary>
public interface IAvatarProcessor
{
    /// <returns>The public path of the stored photo.</returns>
    Task<string> ProcessAndStoreAsync(Stream upload, long length, string? contentType, CancellationToken cancellationToken);
}
