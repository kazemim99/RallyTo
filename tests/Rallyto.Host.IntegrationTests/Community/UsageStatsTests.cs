using System.Net;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Community;

/// <summary>The admin usage dashboard (tasks 10.9).</summary>
public sealed class UsageStatsTests(RallytoHostFactory factory) : MatchTestBase(factory)
{
    private sealed record Stats(string From, string To, int SignUps, int ActivePlayers, int Posts, int Invitations, int ConfirmedMatches, int CompletedMatches,
        int ResolvedMatches, double? CompletionRate, int Reports, int OpenReports);

    [Fact]
    public async Task Counts_sign_ups_posts_matches_and_reports_of_the_period()
    {
        var (host, _) = await PlayerAsync("میزبان");
        var (guest, guestId) = await PlayerAsync("مهمان");
        var post = await PostAsync(host, MatchApi.Post(Sports["tennis"], Esteghlal));
        await JoinAsync(guest, post.Id);
        await AcceptAsync(host, post.Id, guestId);
        await PostAsync(host, MatchApi.Post(Sports["padel"], Esteghlal, "Doubles", startTime: "21:00"));
        await SafetyApi.ReportAsync(guest, "Post", post.Id.ToString(), "Spam");
        var admin = await Factory.AdminClientAsync();

        var stats = (await admin.GetApiAsync<Stats>("/api/v1/admin/stats?from=1405/08/01&to=1405/08/02")).Data!;

        stats.Should().BeEquivalentTo(new { SignUps = 2, ActivePlayers = 2, Posts = 2, Invitations = 0, ConfirmedMatches = 1, Reports = 1, OpenReports = 1, CompletionRate = (double?)null });
    }

    [Fact]
    public async Task Defaults_to_the_last_30_days_and_is_admin_only()
    {
        var (player, _) = await PlayerAsync("علی");

        var stats = (await (await Factory.AdminClientAsync()).GetApiAsync<Stats>("/api/v1/admin/stats")).Data!;

        stats.To.Should().Be("1405/08/01");
        stats.From.Should().Be("1405/07/02");
        (await player.GetApiAsync<Stats>("/api/v1/admin/stats")).Status.Should().Be(HttpStatusCode.Forbidden);
    }
}
