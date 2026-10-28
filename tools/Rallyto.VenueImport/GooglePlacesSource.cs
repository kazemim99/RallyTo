using System.Net.Http.Json;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Rallyto.VenueImport;

/// <summary>
/// Places API (New) Text Search. Google Maps Platform does not serve Iranian accounts or IP addresses, so this runs
/// from a machine outside Iran with a non-Iranian billing account (design D15).
/// </summary>
public sealed class GooglePlacesSource(HttpClient http, string apiKey, TimeSpan delayBetweenRequests, int maxPages = 3) : IVenueSource
{
    private const string Endpoint = "https://places.googleapis.com/v1/places:searchText";
    private const string FieldMask = "places.id,places.displayName,places.formattedAddress,places.location,nextPageToken";

    public string Name => "google-places";

    public async IAsyncEnumerable<Candidate> SearchAsync(City city, string keyword, [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        string? pageToken = null;
        for (var page = 0; page < maxPages; page++)
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, Endpoint)
            {
                Content = JsonContent.Create(BuildRequest(city, keyword, pageToken)),
            };
            request.Headers.Add("X-Goog-Api-Key", apiKey);
            request.Headers.Add("X-Goog-FieldMask", FieldMask);

            using var response = await http.SendAsync(request, cancellationToken);
            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            if (!response.IsSuccessStatusCode)
                throw new HttpRequestException($"Places search failed for '{keyword} {city.Name}': {(int)response.StatusCode} {body}");

            var parsed = Parse(body);
            foreach (var candidate in ToCandidates(parsed, city, keyword))
                yield return candidate;

            pageToken = parsed.NextPageToken;
            if (string.IsNullOrEmpty(pageToken))
                yield break;
            await Task.Delay(delayBetweenRequests, cancellationToken);
        }
    }

    internal static object BuildRequest(City city, string keyword, string? pageToken) => new Dictionary<string, object?>
    {
        ["textQuery"] = $"{keyword} {city.Name}",
        ["languageCode"] = "fa",
        ["regionCode"] = "IR",
        ["pageSize"] = 20,
        ["pageToken"] = pageToken,
    }.Where(kv => kv.Value is not null).ToDictionary(kv => kv.Key, kv => kv.Value);

    internal static SearchResponse Parse(string json) =>
        JsonSerializer.Deserialize<SearchResponse>(json, JsonOptions) ?? new SearchResponse(null, null);

    internal static IEnumerable<Candidate> ToCandidates(SearchResponse response, City city, string keyword) =>
        (response.Places ?? [])
            .Where(p => !string.IsNullOrWhiteSpace(p.Id) && !string.IsNullOrWhiteSpace(p.DisplayName?.Text))
            .Select(p => new Candidate(p.Id!, p.DisplayName!.Text!, p.FormattedAddress, p.Location?.Latitude, p.Location?.Longitude, city.Id, keyword));

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    internal sealed record SearchResponse(List<Place>? Places, string? NextPageToken);

    internal sealed record Place(string? Id, LocalizedText? DisplayName, string? FormattedAddress, LatLng? Location);

    internal sealed record LocalizedText(string? Text, [property: JsonPropertyName("languageCode")] string? LanguageCode);

    internal sealed record LatLng(double Latitude, double Longitude);
}
