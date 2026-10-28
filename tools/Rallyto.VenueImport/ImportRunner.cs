namespace Rallyto.VenueImport;

public interface ICandidateSink
{
    Task<IReadOnlyList<City>> CitiesAsync(string? provinceFilter, CancellationToken cancellationToken);

    Task<RallytoApi.ImportResult> ImportAsync(IReadOnlyList<Candidate> batch, CancellationToken cancellationToken);
}

/// <summary>Searches every city × keyword, removes duplicates by place id, and uploads in batches.</summary>
public sealed class ImportRunner(IVenueSource source, ICandidateSink sink, TextWriter log, int delayMs, int batchSize = 200)
{
    public ImportRunner(IVenueSource source, RallytoApi api, TextWriter log, int delayMs)
        : this(source, new ApiSink(api), log, delayMs)
    {
    }

    public async Task<IReadOnlyList<Candidate>> CollectAsync(string? provinceFilter, CancellationToken cancellationToken)
    {
        var cities = await sink.CitiesAsync(provinceFilter, cancellationToken);
        var byPlace = new Dictionary<string, Candidate>(StringComparer.Ordinal);
        foreach (var city in cities)
        {
            foreach (var keyword in SportKeywords.All)
            {
                var found = 0;
                await foreach (var candidate in source.SearchAsync(city, keyword, cancellationToken))
                {
                    // The same club often answers several keywords; keep the first sighting.
                    if (byPlace.TryAdd(candidate.PlaceId, candidate))
                        found++;
                }

                log.WriteLine($"{city.ProvinceName} / {city.Name} / {keyword}: {found} new");
                if (delayMs > 0)
                    await Task.Delay(delayMs, cancellationToken);
            }
        }

        return byPlace.Values.ToList();
    }

    public async Task<RallytoApi.ImportResult> UploadAsync(IReadOnlyList<Candidate> candidates, CancellationToken cancellationToken)
    {
        int created = 0, inCatalog = 0, known = 0;
        foreach (var batch in candidates.Chunk(batchSize))
        {
            var result = await sink.ImportAsync(batch, cancellationToken);
            created += result.Created;
            inCatalog += result.SkippedInCatalog;
            known += result.SkippedKnown;
        }

        return new RallytoApi.ImportResult(created, inCatalog, known);
    }

    private sealed class ApiSink(RallytoApi api) : ICandidateSink
    {
        public Task<IReadOnlyList<City>> CitiesAsync(string? provinceFilter, CancellationToken cancellationToken) => api.CitiesAsync(provinceFilter, cancellationToken);

        public Task<RallytoApi.ImportResult> ImportAsync(IReadOnlyList<Candidate> batch, CancellationToken cancellationToken) => api.ImportAsync(batch, cancellationToken);
    }
}
