using System.Net;
using Rallyto.Host.IntegrationTests.Infrastructure;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Community;

/// <summary>Shared arrangement for play-post and match tests: two Tehran clubs offering all sports and onboarded players.</summary>
public abstract class MatchTestBase(RallytoHostFactory factory) : IntegrationTestBase(factory)
{
    private int _phone = 7000000;

    protected Guid Esteghlal { get; private set; }
    protected Guid TennisOnly { get; private set; }
    protected Dictionary<string, Guid> Sports { get; private set; } = [];

    public override async Task InitializeAsync()
    {
        await base.InitializeAsync();
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        Esteghlal = (await CatalogApi.CreateVenueAsync(admin, tehran, "مجموعه تنیس استقلال",
            CatalogApi.TennisOutdoor(14), CatalogApi.Sport("padel"), CatalogApi.Sport("badminton"), CatalogApi.Sport("squash"))).Id;
        TennisOnly = (await CatalogApi.CreateVenueAsync(admin, tehran, "باشگاه فقط تنیس", CatalogApi.TennisOutdoor(4))).Id;
        Sports = await CommunityApi.SportIdsAsync(admin);
    }

    protected string LastPhone => $"0912{_phone:0000000}";

    /// <summary>An onboarded player who plays every sport at the given tennis level (other sports Intermediate).</summary>
    protected async Task<(HttpClient Client, Guid Id)> PlayerAsync(string name, string level = "Intermediate", string gender = "Male", string visibility = "Everyone")
    {
        _phone++;
        var (client, id) = await Factory.OnboardedPlayerAsync(LastPhone, name, gender, level, visibility: visibility);
        foreach (var (code, formats) in new[] { ("padel", new[] { "Doubles" }), ("badminton", new[] { "Singles", "Doubles" }), ("squash", new[] { "Singles" }) })
            await client.PutApiAsync<MyProfileView>($"{CommunityApi.Profile}/sports/{Sports[code]}", CommunityApi.SportProfile(Sports[code], formats: formats));
        return (client, id);
    }

    protected async Task<MatchView> PostAsync(HttpClient host, object body)
    {
        var response = await host.PostApiAsync<MatchView>(MatchApi.Posts, body);
        response.Status.Should().Be(HttpStatusCode.Created, response.ErrorCode);
        return response.Data!;
    }

    protected static async Task<ApiResponse<MatchView>> JoinAsync(HttpClient player, Guid matchId, string? message = null) =>
        await player.PostApiAsync<MatchView>($"{MatchApi.Matches}/{matchId}/join", new { message });

    protected static async Task<ApiResponse<MatchView>> AcceptAsync(HttpClient host, Guid matchId, Guid playerId) =>
        await host.PostApiAsync<MatchView>($"{MatchApi.Matches}/{matchId}/requests/{playerId}/accept");

    protected static async Task<MatchView> GetAsync(HttpClient client, Guid matchId) =>
        (await client.GetApiAsync<MatchView>($"{MatchApi.Matches}/{matchId}")).Data!;
}
