using Rallyto.Catalog.Domain.Sports;
using Rallyto.Catalog.Domain.Venues;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Catalog.Application;

public sealed record SportFormatDto(PlayFormat Format, int PlayersPerSide, int Capacity);

public sealed record LevelTierDto(LevelTier Tier, int Order, string Name, string Description);

public sealed record SportDto(
    Guid Id,
    string Code,
    string NameFa,
    string NameEn,
    int SortOrder,
    bool IsActive,
    int DefaultSessionMinutes,
    IReadOnlyList<SportFormatDto> Formats,
    IReadOnlyList<LevelTierDto> Levels,
    IReadOnlyList<CourtSurface> Surfaces);

public sealed record ProvinceDto(int Id, string Name);

public sealed record CityDto(int Id, int ProvinceId, string Name, int ActiveVenueCount);

public sealed record VenueSportDto(string SportCode, int? CourtCount, CourtSetting Setting, CourtSurface? Surface, bool HasLighting);

public sealed record VenueDto(
    Guid Id,
    string Name,
    int CityId,
    string CityName,
    string? Address,
    string? Phone,
    double? Latitude,
    double? Longitude,
    VenueStatus Status,
    string? GooglePlaceId,
    IReadOnlyList<VenueSportDto> Sports,
    string? Tagline,
    string? Description,
    string? Website,
    string? Instagram,
    string? Telegram,
    string? WorkingHours,
    IReadOnlyList<string> Amenities,
    IReadOnlyList<string> CourtTypes,
    string? CoverImage,
    IReadOnlyList<string> Images,
    string? SourceUrl,
    double? GoogleRating,
    int? GoogleReviewCount);

public sealed record VenueCandidateDto(
    Guid Id,
    int CityId,
    string Name,
    string? Address,
    double? Latitude,
    double? Longitude,
    string PlaceId,
    string? Keyword,
    CandidateStatus Status,
    Guid? ResolvedVenueId,
    DateTime ImportedAt);

public sealed record VenueSportInput(string SportCode, int? CourtCount, CourtSetting Setting, CourtSurface? Surface, bool HasLighting);

public static class LevelTierNames
{
    public static string Persian(LevelTier tier) => tier switch
    {
        LevelTier.Beginner => "مبتدی",
        LevelTier.LowerIntermediate => "متوسط رو به پایین",
        LevelTier.Intermediate => "متوسط",
        LevelTier.Advanced => "پیشرفته",
        LevelTier.Professional => "حرفه‌ای",
        _ => tier.ToString(),
    };
}

public static class CatalogMapping
{
    public const string CacheTag = "catalog";

    public static SportDto ToDto(Sport sport) => new(
        sport.Id,
        sport.Code,
        sport.NameFa,
        sport.NameEn,
        sport.SortOrder,
        sport.IsActive,
        sport.DefaultSessionMinutes,
        sport.Formats.Select(f => new SportFormatDto(f.Format, f.PlayersPerSide, f.Capacity)).ToList(),
        sport.Levels.Select(l => new LevelTierDto(l.Tier, (int)l.Tier, LevelTierNames.Persian(l.Tier), l.Description)).ToList(),
        sport.Surfaces);

    public static VenueDto ToDto(Venue venue, string cityName, IReadOnlyDictionary<Guid, string> sportCodes) => new(
        venue.Id,
        venue.Name,
        venue.CityId,
        cityName,
        venue.Address,
        venue.Phone,
        venue.Latitude,
        venue.Longitude,
        venue.Status,
        venue.GooglePlaceId,
        venue.Sports.Select(s => new VenueSportDto(sportCodes.GetValueOrDefault(s.SportId, "?"), s.CourtCount, s.Setting, s.Surface, s.HasLighting)).ToList(),
        venue.Profile.Tagline,
        venue.Profile.Description,
        venue.Profile.Website,
        venue.Profile.Instagram,
        venue.Profile.Telegram,
        venue.Profile.WorkingHours,
        venue.Profile.Amenities,
        venue.Profile.CourtTypes,
        venue.CoverImage,
        venue.Images.OrderBy(i => i.SortOrder).Select(i => i.Path).ToList(),
        venue.SourceUrl,
        venue.GoogleRating,
        venue.GoogleReviewCount);

    public static VenueCandidateDto ToDto(VenueCandidate c) =>
        new(c.Id, c.CityId, c.Name, c.Address, c.Latitude, c.Longitude, c.PlaceId, c.Keyword, c.Status, c.ResolvedVenueId, c.ImportedAt);
}
