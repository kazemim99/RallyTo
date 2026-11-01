using System.Net;
using Rallyto.Host.IntegrationTests.Infrastructure;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Catalog;

/// <summary>
/// The public club directory the landing site is built from (spec venue-catalog, owner decision 2026-11-01): anyone may
/// read it without signing in; it lists only active clubs, and only their name, sports, province and city — never an
/// address, a phone number or coordinates.
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
    public async Task Never_exposes_an_address_a_phone_or_coordinates()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        await CatalogApi.CreateVenueAsync(admin, tehran, "باشگاه با نشانی");

        var json = await Factory.CreateClient().GetStringAsync(CatalogApi.PublicVenues);

        json.Should().Contain("باشگاه با نشانی");
        json.Should().NotContainAny("address", "phone", "latitude", "longitude", "خیابان ولیعصر", "googlePlaceId", "\"id\"");
    }
}
