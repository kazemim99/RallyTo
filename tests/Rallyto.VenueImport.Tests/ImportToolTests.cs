using System.Runtime.CompilerServices;
using System.Text.Json;

namespace Rallyto.VenueImport.Tests;

public sealed class ImportToolTests
{
    private static readonly City Shiraz = new(152, 145, "شیراز", "فارس");

    [Fact]
    public void Keywords_cover_every_seeded_sport()
    {
        SportKeywords.BySport.Keys.Should().BeEquivalentTo("tennis", "padel", "badminton", "squash");
        SportKeywords.All.Should().Contain(["باشگاه تنیس", "پدل", "سالن بدمینتون", "اسکواش"]);
    }

    [Fact]
    public void Search_request_appends_the_city_and_asks_for_persian_results_in_iran()
    {
        var body = JsonSerializer.Serialize(GooglePlacesSource.BuildRequest(Shiraz, "باشگاه تنیس", null));

        using var json = JsonDocument.Parse(body);
        json.RootElement.GetProperty("textQuery").GetString().Should().Be("باشگاه تنیس شیراز");
        json.RootElement.GetProperty("languageCode").GetString().Should().Be("fa");
        json.RootElement.GetProperty("regionCode").GetString().Should().Be("IR");
        json.RootElement.TryGetProperty("pageToken", out _).Should().BeFalse();
    }

    [Fact]
    public void Places_response_maps_to_candidates_and_skips_incomplete_places()
    {
        const string response = """
            {
              "places": [
                { "id": "ChIJ1", "displayName": { "text": "باشگاه تنیس ارم", "languageCode": "fa" },
                  "formattedAddress": "شیراز، خیابان ارم", "location": { "latitude": 29.63, "longitude": 52.52 } },
                { "id": "ChIJ2", "displayName": { "text": "" } },
                { "displayName": { "text": "بدون شناسه" } }
              ],
              "nextPageToken": "next"
            }
            """;

        var parsed = GooglePlacesSource.Parse(response);
        var candidates = GooglePlacesSource.ToCandidates(parsed, Shiraz, "باشگاه تنیس").ToList();

        parsed.NextPageToken.Should().Be("next");
        candidates.Should().ContainSingle();
        candidates[0].Should().Be(new Candidate("ChIJ1", "باشگاه تنیس ارم", "شیراز، خیابان ارم", 29.63, 52.52, 152, "باشگاه تنیس"));
    }

    [Fact]
    public async Task The_same_place_found_by_several_keywords_is_uploaded_once()
    {
        var sink = new FakeSink([Shiraz]);
        var runner = new ImportRunner(new FakeSource(), sink, TextWriter.Null, delayMs: 0, batchSize: 2);

        var candidates = await runner.CollectAsync(null, CancellationToken.None);
        await runner.UploadAsync(candidates, CancellationToken.None);

        candidates.Select(c => c.PlaceId).Should().OnlyHaveUniqueItems();
        sink.Uploaded.Should().HaveCount(candidates.Count);
        sink.Batches.Should().OnlyContain(b => b <= 2);
    }

    private sealed class FakeSource : IVenueSource
    {
        public string Name => "fake";

        public async IAsyncEnumerable<Candidate> SearchAsync(City city, string keyword, [EnumeratorCancellation] CancellationToken cancellationToken)
        {
            await Task.Yield();
            yield return new Candidate("shared-place", "مجموعه ورزشی", null, null, null, city.Id, keyword);
            yield return new Candidate($"only-{keyword}", keyword, null, null, null, city.Id, keyword);
        }
    }

    private sealed class FakeSink(IReadOnlyList<City> cities) : ICandidateSink
    {
        public List<Candidate> Uploaded { get; } = [];
        public List<int> Batches { get; } = [];

        public Task<IReadOnlyList<City>> CitiesAsync(string? provinceFilter, CancellationToken cancellationToken) => Task.FromResult(cities);

        public Task<RallytoApi.ImportResult> ImportAsync(IReadOnlyList<Candidate> batch, CancellationToken cancellationToken)
        {
            Uploaded.AddRange(batch);
            Batches.Add(batch.Count);
            return Task.FromResult(new RallytoApi.ImportResult(batch.Count, 0, 0));
        }
    }
}
