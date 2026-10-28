using System.Net;
using Rallyto.Host.IntegrationTests.Infrastructure;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Catalog;

/// <summary>spec sport-catalog.</summary>
public sealed class SportCatalogTests(RallytoHostFactory factory) : IntegrationTestBase(factory)
{
    [Fact]
    public async Task Four_sports_are_seeded_with_persian_names_and_readable_anonymously()
    {
        using var anonymous = Factory.CreateClient();

        var response = await anonymous.GetApiAsync<List<SportDto>>(CatalogApi.Sports);

        response.Status.Should().Be(HttpStatusCode.OK);
        response.Data!.Select(s => (s.Code, s.NameFa)).Should().Equal(
            ("tennis", "تنیس"), ("padel", "پدل"), ("badminton", "بدمینتون"), ("squash", "اسکواش"));
    }

    [Fact]
    public async Task Formats_and_capacity_follow_each_sport()
    {
        using var anonymous = Factory.CreateClient();

        var sports = (await anonymous.GetApiAsync<List<SportDto>>(CatalogApi.Sports)).Data!.ToDictionary(s => s.Code);

        sports["tennis"].Formats.Select(f => (f.Format, f.Capacity)).Should().Equal(("Singles", 2), ("Doubles", 4));
        sports["badminton"].Formats.Select(f => (f.Format, f.Capacity)).Should().Equal(("Singles", 2), ("Doubles", 4));
        sports["padel"].Formats.Select(f => (f.Format, f.Capacity)).Should().Equal(("Doubles", 4));
        sports["squash"].Formats.Select(f => (f.Format, f.Capacity)).Should().Equal(("Singles", 2));
    }

    [Fact]
    public async Task Five_ordered_tiers_with_descriptions_that_differ_by_sport()
    {
        using var anonymous = Factory.CreateClient();

        var sports = (await anonymous.GetApiAsync<List<SportDto>>(CatalogApi.Sports)).Data!.ToDictionary(s => s.Code);

        var badminton = sports["badminton"].Levels;
        badminton.Select(l => l.Tier).Should().Equal("Beginner", "LowerIntermediate", "Intermediate", "Advanced", "Professional");
        badminton.Select(l => l.Name).Should().Equal("مبتدی", "متوسط رو به پایین", "متوسط", "پیشرفته", "حرفه‌ای");
        badminton.Should().OnlyContain(l => !string.IsNullOrWhiteSpace(l.Description));
        badminton[2].Description.Should().NotBe(sports["tennis"].Levels[2].Description);
    }

    [Fact]
    public async Task Default_session_lengths()
    {
        using var anonymous = Factory.CreateClient();

        var sports = (await anonymous.GetApiAsync<List<SportDto>>(CatalogApi.Sports)).Data!.ToDictionary(s => s.Code, s => s.DefaultSessionMinutes);

        sports.Should().BeEquivalentTo(new Dictionary<string, int> { ["tennis"] = 90, ["padel"] = 90, ["badminton"] = 60, ["squash"] = 60 });
    }

    [Fact]
    public async Task Admin_adds_a_sport()
    {
        var admin = await Factory.AdminClientAsync();

        var created = await admin.PostApiAsync<SportDto>(CatalogApi.AdminSports, new
        {
            code = "table-tennis",
            nameFa = "تنیس روی میز",
            nameEn = "Table tennis",
            defaultSessionMinutes = 60,
            formats = new[] { new { format = "Singles", playersPerSide = 1 }, new { format = "Doubles", playersPerSide = 2 } },
            levels = Enumerable.Range(1, 5).Select(i => new { tier = i, description = $"توضیح سطح {i}" }).ToArray(),
            surfaces = Array.Empty<string>(),
        });
        var list = await Factory.CreateClient().GetApiAsync<List<SportDto>>(CatalogApi.Sports);

        created.Status.Should().Be(HttpStatusCode.Created);
        list.Data!.Should().Contain(s => s.Code == "table-tennis" && s.Formats.Count == 2);
    }

    [Fact]
    public async Task Deactivated_sport_disappears_for_players_but_not_for_admins()
    {
        var admin = await Factory.AdminClientAsync();
        var badminton = (await admin.GetApiAsync<List<SportDto>>(CatalogApi.AdminSports)).Data!.Single(s => s.Code == "badminton");

        var deactivate = await admin.PostApiAsync<Empty>($"{CatalogApi.AdminSports}/{badminton.Id}/deactivate");
        var playerList = await Factory.CreateClient().GetApiAsync<List<SportDto>>(CatalogApi.Sports);
        var adminList = await admin.GetApiAsync<List<SportDto>>(CatalogApi.AdminSports);

        deactivate.Status.Should().Be(HttpStatusCode.NoContent);
        playerList.Data!.Should().NotContain(s => s.Code == "badminton");
        adminList.Data!.Should().Contain(s => s.Code == "badminton" && !s.IsActive);
    }

    [Fact]
    public async Task Player_cannot_manage_sports()
    {
        var (player, _) = await Factory.SignedInClientAsync("09121234567");

        var response = await player.PostApiAsync<SportDto>(CatalogApi.AdminSports, new { code = "x" });

        response.Status.Should().Be(HttpStatusCode.Forbidden);
    }
}
