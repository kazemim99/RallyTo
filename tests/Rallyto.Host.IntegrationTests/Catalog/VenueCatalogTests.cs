using System.Net;
using Rallyto.Host.IntegrationTests.Infrastructure;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Catalog;

/// <summary>spec venue-catalog.</summary>
public sealed class VenueCatalogTests(RallytoHostFactory factory) : IntegrationTestBase(factory)
{
    private const string Player = "09121234567";

    [Fact]
    public async Task All_31_provinces_are_seeded_with_persian_names()
    {
        var (player, _) = await Factory.SignedInClientAsync(Player);

        var provinces = (await player.GetApiAsync<List<ProvinceDto>>(CatalogApi.Provinces)).Data!;

        provinces.Should().HaveCount(31);
        provinces.Select(p => p.Name).Should().Contain(["تهران", "اصفهان", "فارس", "کرمان", "کردستان"]);
        provinces.Should().NotContain(p => p.Name.Contains('ك') || p.Name.Contains('ي'));
    }

    [Fact]
    public async Task Cities_with_venues_are_listed_first()
    {
        var (player, _) = await Factory.SignedInClientAsync(Player);
        var admin = await Factory.AdminClientAsync();
        var kashan = await CatalogApi.CityIdAsync(player, "اصفهان", "کاشان");
        await CatalogApi.CreateVenueAsync(admin, kashan, "باشگاه تنیس کاشان");
        var isfahan = (await player.GetApiAsync<List<ProvinceDto>>(CatalogApi.Provinces)).Data!.Single(p => p.Name == "اصفهان");

        var cities = (await player.GetApiAsync<List<CityDto>>($"{CatalogApi.Provinces}/{isfahan.Id}/cities")).Data!;

        cities.First().Name.Should().Be("کاشان");
        cities.First().ActiveVenueCount.Should().Be(1);
        cities.Skip(1).Select(c => c.Name).Should().BeInAscendingOrder(StringComparer.Create(new System.Globalization.CultureInfo("fa-IR"), false));
    }

    [Fact]
    public async Task Import_creates_pending_candidates_that_players_cannot_see()
    {
        var admin = await Factory.AdminClientAsync();
        var shiraz = await CatalogApi.CityIdAsync(admin, "فارس", "شیراز");

        var result = await admin.PostApiAsync<ImportResultDto>($"{CatalogApi.AdminCandidates}/import", new { items = Candidates(shiraz, 12) });
        var (player, _) = await Factory.SignedInClientAsync(Player);
        var visible = await player.GetApiAsync<List<VenueDto>>($"{CatalogApi.Venues}?cityId={shiraz}");
        var pending = await admin.GetApiAsync<PagedResult<VenueCandidateDto>>($"{CatalogApi.AdminCandidates}?cityId={shiraz}&status=Pending");

        result.Data!.Created.Should().Be(12);
        visible.Data!.Should().BeEmpty();
        pending.Data!.TotalCount.Should().Be(12);
    }

    [Fact]
    public async Task Re_running_the_import_creates_no_duplicates_and_rejected_places_stay_away()
    {
        var admin = await Factory.AdminClientAsync();
        var shiraz = await CatalogApi.CityIdAsync(admin, "فارس", "شیراز");
        await admin.PostApiAsync<ImportResultDto>($"{CatalogApi.AdminCandidates}/import", new { items = Candidates(shiraz, 3) });
        var first = (await admin.GetApiAsync<PagedResult<VenueCandidateDto>>($"{CatalogApi.AdminCandidates}?cityId={shiraz}")).Data!.Items[0];
        await admin.PostApiAsync<Empty>($"{CatalogApi.AdminCandidates}/{first.Id}/reject", new { reason = "not a club" });

        var again = await admin.PostApiAsync<ImportResultDto>($"{CatalogApi.AdminCandidates}/import", new { items = Candidates(shiraz, 3) });
        var pending = await admin.GetApiAsync<PagedResult<VenueCandidateDto>>($"{CatalogApi.AdminCandidates}?cityId={shiraz}&status=Pending");

        again.Data!.Created.Should().Be(0);
        again.Data.SkippedKnown.Should().Be(3);
        pending.Data!.TotalCount.Should().Be(2);
    }

    [Fact]
    public async Task A_place_already_in_the_catalog_creates_no_candidate()
    {
        var admin = await Factory.AdminClientAsync();
        var shiraz = await CatalogApi.CityIdAsync(admin, "فارس", "شیراز");
        await admin.PostApiAsync<ImportResultDto>($"{CatalogApi.AdminCandidates}/import", new { items = Candidates(shiraz, 1) });
        var candidate = (await admin.GetApiAsync<PagedResult<VenueCandidateDto>>($"{CatalogApi.AdminCandidates}?cityId={shiraz}")).Data!.Items[0];
        await admin.PostApiAsync<VenueDto>($"{CatalogApi.AdminCandidates}/{candidate.Id}/approve", Approval(candidate.Name, CatalogApi.TennisOutdoor()));

        var again = await admin.PostApiAsync<ImportResultDto>($"{CatalogApi.AdminCandidates}/import", new { items = Candidates(shiraz, 1) });

        again.Data!.Created.Should().Be(0);
        again.Data.SkippedInCatalog.Should().Be(1);
    }

