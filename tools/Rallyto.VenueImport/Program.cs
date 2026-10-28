using System.Text.Json;
using Rallyto.VenueImport;

// Usage (from a machine outside Iran; see README.md):
//   dotnet run --project tools/Rallyto.VenueImport -- --api https://api.example --token <admin access token>
//       --google-key <key> [--province تهران] [--dry-run candidates.json] [--delay-ms 300]
var options = ImportOptions.Parse(args);
if (options is null)
{
    Console.Error.WriteLine(ImportOptions.Usage);
    return 2;
}

using var cts = new CancellationTokenSource();
Console.CancelKeyPress += (_, e) => { e.Cancel = true; cts.Cancel(); };

using var apiHttp = new HttpClient { Timeout = TimeSpan.FromSeconds(60) };
using var googleHttp = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
var api = new RallytoApi(apiHttp, options.ApiBaseUrl, options.AdminToken);
IVenueSource source = new GooglePlacesSource(googleHttp, options.GoogleApiKey, TimeSpan.FromMilliseconds(options.DelayMs));

var runner = new ImportRunner(source, api, Console.Out, options.DelayMs);
var candidates = await runner.CollectAsync(options.Province, cts.Token);

if (options.DryRunFile is { } file)
{
    await File.WriteAllTextAsync(file, JsonSerializer.Serialize(candidates, new JsonSerializerOptions { WriteIndented = true, Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping }), cts.Token);
    Console.WriteLine($"Dry run: {candidates.Count} candidates written to {file}");
    return 0;
}

var totals = await runner.UploadAsync(candidates, cts.Token);
Console.WriteLine($"Done: {totals.Created} created, {totals.SkippedInCatalog} already in the catalog, {totals.SkippedKnown} already imported.");
return 0;

internal sealed record ImportOptions(string ApiBaseUrl, string AdminToken, string GoogleApiKey, string? Province, string? DryRunFile, int DelayMs)
{
    public const string Usage =
        "Usage: --api <base url> --token <admin access token> --google-key <key> [--province <name>] [--dry-run <file.json>] [--delay-ms 300]";

    public static ImportOptions? Parse(string[] args)
    {
        var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        for (var i = 0; i + 1 < args.Length; i += 2)
            values[args[i].TrimStart('-')] = args[i + 1];
        if (!values.TryGetValue("api", out var api) || !values.TryGetValue("token", out var token) || !values.TryGetValue("google-key", out var key))
            return null;
        return new ImportOptions(api, token, key, values.GetValueOrDefault("province"), values.GetValueOrDefault("dry-run"),
            int.TryParse(values.GetValueOrDefault("delay-ms"), out var delay) ? delay : 300);
    }
}
