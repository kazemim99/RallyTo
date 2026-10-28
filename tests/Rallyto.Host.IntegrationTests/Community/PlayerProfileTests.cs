using System.Net;
using System.Net.Http.Headers;
using Rallyto.Host.IntegrationTests.Infrastructure;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Community;

/// <summary>spec player-profile.</summary>
public sealed class PlayerProfileTests(RallytoHostFactory factory) : IntegrationTestBase(factory)
{
    private const string Ali = "09121000001";
    private const string Sara = "09121000002";
    private const string Reza = "09121000003";

    [Fact]
    public async Task Player_endpoints_require_a_profile_first()
    {
        var (client, _) = await Factory.SignedInClientAsync(Ali);

        var response = await client.GetApiAsync<PlayerProfileView>($"{CommunityApi.Players}/{Guid.NewGuid()}");

        response.Status.Should().Be(HttpStatusCode.Forbidden);
        response.ErrorCode.Should().Be("PROFILE_REQUIRED");
    }

    [Fact]
    public async Task Successful_onboarding_creates_the_profile_and_completes_the_account()
    {
        var (client, _) = await Factory.SignedInClientAsync(Ali);
        var sports = await CommunityApi.SportIdsAsync(client);
        var tehran = await CatalogApi.CityIdAsync(client, "تهران", "تهران");

        var created = await client.PostApiAsync<MyProfileView>(CommunityApi.Profile,
            CommunityApi.NewProfile(tehran, [CommunityApi.SportProfile(sports["tennis"])], "علی", "Male", "1375/05/10"));

        created.Status.Should().Be(HttpStatusCode.Created);
        created.Data!.DisplayName.Should().Be("علی");
        created.Data.BirthDate.Should().Be("1375/05/10");
        created.Data.Sports.Should().ContainSingle(s => s.SportCode == "tennis" && s.Level == "Intermediate");
        await CommunityApi.EventuallyAsync(async () => (await client.GetApiAsync<MyAccount>(IdentityApi.Me)).Data!.ProfileCompleted);
        Factory.Advance(TimeSpan.FromSeconds(61));
        (await Factory.SignInAsync(Ali)).ProfileCompleted.Should().BeTrue();
    }

    [Fact]
    public async Task A_profile_without_a_sport_is_rejected()
    {
        var (client, _) = await Factory.SignedInClientAsync(Ali);
        var tehran = await CatalogApi.CityIdAsync(client, "تهران", "تهران");

        var response = await client.PostApiAsync<MyProfileView>(CommunityApi.Profile, CommunityApi.NewProfile(tehran, []));

        response.Status.Should().Be(HttpStatusCode.BadRequest);
    }

    [Theory]
    [InlineData("1387/08/02", HttpStatusCode.BadRequest)]
    [InlineData("1387/08/01", HttpStatusCode.Created)]
    public async Task Players_must_be_18_on_the_tehran_date(string birthDate, HttpStatusCode expected)
    {
        var (client, _) = await Factory.SignedInClientAsync(Ali);
        var sports = await CommunityApi.SportIdsAsync(client);
        var tehran = await CatalogApi.CityIdAsync(client, "تهران", "تهران");

        var response = await client.PostApiAsync<MyProfileView>(CommunityApi.Profile,
            CommunityApi.NewProfile(tehran, [CommunityApi.SportProfile(sports["tennis"])], birthDate: birthDate));

        response.Status.Should().Be(expected);
        if (expected == HttpStatusCode.BadRequest)
        {
            response.ErrorCode.Should().Be("UNDER_18");
            (await client.GetApiAsync<MyProfileView>(CommunityApi.MyProfile)).Status.Should().Be(HttpStatusCode.Forbidden);
        }
    }

    [Fact]
    public async Task Padel_with_a_singles_preference_is_rejected()
    {
        var (client, _) = await Factory.OnboardedPlayerAsync(Ali);
        var sports = await CommunityApi.SportIdsAsync(client);

        var response = await client.PutApiAsync<MyProfileView>($"{CommunityApi.Profile}/sports/{sports["padel"]}",
            CommunityApi.SportProfile(sports["padel"], formats: ["Singles"]));

        response.Status.Should().Be(HttpStatusCode.BadRequest);
        response.ErrorCode.Should().Be("FORMAT_NOT_ALLOWED");
    }