    [Fact]
    public async Task Approving_a_candidate_publishes_a_venue_with_its_sports()
    {
        var admin = await Factory.AdminClientAsync();
        var shiraz = await CatalogApi.CityIdAsync(admin, "فارس", "شیراز");
        await admin.PostApiAsync<ImportResultDto>($"{CatalogApi.AdminCandidates}/import", new { items = Candidates(shiraz, 1) });
        var candidate = (await admin.GetApiAsync<PagedResult<VenueCandidateDto>>($"{CatalogApi.AdminCandidates}?cityId={shiraz}")).Data!.Items[0];

        var approved = await admin.PostApiAsync<VenueDto>($"{CatalogApi.AdminCandidates}/{candidate.Id}/approve", Approval("باشگاه تنیس ارم", CatalogApi.TennisOutdoor(6)));
        var (player, _) = await Factory.SignedInClientAsync(Player);
        var list = await player.GetApiAsync<List<VenueDto>>($"{CatalogApi.Venues}?cityId={shiraz}&sport=tennis");

        approved.Status.Should().Be(HttpStatusCode.OK);
        approved.Data!.GooglePlaceId.Should().Be(candidate.PlaceId);
        list.Data!.Should().ContainSingle(v => v.Name == "باشگاه تنیس ارم" && v.Sports.Single().CourtCount == 6 && v.Sports.Single().HasLighting);
    }

    [Fact]
    public async Task Merging_a_duplicate_attaches_the_place_to_the_existing_venue()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        var existing = await CatalogApi.CreateVenueAsync(admin, tehran, "مجموعه ورزشی انقلاب");
        await admin.PostApiAsync<ImportResultDto>($"{CatalogApi.AdminCandidates}/import", new { items = Candidates(tehran, 1) });
        var candidate = (await admin.GetApiAsync<PagedResult<VenueCandidateDto>>($"{CatalogApi.AdminCandidates}?cityId={tehran}")).Data!.Items[0];

        var merge = await admin.PostApiAsync<Empty>($"{CatalogApi.AdminCandidates}/{candidate.Id}/merge", new { venueId = existing.Id });
        var venue = await admin.GetApiAsync<VenueDto>($"{CatalogApi.AdminVenues}/{existing.Id}");
        var all = await admin.GetApiAsync<PagedResult<VenueDto>>($"{CatalogApi.AdminVenues}?cityId={tehran}");

