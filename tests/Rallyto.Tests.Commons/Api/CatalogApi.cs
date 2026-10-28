namespace Rallyto.Tests.Commons.Api;

public sealed record SportFormatDto(string Format, int PlayersPerSide, int Capacity);

public sealed record LevelTierDto(string Tier, int Order, string Name, string Description);

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
    IReadOnlyList<string> Surfaces);

public sealed record ProvinceDto(int Id, string Name);

public sealed record CityDto(int Id, int ProvinceId, string Name, int ActiveVenueCount);

public sealed record VenueSportDto(string SportCode, int? CourtCount, string Setting, string? Surface, bool HasLighting);

public sealed record VenueDto(
    Guid Id,
    string Name,
    int CityId,
    string CityName,
    string? Address,
    string? Phone,
    double? Latitude,
    double? Longitude,
    string Status,
    string? GooglePlaceId,
    IReadOnlyList<VenueSportDto> Sports,
    string? Tagline = null,
    string? Description = null,
    string? Website = null,
    string? Instagram = null,
    string? Telegram = null,
    string? WorkingHours = null,
    IReadOnlyList<string>? Amenities = null,
    IReadOnlyList<string>? CourtTypes = null,
    string? CoverImage = null,
    IReadOnlyList<string>? Images = null,
    string? SourceUrl = null,
    double? GoogleRating = null,
    int? GoogleReviewCount = null);

public sealed record VenueImportOutcomeDto(string SourceRef, string Outcome, Guid? VenueId, string? Message);

public sealed record VenueImportResultDto(int Created, int Existing, int Skipped, IReadOnlyList<VenueImportOutcomeDto> Items);

public sealed record VenueCandidateDto(Guid Id, int CityId, string Name, string? Address, string PlaceId, string? Keyword, string Status, Guid? ResolvedVenueId);

public sealed record ImportResultDto(int Created, int SkippedInCatalog, int SkippedKnown);

public static class CatalogApi
{
    public const string Sports = "/api/v1/sports";
    public const string Provinces = "/api/v1/provinces";
    public const string Venues = "/api/v1/venues";
    public const string AdminSports = "/api/v1/admin/sports";
    public const string AdminVenues = "/api/v1/admin/venues";
    public const string AdminCandidates = "/api/v1/admin/venue-candidates";

    public static object TennisOutdoor(int courts = 6) =>
        new { sportCode = "tennis", courtCount = courts, setting = "Outdoor", surface = "Hard", hasLighting = true };

    public static object Sport(string code, string setting = "Indoor") =>
        new { sportCode = code, courtCount = (int?)null, setting, surface = (string?)null, hasLighting = true };

    public static async Task<int> CityIdAsync(HttpClient client, string provinceName, string cityName)
    {
        var provinces = (await client.GetApiAsync<List<ProvinceDto>>(Provinces)).Data!;
        var province = provinces.Single(p => p.Name == provinceName);
        var cities = (await client.GetApiAsync<List<CityDto>>($"{Provinces}/{province.Id}/cities")).Data!;
        return cities.Single(c => c.Name == cityName).Id;
    }

    /// <summary>Creates an active venue through the admin API and returns it.</summary>
    public static async Task<VenueDto> CreateVenueAsync(HttpClient admin, int cityId, string name, params object[] sports)
    {
        var response = await admin.PostApiAsync<VenueDto>(AdminVenues, new
        {
            cityId,
            name,
            address = "خیابان ولیعصر",
            phone = (string?)null,
            latitude = (double?)null,
            longitude = (double?)null,
            sports = sports.Length == 0 ? [TennisOutdoor()] : sports,
            allowSimilar = true,
        });
        return response.Data ?? throw new InvalidOperationException($"create venue failed: {response.ErrorCode} {response.Error?.Message}");
    }
}
