using System.Net;
using Rallyto.Host.IntegrationTests.Infrastructure;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Catalog;

/// <summary>
/// The public club directory the landing site is built from (spec venue-catalog, owner decisions 2026-11-01): anyone may
/// read it without signing in; it lists only active clubs, with what a visitor needs to find and reach one — but no
/// internal reference.
/// </summary>
public sealed class PublicVenueDirectoryTests(RallytoHostFactory factory) : IntegrationTestBase(factory)
{
    [Fact]
    public async Task Anyone_can_read_the_active_clubs_with_their_sports_province_and_city()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        await CatalogApi.CreateVenueAsync(admin, tehran, "باشگاه انقلاب", CatalogApi.TennisOutdoor(), CatalogApi.Sport("padel"));
        using var anonymous = Factory.CreateClient();

        var response = await anonymous.GetApiAsync<List<PublicVenueDto>>(CatalogApi.PublicVenues);

        response.Status.Should().Be(HttpStatusCode.OK);
        var club = response.Data!.Single(v => v.Name == "باشگاه انقلاب");
        club.ProvinceName.Should().Be("تهران");
        club.CityName.Should().Be("تهران");
        club.CityId.Should().Be(tehran);
        club.Sports.Should().BeEquivalentTo(["tennis", "padel"]);
    }

    [Fact]
    public async Task A_hidden_club_is_not_listed()
    {
        var admin = await Factory.AdminClientAsync();
        var shiraz = await CatalogApi.CityIdAsync(admin, "فارس", "شیراز");
        var hidden = await CatalogApi.CreateVenueAsync(admin, shiraz, "باشگاه پنهان");
        await CatalogApi.CreateVenueAsync(admin, shiraz, "باشگاه پیدا");
        await admin.PostApiAsync<Empty>($"{CatalogApi.AdminVenues}/{hidden.Id}/hide");

        var list = (await Factory.CreateClient().GetApiAsync<List<PublicVenueDto>>(CatalogApi.PublicVenues)).Data!;

        list.Select(v => v.Name).Should().Contain("باشگاه پیدا").And.NotContain("باشگاه پنهان");
    }

    [Fact]
    public async Task Lists_how_to_find_and_reach_a_club()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        var created = await admin.PostApiAsync<VenueDto>(CatalogApi.AdminVenues, new
        {
            cityId = tehran,
            name = "باشگاه با اطلاعات کامل",
            address = "تهران، خیابان ولیعصر، پلاک ۱۰",
            phone = "02122638043",
            latitude = 35.7730808,
            longitude = 51.4420388,
            sports = new[] { CatalogApi.TennisOutdoor() },
            allowSimilar = true,
        });
        await admin.PutApiAsync<VenueDto>($"{CatalogApi.AdminVenues}/{created.Data!.Id}/profile", new
        {
            description = "۲ زمین خاک رس",
            website = "https://example.ir",
            instagram = "https://www.instagram.com/example",
            telegram = "https://t.me/example",
            workingHours = "همه‌روزه ۷ تا ۲۴",
        });

        var list = (await Factory.CreateClient().GetApiAsync<List<PublicVenueDto>>(CatalogApi.PublicVenues)).Data!;

        var club = list.Single(v => v.Name == "باشگاه با اطلاعات کامل");
        club.Address.Should().Be("تهران، خیابان ولیعصر، پلاک ۱۰");
        club.Phone.Should().Be("02122638043");
        club.Latitude.Should().Be(35.7730808);
        club.Longitude.Should().Be(51.4420388);
        club.WorkingHours.Should().Be("همه‌روزه ۷ تا ۲۴");
        club.Website.Should().Be("https://example.ir");
        club.Instagram.Should().Be("https://www.instagram.com/example");
        club.Telegram.Should().Be("https://t.me/example");
        club.Description.Should().Be("۲ زمین خاک رس");
    }

    [Fact]
    public async Task A_club_without_a_phone_or_position_lists_none()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        await CatalogApi.CreateVenueAsync(admin, tehran, "باشگاه بی‌تلفن");

        var list = (await Factory.CreateClient().GetApiAsync<List<PublicVenueDto>>(CatalogApi.PublicVenues)).Data!;

        var club = list.Single(v => v.Name == "باشگاه بی‌تلفن");
        club.Phone.Should().BeNull();
        club.Latitude.Should().BeNull();
        club.Longitude.Should().BeNull();
    }

    [Fact]
    public async Task Never_exposes_an_internal_reference()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        await CatalogApi.CreateVenueAsync(admin, tehran, "باشگاه با نشانی");

        var json = await Factory.CreateClient().GetStringAsync(CatalogApi.PublicVenues);

        json.Should().Contain("باشگاه با نشانی");
        json.Should().NotContainAny("sourceRef", "sourceUrl", "googleRating", "googleReviewCount", "\"status\"", "\"id\"");
    }
}
