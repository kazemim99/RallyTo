namespace Rallyto.VenueImport;

public sealed record City(int Id, int ProvinceId, string Name, string ProvinceName);

/// <summary>What the API's <c>POST /api/v1/admin/venue-candidates/import</c> accepts.</summary>
public sealed record Candidate(string PlaceId, string Name, string? Address, double? Latitude, double? Longitude, int CityId, string Keyword);

/// <summary>A source of candidate clubs. Google Places today; OpenStreetMap or Neshan can be added as further adapters.</summary>
public interface IVenueSource
{
    string Name { get; }

    IAsyncEnumerable<Candidate> SearchAsync(City city, string keyword, CancellationToken cancellationToken);
}

public static class SportKeywords
{
    /// <summary>
    /// Search phrases per seeded sport (spec venue-catalog › Keywords cover every seeded sport). The city name is
    /// appended to each phrase.
    /// </summary>
    public static readonly IReadOnlyDictionary<string, string[]> BySport = new Dictionary<string, string[]>
    {
        ["tennis"] = ["باشگاه تنیس", "زمین تنیس"],
        ["padel"] = ["پدل"],
        ["badminton"] = ["سالن بدمینتون"],
        ["squash"] = ["اسکواش"],
    };

    public static IEnumerable<string> All => BySport.Values.SelectMany(k => k).Distinct();
}
