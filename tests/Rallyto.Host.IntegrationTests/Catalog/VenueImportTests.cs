using System.Text.Json;
using System.Net;
using System.Net.Http.Headers;
using Rallyto.Host.IntegrationTests.Infrastructure;
using Rallyto.Tests.Commons;
using Rallyto.Tests.Commons.Api;

namespace Rallyto.Host.IntegrationTests.Catalog;

/// <summary>spec venue-catalog › Importing clubs with their profile and photos.</summary>
public sealed class VenueImportTests(RallytoHostFactory factory) : IntegrationTestBase(factory)
{
    private const string Import = CatalogApi.AdminVenues + "/import";

    private static readonly byte[] TinyPng = Convert.FromBase64String(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==");

    private static object Item(int cityId, string sourceRef, string name, object? profile = null) => new
    {
        sourceRef,
        sourceUrl = $"https://tennix.ir/clubs/{sourceRef}",
        cityId,
        name,
        address = "تهران، خیابان ولیعصر",
        phone = "02126216153",
        latitude = 35.783,
        longitude = 51.408,
        sports = new[] { CatalogApi.TennisOutdoor(37) },
        profile = profile ?? new
        {
            tagline = "بزرگ‌ترین مجموعه زمین خاک رس",
            description = "توضیح کامل باشگاه",
            website = "https://enghelab.example.ir",
            instagram = "https://www.instagram.com/enghelab/",
            workingHours = "همه‌روزه ۹ تا ۲۳",
            amenities = new[] { "پارکینگ", "رستوران" },
            courtTypes = new[] { "خاک رس" },
        },
    };

    [Fact]
    public async Task Import_creates_active_venues_with_the_whole_profile_visible_to_players()
    {
        var admin = await Factory.AdminClientAsync();
        var (player, _) = await Factory.SignedInClientAsync("09121234567");
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");

        var result = await admin.PostApiAsync<VenueImportResultDto>(Import, new { items = new[] { Item(tehran, "tennix.ir:enghelab", "مجموعه تنیس انقلاب") } });
        var venue = (await player.GetApiAsync<List<VenueDto>>($"{CatalogApi.Venues}?cityId={tehran}")).Data!.Single();

        result.Data!.Created.Should().Be(1);
        result.Data.Items.Single().Outcome.Should().Be("Created");
        venue.Name.Should().Be("مجموعه تنیس انقلاب");
        venue.Status.Should().Be("Active");
        venue.Tagline.Should().Be("بزرگ‌ترین مجموعه زمین خاک رس");
        venue.Description.Should().Be("توضیح کامل باشگاه");
        venue.Website.Should().Be("https://enghelab.example.ir");
        venue.Instagram.Should().Be("https://www.instagram.com/enghelab/");
        venue.WorkingHours.Should().Be("همه‌روزه ۹ تا ۲۳");
        venue.Amenities.Should().Equal("پارکینگ", "رستوران");
        venue.CourtTypes.Should().Equal("خاک رس");
        venue.SourceUrl.Should().Be("https://tennix.ir/clubs/tennix.ir:enghelab");
        venue.Sports.Single().CourtCount.Should().Be(37);
        venue.Latitude.Should().Be(35.783);
    }

    [Fact]
    public async Task Re_running_the_import_creates_no_duplicates_and_keeps_admin_edits()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        var first = await admin.PostApiAsync<VenueImportResultDto>(Import, new { items = new[] { Item(tehran, "tennix.ir:a", "باشگاه آفتاب") } });
        var id = first.Data!.Items.Single().VenueId!.Value;
        await admin.PutApiAsync<VenueDto>($"{CatalogApi.AdminVenues}/{id}", new
        {
            cityId = tehran, name = "باشگاه آفتاب ویرایش‌شده", address = (string?)null, phone = (string?)null,
            latitude = (double?)null, longitude = (double?)null, sports = new[] { CatalogApi.TennisOutdoor() }, allowSimilar = true,
        });

        var again = await admin.PostApiAsync<VenueImportResultDto>(Import, new { items = new[] { Item(tehran, "tennix.ir:a", "باشگاه آفتاب") } });
        var all = (await admin.GetApiAsync<PagedResult<VenueDto>>($"{CatalogApi.AdminVenues}?cityId={tehran}")).Data!;

        again.Data!.Created.Should().Be(0);
        again.Data.Existing.Should().Be(1);
        again.Data.Items.Single().VenueId.Should().Be(id);
        all.Items.Should().ContainSingle().Which.Name.Should().Be("باشگاه آفتاب ویرایش‌شده");
    }

