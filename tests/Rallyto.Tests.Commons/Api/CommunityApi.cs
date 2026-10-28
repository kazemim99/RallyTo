namespace Rallyto.Tests.Commons.Api;

public sealed record SportProfileView(
    Guid SportId,
    string SportCode,
    string Level,
    string LevelName,
    string? LevelDescription,
    string Experience,
    string[] Formats,
    string[] Goals);

public sealed record NamedRef(Guid Id, string Name);

public sealed record CityRef(int Id, string Name);

public sealed record PlayerProfileView(
    Guid UserId,
    string DisplayName,
    string? PhotoUrl,
    string Gender,
    string AgeRange,
    CityRef City,
    string? Bio,
    IReadOnlyList<SportProfileView> Sports,
    IReadOnlyList<NamedRef> HomeVenues,
    string MemberSince,
    string LastActive);

public sealed record MyProfileView(
    Guid UserId,
    string DisplayName,
    string? PhotoUrl,
    string Gender,
    string BirthDate,
    string AgeRange,
    CityRef City,
    string? Bio,
    string Visibility,
    IReadOnlyList<SportProfileView> Sports,
    IReadOnlyList<NamedRef> HomeVenues);

public sealed record BlockedPlayer(Guid UserId, string DisplayName, DateTime BlockedAt);

public static class CommunityApi
{
    public const string Profile = "/api/v1/profile";
    public const string MyProfile = "/api/v1/profile/me";
    public const string Players = "/api/v1/players";
    public const string Blocks = "/api/v1/blocks";
    public const string AdminPlayers = "/api/v1/admin/players";

    public static object SportProfile(Guid sportId, string level = "Intermediate", string experience = "OneToThreeYears",
        string[]? formats = null, string[]? goals = null) => new
    {
        sportId,
        level,
        experience,
        formats = formats ?? ["Singles"],
        goals = goals ?? ["FriendlyMatch"],
    };

    public static object NewProfile(int cityId, object[] sports, string displayName = "علی", string gender = "Male", string birthDate = "1375/05/10", string? bio = null) =>
        new { displayName, gender, birthDate, cityId, bio, sports };

    public static async Task<Dictionary<string, Guid>> SportIdsAsync(HttpClient client) =>
        (await client.GetApiAsync<List<SportDto>>(CatalogApi.Sports)).Data!.ToDictionary(s => s.Code, s => s.Id);

    /// <summary>Signs a new player in and creates a profile; returns the client and the player's id.</summary>
    public static async Task<(HttpClient Client, Guid UserId)> OnboardedPlayerAsync(
        this RallytoHostFactory factory, string localMobile, string displayName = "بازیکن", string gender = "Male",
        string level = "Intermediate", string sport = "tennis", string visibility = "Everyone", string birthDate = "1375/05/10")
    {
        var (client, _) = await factory.SignedInClientAsync(localMobile);
        var sports = await SportIdsAsync(client);
        var tehran = await CatalogApi.CityIdAsync(client, "تهران", "تهران");
        var formats = sport == "padel" ? new[] { "Doubles" } : sport == "squash" ? ["Singles"] : new[] { "Singles", "Doubles" };
        var created = await client.PostApiAsync<MyProfileView>(Profile,
            NewProfile(tehran, [SportProfile(sports[sport], level, formats: formats)], displayName, gender, birthDate));
        if (created.Data is null)
            throw new InvalidOperationException($"create profile failed: {created.ErrorCode} {created.Error?.Message}");
        if (visibility != "Everyone")
            await client.PutApiAsync<Empty>($"{Profile}/visibility", new { visibility });
        return (client, created.Data.UserId);
    }

    /// <summary>Retries an assertion while asynchronous integration events are delivered.</summary>
    public static async Task EventuallyAsync(Func<Task<bool>> condition, int timeoutMs = 5000)
    {
        var deadline = DateTime.UtcNow.AddMilliseconds(timeoutMs);
        while (DateTime.UtcNow < deadline)
        {
            if (await condition())
                return;
            await Task.Delay(100);
        }

        throw new TimeoutException("Condition was not met in time.");
    }
}