    [Fact]
    public async Task Padel_profile_with_doubles_is_saved()
    {
        var (client, _) = await Factory.OnboardedPlayerAsync(Ali);
        var sports = await CommunityApi.SportIdsAsync(client);

        var response = await client.PutApiAsync<MyProfileView>($"{CommunityApi.Profile}/sports/{sports["padel"]}",
            CommunityApi.SportProfile(sports["padel"], "Intermediate", "OneToThreeYears", ["Doubles"], ["FriendlyMatch"]));

        response.Status.Should().Be(HttpStatusCode.OK);
        response.Data!.Sports.Should().Contain(s => s.SportCode == "padel" && s.Formats.SequenceEqual(new[] { "Doubles" }));
    }

    [Fact]
    public async Task The_last_sport_profile_cannot_be_removed()
    {
        var (client, _) = await Factory.OnboardedPlayerAsync(Ali);
        var sports = await CommunityApi.SportIdsAsync(client);

        var response = await client.DeleteApiAsync<MyProfileView>($"{CommunityApi.Profile}/sports/{sports["tennis"]}");

        response.Status.Should().Be(HttpStatusCode.Conflict);
        response.ErrorCode.Should().Be("LAST_SPORT_PROFILE");
    }

    [Fact]
    public async Task At_most_five_home_clubs()
    {
        var (client, _) = await Factory.OnboardedPlayerAsync(Ali);
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        var venues = new List<Guid>();
        for (var i = 1; i <= 6; i++)
            venues.Add((await CatalogApi.CreateVenueAsync(admin, tehran, $"باشگاه شماره {i}")).Id);

        var five = await client.PutApiAsync<MyProfileView>($"{CommunityApi.Profile}/home-venues", new { venueIds = venues.Take(5) });
        var six = await client.PutApiAsync<MyProfileView>($"{CommunityApi.Profile}/home-venues", new { venueIds = venues });

        five.Status.Should().Be(HttpStatusCode.OK);
        five.Data!.HomeVenues.Should().HaveCount(5);
        six.Status.Should().Be(HttpStatusCode.BadRequest);
        six.ErrorCode.Should().Be("TOO_MANY_HOME_VENUES");
    }

    [Fact]
    public async Task Player_cannot_change_their_gender()
    {
        var (client, _) = await Factory.OnboardedPlayerAsync(Ali);
        var tehran = await CatalogApi.CityIdAsync(client, "تهران", "تهران");

        var response = await client.PutApiAsync<MyProfileView>(CommunityApi.Profile,
            new { displayName = "علی", gender = "Female", cityId = tehran, bio = (string?)null });

        response.Status.Should().Be(HttpStatusCode.BadRequest);
        response.ErrorCode.Should().Be("GENDER_LOCKED");
        (await client.GetApiAsync<MyProfileView>(CommunityApi.MyProfile)).Data!.Gender.Should().Be("Male");
    }

    [Fact]
    public async Task Admin_corrects_a_gender_with_a_reason()
    {
        var (client, userId) = await Factory.OnboardedPlayerAsync(Ali);
        var admin = await Factory.AdminClientAsync();

        var response = await admin.PostApiAsync<Empty>($"{CommunityApi.AdminPlayers}/{userId}/gender",
            new { gender = "Female", reason = "chosen by mistake at sign-up" });

        response.Status.Should().Be(HttpStatusCode.NoContent);
        (await client.GetApiAsync<MyProfileView>(CommunityApi.MyProfile)).Data!.Gender.Should().Be("Female");
    }

    [Fact]
    public async Task Others_see_an_age_range_and_no_birth_date()
    {
        var (_, aliId) = await Factory.OnboardedPlayerAsync(Ali, "علی", birthDate: "1370/01/01");
        var (viewer, _) = await Factory.OnboardedPlayerAsync(Reza, "رضا");

        var response = await viewer.GetAsync($"{CommunityApi.Players}/{aliId}");
        var body = await response.Content.ReadAsStringAsync();
        var view = await viewer.GetApiAsync<PlayerProfileView>($"{CommunityApi.Players}/{aliId}");

        view.Data!.AgeRange.Should().Be("35-44");
        body.Should().NotContain("1370").And.NotContain("birthDate");
        body.Should().NotContain("+98");
    }