        merge.Status.Should().Be(HttpStatusCode.NoContent);
        venue.Data!.GooglePlaceId.Should().Be(candidate.PlaceId);
        all.Data!.TotalCount.Should().Be(1);
    }

    [Fact]
    public async Task Bulk_approval_publishes_the_selected_candidates_only()
    {
        var admin = await Factory.AdminClientAsync();
        var mashhad = await CatalogApi.CityIdAsync(admin, "خراسان رضوی", "مشهد");
        await admin.PostApiAsync<ImportResultDto>($"{CatalogApi.AdminCandidates}/import", new { items = Candidates(mashhad, 15) });
        var candidates = (await admin.GetApiAsync<PagedResult<VenueCandidateDto>>($"{CatalogApi.AdminCandidates}?cityId={mashhad}&pageSize=50")).Data!.Items;

        var bulk = await admin.PostApiAsync<Empty>($"{CatalogApi.AdminCandidates}/bulk-approve",
            new { candidateIds = candidates.Take(12).Select(c => c.Id).ToArray(), sports = new[] { CatalogApi.Sport("tennis", "Outdoor") } });
        var venues = await admin.GetApiAsync<PagedResult<VenueDto>>($"{CatalogApi.AdminVenues}?cityId={mashhad}");
        var pending = await admin.GetApiAsync<PagedResult<VenueCandidateDto>>($"{CatalogApi.AdminCandidates}?cityId={mashhad}&status=Pending");

        bulk.Status.Should().Be(HttpStatusCode.NoContent);
        venues.Data!.TotalCount.Should().Be(12);
        pending.Data!.TotalCount.Should().Be(3);
    }

    [Fact]
    public async Task Admin_adds_a_club_that_google_does_not_list()
    {
        var admin = await Factory.AdminClientAsync();
        var karaj = await CatalogApi.CityIdAsync(admin, "البرز", "کرج");

        var created = await CatalogApi.CreateVenueAsync(admin, karaj, "باشگاه تنیس آفتاب", CatalogApi.TennisOutdoor(4));

        created.Status.Should().Be("Active");
        created.GooglePlaceId.Should().BeNull();
    }

    [Fact]
    public async Task Similar_name_in_the_same_city_is_shown_before_saving()
    {
        var admin = await Factory.AdminClientAsync();
        var karaj = await CatalogApi.CityIdAsync(admin, "البرز", "کرج");
        await CatalogApi.CreateVenueAsync(admin, karaj, "باشگاه تنیس آفتاب");

        var similar = await admin.GetApiAsync<List<VenueDto>>($"{CatalogApi.AdminVenues}/similar?cityId={karaj}&name=باشگاه آفتاب");
        var withoutConfirm = await admin.PostApiAsync<VenueDto>(CatalogApi.AdminVenues, new
        {
            cityId = karaj, name = "باشگاه آفتاب", address = (string?)null, sports = new[] { CatalogApi.TennisOutdoor() }, allowSimilar = false,
        });

        similar.Data!.Should().ContainSingle(v => v.Name == "باشگاه تنیس آفتاب");
        withoutConfirm.Status.Should().Be(HttpStatusCode.Conflict);
        withoutConfirm.ErrorCode.Should().Be("SIMILAR_VENUE_EXISTS");
    }

    [Fact]
    public async Task Players_cannot_create_venues()
    {
        var (player, _) = await Factory.SignedInClientAsync(Player);

        var response = await player.PostApiAsync<VenueDto>(CatalogApi.AdminVenues, new { cityId = 428, name = "x" });

        response.Status.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Name_search_treats_arabic_and_persian_letters_alike()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        await CatalogApi.CreateVenueAsync(admin, tehran, "باشگاه تنیس شهید پازوکی");
        var (player, _) = await Factory.SignedInClientAsync(Player);

        var results = await player.GetApiAsync<List<VenueDto>>($"{CatalogApi.Venues}?cityId={tehran}&q={Uri.EscapeDataString("باشگاه تنيس")}");

        results.Data!.Should().ContainSingle(v => v.Name == "باشگاه تنیس شهید پازوکی");
    }

    [Fact]
    public async Task Listing_filters_by_sport()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        await CatalogApi.CreateVenueAsync(admin, tehran, "مجموعه تنیس استقلال", CatalogApi.TennisOutdoor(14));
        await CatalogApi.CreateVenueAsync(admin, tehran, "پدل سنتر تهران", CatalogApi.Sport("padel"));
        var (player, _) = await Factory.SignedInClientAsync(Player);

        var padel = await player.GetApiAsync<List<VenueDto>>($"{CatalogApi.Venues}?cityId={tehran}&sport=padel");

        padel.Data!.Select(v => v.Name).Should().Equal("پدل سنتر تهران");
    }

    [Fact]
    public async Task Hidden_venue_disappears_from_player_lists()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        var venue = await CatalogApi.CreateVenueAsync(admin, tehran, "باشگاه تعطیل‌شده");
        var (player, _) = await Factory.SignedInClientAsync(Player);

        var hide = await admin.PostApiAsync<Empty>($"{CatalogApi.AdminVenues}/{venue.Id}/hide");
        var list = await player.GetApiAsync<List<VenueDto>>($"{CatalogApi.Venues}?cityId={tehran}");
        var detail = await player.GetApiAsync<VenueDto>($"{CatalogApi.Venues}/{venue.Id}");

        hide.Status.Should().Be(HttpStatusCode.NoContent);
        list.Data!.Should().BeEmpty();
        detail.Status.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Venue_without_coordinates_shows_its_address_only()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        var venue = await CatalogApi.CreateVenueAsync(admin, tehran, "باشگاه بی‌نقشه");
        var (player, _) = await Factory.SignedInClientAsync(Player);

        var detail = (await player.GetApiAsync<VenueDto>($"{CatalogApi.Venues}/{venue.Id}")).Data!;

        detail.Address.Should().Be("خیابان ولیعصر");
        detail.Latitude.Should().BeNull();
        detail.Longitude.Should().BeNull();
        detail.CityName.Should().Be("تهران");
    }

    private static object[] Candidates(int cityId, int count) =>
        Enumerable.Range(1, count)
            .Select(i => (object)new { placeId = $"place-{cityId}-{i}", name = $"باشگاه نمونه {i}", address = $"آدرس {i}", latitude = 29.6 + i / 1000.0, longitude = 52.5, cityId, keyword = "باشگاه تنیس" })
            .ToArray();

    private static object Approval(string name, params object[] sports) =>
        new { name, address = "خیابان ارم", phone = (string?)null, latitude = 29.63, longitude = 52.52, sports };
}
