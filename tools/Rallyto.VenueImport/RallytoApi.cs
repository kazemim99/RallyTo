using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace Rallyto.VenueImport;

/// <summary>The few Rallyto API calls the tool needs, with an admin access token.</summary>
public sealed class RallytoApi
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private readonly HttpClient _http;

    public RallytoApi(HttpClient http, string baseUrl, string adminAccessToken)
    {
        _http = http;
        _http.BaseAddress = new Uri(baseUrl.TrimEnd('/') + "/");
        _http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", adminAccessToken);
    }

    public async Task<IReadOnlyList<City>> CitiesAsync(string? provinceFilter, CancellationToken cancellationToken)
    {
        var provinces = await GetDataAsync<List<ProvinceRow>>("api/v1/provinces", cancellationToken);
        var result = new List<City>();
        foreach (var province in provinces.Where(p => provinceFilter is null || p.Name == provinceFilter))
        {
            var cities = await GetDataAsync<List<CityRow>>($"api/v1/provinces/{province.Id}/cities", cancellationToken);
            result.AddRange(cities.Select(c => new City(c.Id, province.Id, c.Name, province.Name)));
        }

        return result;
    }

    public async Task<ImportResult> ImportAsync(IReadOnlyList<Candidate> batch, CancellationToken cancellationToken)
    {
        using var response = await _http.PostAsJsonAsync("api/v1/admin/venue-candidates/import", new { items = batch }, Json, cancellationToken);
        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
            throw new HttpRequestException($"Import failed: {(int)response.StatusCode} {body}");
        return Unwrap<ImportResult>(body);
    }

    private async Task<T> GetDataAsync<T>(string path, CancellationToken cancellationToken)
    {
        var body = await _http.GetStringAsync(path, cancellationToken);
        return Unwrap<T>(body);
    }

    internal static T Unwrap<T>(string envelope)
    {
        using var document = JsonDocument.Parse(envelope);
        return document.RootElement.GetProperty("data").Deserialize<T>(Json)
               ?? throw new InvalidOperationException("Empty data in API response");
    }

    public sealed record ImportResult(int Created, int SkippedInCatalog, int SkippedKnown);

    private sealed record ProvinceRow(int Id, string Name);

    private sealed record CityRow(int Id, int ProvinceId, string Name);
}
