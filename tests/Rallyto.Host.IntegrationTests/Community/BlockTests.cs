using System.Net;
using Rallyto.Host.IntegrationTests.Infrastructure;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Community;

/// <summary>spec trust-safety › Block a player (search, posts and chat effects are tested with those slices).</summary>
public sealed class BlockTests(RallytoHostFactory factory) : IntegrationTestBase(factory)
{
    [Fact]
    public async Task Blocking_hides_both_profiles_from_each_other_silently()
    {
        var (a, aId) = await Factory.OnboardedPlayerAsync("09122000001", "الف");
        var (b, bId) = await Factory.OnboardedPlayerAsync("09122000002", "بهار");

        var block = await a.PostApiAsync<Empty>($"{CommunityApi.Blocks}/{bId}");
        var bSeesA = await b.GetApiAsync<PlayerProfileView>($"{CommunityApi.Players}/{aId}");
        var aSeesB = await a.GetApiAsync<PlayerProfileView>($"{CommunityApi.Players}/{bId}");
        var missing = await b.GetApiAsync<PlayerProfileView>($"{CommunityApi.Players}/{Guid.NewGuid()}");

        block.Status.Should().Be(HttpStatusCode.NoContent);
        bSeesA.Status.Should().Be(HttpStatusCode.NotFound);
        aSeesB.Status.Should().Be(HttpStatusCode.NotFound);
        bSeesA.ErrorCode.Should().Be(missing.ErrorCode);
        bSeesA.Error!.Message.Should().Be(missing.Error!.Message);
    }

    [Fact]
    public async Task Unblocking_restores_visibility()
    {
        var (a, _) = await Factory.OnboardedPlayerAsync("09122000001", "الف");
        var (b, bId) = await Factory.OnboardedPlayerAsync("09122000002", "بهار");
        await a.PostApiAsync<Empty>($"{CommunityApi.Blocks}/{bId}");

        var unblock = await a.DeleteApiAsync<Empty>($"{CommunityApi.Blocks}/{bId}");
        var view = await a.GetApiAsync<PlayerProfileView>($"{CommunityApi.Players}/{bId}");

        unblock.Status.Should().Be(HttpStatusCode.NoContent);
        view.Status.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task The_blocker_sees_whom_they_blocked()
    {
        var (a, _) = await Factory.OnboardedPlayerAsync("09122000001", "الف");
        var (_, bId) = await Factory.OnboardedPlayerAsync("09122000002", "بهار");
        await a.PostApiAsync<Empty>($"{CommunityApi.Blocks}/{bId}");

        var list = await a.GetApiAsync<List<BlockedPlayer>>(CommunityApi.Blocks);

        list.Data!.Should().ContainSingle(x => x.UserId == bId && x.DisplayName == "بهار");
    }

    [Fact]
    public async Task Players_cannot_block_themselves()
    {
        var (a, aId) = await Factory.OnboardedPlayerAsync("09122000001", "الف");

        var response = await a.PostApiAsync<Empty>($"{CommunityApi.Blocks}/{aId}");

        response.Status.Should().Be(HttpStatusCode.BadRequest);
    }
}
