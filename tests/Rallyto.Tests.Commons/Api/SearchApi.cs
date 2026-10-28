namespace Rallyto.Tests.Commons.Api;

public sealed record MatchingWindowView(
    Guid AvailabilityId,
    IReadOnlyList<NamedRef> Venues,
    string[] Weekdays,
    string? Date,
    string StartTime,
    string EndTime,
    string OverlapStart,
    string OverlapEnd,
    string[] Formats);

public sealed record PartnerResultView(
    Guid UserId,
    string DisplayName,
    string? PhotoUrl,
    string Gender,
    string AgeRange,
    string Level,
    string LevelName,
    string Experience,
    string LastActive,
    IReadOnlyList<MatchingWindowView> Windows);

public sealed record SearchResultsView(IReadOnlyList<PartnerResultView> Players, string? NextCursor);

public sealed record SavedSearchView(Guid Id, string Name, bool AlertsEnabled, int AlertsSent, int PendingMatches, DateTime? LastAlertAt, string? ExpiresOn);

public static class SearchApi
{
    public const string Partners = "/api/v1/search/partners";
    public const string SavedSearches = "/api/v1/saved-searches";

    public static string Query(Guid sportId, string? date = null, string? weekdays = null, string? from = null, string? to = null,
        Guid[]? venueIds = null, string? minLevel = null, string? maxLevel = null, string? gender = null, string? cursor = null, int? cityId = null)
    {
        var parts = new List<string> { $"sportId={sportId}" };
        void Add(string key, string? value)
        {
            if (value is not null)
                parts.Add($"{key}={Uri.EscapeDataString(value)}");
        }

        Add("date", date);
        Add("weekdays", weekdays);
        Add("from", from);
        Add("to", to);
        Add("minLevel", minLevel);
        Add("maxLevel", maxLevel);
        Add("gender", gender);
        Add("cursor", cursor);
        Add("cityId", cityId?.ToString());
        foreach (var venue in venueIds ?? [])
            parts.Add($"venueIds={venue}");
        return $"{Partners}?{string.Join('&', parts)}";
    }
}