    [Fact]
    public async Task Same_gender_visibility_hides_the_player_from_the_opposite_gender()
    {
        var (_, saraId) = await Factory.OnboardedPlayerAsync(Sara, "سارا", "Female", visibility: "SameGender");
        var (man, _) = await Factory.OnboardedPlayerAsync(Reza, "رضا", "Male");
        var (woman, _) = await Factory.OnboardedPlayerAsync("09121000004", "مریم", "Female");

        var fromMan = await man.GetApiAsync<PlayerProfileView>($"{CommunityApi.Players}/{saraId}");
        var fromWoman = await woman.GetApiAsync<PlayerProfileView>($"{CommunityApi.Players}/{saraId}");

        fromMan.Status.Should().Be(HttpStatusCode.NotFound);
        fromWoman.Status.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task A_restricted_player_cannot_see_the_opposite_gender_either()
    {
        var (sara, _) = await Factory.OnboardedPlayerAsync(Sara, "سارا", "Female", visibility: "SameGender");
        var (_, rezaId) = await Factory.OnboardedPlayerAsync(Reza, "رضا", "Male");

        var response = await sara.GetApiAsync<PlayerProfileView>($"{CommunityApi.Players}/{rezaId}");

        response.Status.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Suspended_player_profile_is_not_found()
    {
        var (_, aliId) = await Factory.OnboardedPlayerAsync(Ali);
        var (viewer, _) = await Factory.OnboardedPlayerAsync(Reza, "رضا");
        var admin = await Factory.AdminClientAsync();

        await admin.PostApiAsync<Empty>($"{IdentityApi.AdminUsers}/{aliId}/suspend",
            new { until = RallytoHostFactory.DefaultNow.UtcDateTime.AddDays(3), reason = "test" });

        await CommunityApi.EventuallyAsync(async () =>
            (await viewer.GetApiAsync<PlayerProfileView>($"{CommunityApi.Players}/{aliId}")).Status == HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Last_active_is_coarse()
    {
        var (_, aliId) = await Factory.OnboardedPlayerAsync(Ali);
        Factory.Advance(TimeSpan.FromDays(3));
        var (viewer, _) = await Factory.OnboardedPlayerAsync(Reza, "رضا");

        var view = await viewer.GetApiAsync<PlayerProfileView>($"{CommunityApi.Players}/{aliId}");

        view.Data!.LastActive.Should().Be("ThisWeek");
    }

    [Fact]
    public async Task Oversized_photo_is_rejected_and_a_small_one_is_served()
    {
        var (client, _) = await Factory.OnboardedPlayerAsync(Ali);

        using var big = new MultipartFormDataContent { { new ByteArrayContent(new byte[8 * 1024 * 1024]) { Headers = { ContentType = new MediaTypeHeaderValue("image/jpeg") } }, "file", "big.jpg" } };
        var tooBig = await client.PutAsync($"{CommunityApi.Profile}/photo", big);
        using var small = new MultipartFormDataContent { { new ByteArrayContent(TinyPng) { Headers = { ContentType = new MediaTypeHeaderValue("image/png") } }, "file", "me.png" } };
        var ok = await client.PutAsync($"{CommunityApi.Profile}/photo", small);
        var me = (await client.GetApiAsync<MyProfileView>(CommunityApi.MyProfile)).Data!;
        var photo = await Factory.CreateClient().GetAsync(me.PhotoUrl);

        tooBig.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        ok.StatusCode.Should().Be(HttpStatusCode.OK);
        me.PhotoUrl.Should().MatchRegex("^/media/avatars/[0-9a-f]{32}\\.jpg$");
        photo.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Deleted_account_is_anonymised()
    {
        var (ali, aliId) = await Factory.OnboardedPlayerAsync(Ali);
        Factory.Advance(TimeSpan.FromSeconds(61));
        await ali.PostApiAsync<SendCodeResponse>(IdentityApi.DeletionCode);
        await ali.PostApiAsync<Empty>(IdentityApi.Deletion, new { code = Factory.Sms.LastCodeFor(Ali) });
        var admin = await Factory.AdminClientAsync();

        await CommunityApi.EventuallyAsync(async () =>
        {
            var view = await admin.GetApiAsync<MyProfileView>($"{CommunityApi.AdminPlayers}/{aliId}");
            return view.Data?.DisplayName == "کاربر حذف‌شده" && view.Data.PhotoUrl is null && view.Data.Bio is null;
        });
    }

    // 1x1 transparent PNG
    private static readonly byte[] TinyPng = Convert.FromBase64String(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==");
}