    [Fact]
    public async Task A_club_similar_to_an_existing_one_is_skipped_unless_allowed()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        await CatalogApi.CreateVenueAsync(admin, tehran, "باشگاه تنیس انقلاب");

        var skipped = await admin.PostApiAsync<VenueImportResultDto>(Import, new { items = new[] { Item(tehran, "tennix.ir:b", "مجموعه انقلاب") } });
        var allowed = await admin.PostApiAsync<VenueImportResultDto>(Import, new { items = new[] { Item(tehran, "tennix.ir:b", "مجموعه انقلاب") }, allowSimilar = true });

        skipped.Data!.Created.Should().Be(0);
        skipped.Data.Skipped.Should().Be(1);
        skipped.Data.Items.Single().Outcome.Should().Be("Similar");
        allowed.Data!.Created.Should().Be(1);
    }

    [Fact]
    public async Task Clubs_of_the_same_import_are_not_compared_with_each_other()
    {
        var admin = await Factory.AdminClientAsync();
        var tabriz = await CatalogApi.CityIdAsync(admin, "آذربایجان شرقی", "تبریز");

        var result = await admin.PostApiAsync<VenueImportResultDto>(Import, new
        {
            items = new[] { Item(tabriz, "tennix.ir:t1", "باشگاه تنیس سهند تبریز"), Item(tabriz, "tennix.ir:t2", "باشگاه تنیس ارس تبریز") },
        });

        result.Data!.Created.Should().Be(2);
    }

    [Fact]
    public async Task A_google_place_keeps_its_place_id_rating_and_maps_link_and_is_imported_once()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        object Google(string sourceRef) => new
        {
            sourceRef, sourceUrl = "https://www.google.com/maps/place/?q=place_id:ChIJ-test", googlePlaceId = "ChIJ-test",
            googleRating = 4.5, googleReviewCount = 37, cityId = tehran, name = "باشگاه تنیس گوگل", address = "تهران، ونک",
            phone = "02188776655", latitude = 35.75, longitude = 51.41, sports = new[] { CatalogApi.TennisOutdoor() },
        };

        var first = await admin.PostApiAsync<VenueImportResultDto>(Import, new { items = new[] { Google("google:ChIJ-test") } });
        var again = await admin.PostApiAsync<VenueImportResultDto>(Import, new { items = new[] { Google("other:ref") } });
        var venue = (await admin.GetApiAsync<VenueDto>($"{CatalogApi.AdminVenues}/{first.Data!.Items.Single().VenueId}")).Data!;

        first.Data.Created.Should().Be(1);
        venue.GooglePlaceId.Should().Be("ChIJ-test");
        venue.GoogleRating.Should().Be(4.5);
        venue.GoogleReviewCount.Should().Be(37);
        venue.SourceUrl.Should().Be("https://www.google.com/maps/place/?q=place_id:ChIJ-test");
        again.Data!.Created.Should().Be(0);
        again.Data.Items.Single().Outcome.Should().Be("Existing");
        again.Data.Items.Single().VenueId.Should().Be(venue.Id);
    }

    [Fact]
    public async Task One_invalid_club_is_reported_and_the_rest_of_the_batch_is_created()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        var bad = Item(tehran, "tennix.ir:bad", "باشگاه بد", new { website = "javascript:alert(1)" });

        var result = await admin.PostApiAsync<VenueImportResultDto>(Import, new { items = new[] { bad, Item(tehran, "tennix.ir:good", "باشگاه خوب") } });

        result.Status.Should().Be(HttpStatusCode.OK);
        result.Data!.Items.Select(i => i.Outcome).Should().Equal("Invalid", "Created");
        result.Data.Items[0].Message.Should().NotBeNullOrWhiteSpace();
        result.Data.Created.Should().Be(1);
    }

    [Fact]
    public async Task Only_admins_can_import()
    {
        var (player, _) = await Factory.SignedInClientAsync("09121234567");

        var response = await player.PostApiAsync<VenueImportResultDto>(Import, new { items = Array.Empty<object>() });

        response.Status.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Admin_edits_the_profile_of_an_existing_venue_without_touching_its_details()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        var venue = await CatalogApi.CreateVenueAsync(admin, tehran, "باشگاه پروفایل");

        var updated = await admin.PutApiAsync<VenueDto>($"{CatalogApi.AdminVenues}/{venue.Id}/profile", new
        {
            tagline = "شعار", description = "توضیح", website = "https://club.example.ir", instagram = (string?)null, telegram = (string?)null,
            workingHours = "۹ تا ۲۱", amenities = new[] { "پارکینگ" }, courtTypes = new[] { "هارد" },
        });

        updated.Status.Should().Be(HttpStatusCode.OK);
        updated.Data!.Name.Should().Be("باشگاه پروفایل");
        updated.Data.Address.Should().Be("خیابان ولیعصر");
        updated.Data.Tagline.Should().Be("شعار");
        updated.Data.Amenities.Should().Equal("پارکینگ");
    }

    [Fact]
    public async Task A_profile_link_that_is_not_http_is_rejected()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        var venue = await CatalogApi.CreateVenueAsync(admin, tehran, "باشگاه پروفایل");

        var response = await admin.PutApiAsync<VenueDto>($"{CatalogApi.AdminVenues}/{venue.Id}/profile", new { website = "javascript:alert(1)" });

        response.Status.Should().BeOneOf(HttpStatusCode.BadRequest, HttpStatusCode.UnprocessableEntity);
        response.ErrorCode.Should().Be("INVALID_VENUE_LINK");
    }

    [Fact]
    public async Task Photos_are_stored_served_and_the_first_is_the_cover()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        var venue = await CatalogApi.CreateVenueAsync(admin, tehran, "باشگاه عکس");

        var first = await Upload(admin, venue.Id, TinyPng, "image/png");
        var second = await Upload(admin, venue.Id, TinyPng, "image/png");

        first.Data!.CoverImage.Should().MatchRegex("^/media/venues/[0-9a-f]{32}\\.png$");
        second.Data!.Images.Should().HaveCount(2);
        second.Data.CoverImage.Should().Be(first.Data.CoverImage);
        (await Factory.CreateClient().GetAsync(second.Data.CoverImage)).StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Fake_images_are_rejected_whatever_the_declared_type()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        var venue = await CatalogApi.CreateVenueAsync(admin, tehran, "باشگاه عکس");

        var response = await Upload(admin, venue.Id, "<html><script>alert(1)</script></html>"u8.ToArray(), "image/png");

        response.Status.Should().Be(HttpStatusCode.BadRequest);
        response.ErrorCode.Should().Be("PHOTO_TYPE_NOT_ALLOWED");
    }

    [Fact]
    public async Task Removing_the_cover_promotes_the_next_photo_and_deletes_the_file()
    {
        var admin = await Factory.AdminClientAsync();
        var tehran = await CatalogApi.CityIdAsync(admin, "تهران", "تهران");
        var venue = await CatalogApi.CreateVenueAsync(admin, tehran, "باشگاه عکس");
        await Upload(admin, venue.Id, TinyPng, "image/png");
        var two = (await Upload(admin, venue.Id, TinyPng, "image/png")).Data!;
        var (cover, next) = (two.Images![0], two.Images[1]);

        var removed = await admin.DeleteApiAsync<VenueDto>($"{CatalogApi.AdminVenues}/{venue.Id}/images?path={Uri.EscapeDataString(cover)}");

        removed.Data!.CoverImage.Should().Be(next);
        (await Factory.CreateClient().GetAsync(cover)).StatusCode.Should().NotBe(HttpStatusCode.OK);
    }

    private static async Task<ApiResponse<VenueDto>> Upload(HttpClient admin, Guid venueId, byte[] bytes, string contentType)
    {
        using var form = new MultipartFormDataContent { { new ByteArrayContent(bytes) { Headers = { ContentType = new MediaTypeHeaderValue(contentType) } }, "file", "club.png" } };
        var response = await admin.PostAsync($"{CatalogApi.AdminVenues}/{venueId}/images", form);
        var text = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(text);
        var root = doc.RootElement;
        return new ApiResponse<VenueDto>
        {
            Status = response.StatusCode,
            Raw = response,
            Data = root.TryGetProperty("data", out var d) && d.ValueKind == JsonValueKind.Object ? d.Deserialize<VenueDto>(ApiClient.Json) : null,
            Error = root.TryGetProperty("error", out var e) && e.ValueKind == JsonValueKind.Object
                ? new ApiError(e.GetProperty("code").GetString() ?? "", e.GetProperty("message").GetString() ?? "")
                : null,
        };
    }
}
