using Rallyto.Catalog.Application.Venues;
using Rallyto.Catalog.Domain.Venues;
using Rallyto.Core.Domain.Exceptions;

namespace Rallyto.Catalog.UnitTests;

/// <summary>spec venue-catalog › Venue profile and photos.</summary>
public sealed class VenueProfileTests
{
    private static readonly Guid Tennis = Guid.NewGuid();

    private static Venue NewVenue() =>
        Venue.Create(428, new VenueDetails("باشگاه", null, null, null, null), [new VenueSport(Tennis, 4, CourtSetting.Outdoor, null, true)], null);

    private static VenueProfile Profile(string? website = null, string? instagram = null, string? description = null, IReadOnlyList<string>? amenities = null) =>
        new(null, description, website, instagram, null, null, amenities ?? [], []);

    [Fact]
    public void A_new_venue_has_an_empty_profile_and_no_photos()
    {
        var venue = NewVenue();

        venue.Profile.Should().Be(VenueProfile.Empty);
        venue.Images.Should().BeEmpty();
        venue.SourceRef.Should().BeNull();
    }

    [Fact]
    public void Profile_text_is_trimmed_and_blank_becomes_null()
    {
        var venue = NewVenue();

        venue.SetProfile(new VenueProfile("  شعار ", "   ", " https://club.ir ", null, null, " همه‌روزه ۹ تا ۲۳ ", ["پارکینگ", " پارکینگ ", ""], [" خاک رس "]));

        venue.Profile.Tagline.Should().Be("شعار");
        venue.Profile.Description.Should().BeNull();
        venue.Profile.Website.Should().Be("https://club.ir");
        venue.Profile.WorkingHours.Should().Be("همه‌روزه ۹ تا ۲۳");
        venue.Profile.Amenities.Should().Equal("پارکینگ");
        venue.Profile.CourtTypes.Should().Equal("خاک رس");
    }

    [Theory]
    [InlineData("javascript:alert(1)")]
    [InlineData("ftp://club.ir")]
    [InlineData("club.ir")]
    [InlineData("data:text/html;base64,AAAA")]
    public void Links_must_be_http_or_https(string link)
    {
        var venue = NewVenue();

        var website = () => venue.SetProfile(Profile(website: link));
        var instagram = () => venue.SetProfile(Profile(instagram: link));

        website.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("INVALID_VENUE_LINK");
        instagram.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("INVALID_VENUE_LINK");
    }

    [Fact]
    public void Description_longer_than_4000_characters_is_rejected()
    {
        var venue = NewVenue();

        var set = () => venue.SetProfile(Profile(description: new string('ب', 4001)));

        set.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("VENUE_PROFILE_TOO_LONG");
    }

    [Fact]
    public void More_than_30_amenities_are_rejected()
    {
        var venue = NewVenue();

        var set = () => venue.SetProfile(Profile(amenities: Enumerable.Range(0, 31).Select(i => $"امکانات {i}").ToList()));

        set.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("VENUE_PROFILE_TOO_LONG");
    }

    [Fact]
    public void The_first_photo_is_the_cover_and_order_follows_upload_order()
    {
        var venue = NewVenue();

        venue.AddImage("/media/venues/a.jpg");
        venue.AddImage("/media/venues/b.jpg");

        venue.Images.Select(i => i.Path).Should().Equal("/media/venues/a.jpg", "/media/venues/b.jpg");
        venue.CoverImage.Should().Be("/media/venues/a.jpg");
    }

    [Fact]
    public void Removing_the_cover_promotes_the_next_photo()
    {
        var venue = NewVenue();
        venue.AddImage("/media/venues/a.jpg");
        venue.AddImage("/media/venues/b.jpg");

        var removed = venue.RemoveImage("/media/venues/a.jpg");

        removed.Should().BeTrue();
        venue.CoverImage.Should().Be("/media/venues/b.jpg");
        venue.RemoveImage("/media/venues/missing.jpg").Should().BeFalse();
    }

    [Fact]
    public void A_venue_holds_at_most_20_photos()
    {
        var venue = NewVenue();
        for (var i = 0; i < 20; i++)
            venue.AddImage($"/media/venues/{i}.jpg");

        var add = () => venue.AddImage("/media/venues/extra.jpg");

        add.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("VENUE_PHOTO_LIMIT");
    }

    [Fact]
    public void Google_rating_is_kept_with_its_review_count()
    {
        var venue = NewVenue();

        venue.SetGoogleRating(4.6, 120);

        venue.GoogleRating.Should().Be(4.6);
        venue.GoogleReviewCount.Should().Be(120);
    }

    [Theory]
    [InlineData(0.5, 10)]
    [InlineData(5.1, 10)]
    [InlineData(4.0, -1)]
    [InlineData(4.0, null)]
    public void A_rating_outside_one_to_five_or_without_a_review_count_is_rejected(double rating, int? count)
    {
        var venue = NewVenue();

        var set = () => venue.SetGoogleRating(rating, count);

        set.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("INVALID_GOOGLE_RATING");
    }

    [Fact]
    public void No_rating_clears_it()
    {
        var venue = NewVenue();
        venue.SetGoogleRating(4.0, 3);

        venue.SetGoogleRating(null, null);

        venue.GoogleRating.Should().BeNull();
        venue.GoogleReviewCount.Should().BeNull();
    }

    [Fact]
    public void Source_reference_is_required_when_set()
    {
        var venue = NewVenue();

        venue.SetSource("tennix.ir:enghelab", "https://tennix.ir/clubs/enghelab");
        var blank = () => venue.SetSource("  ", null);

        venue.SourceRef.Should().Be("tennix.ir:enghelab");
        venue.SourceUrl.Should().Be("https://tennix.ir/clubs/enghelab");
        blank.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("INVALID_VENUE_SOURCE");
    }
}

public sealed class VenueImageFileTests
{
    private static readonly byte[] Jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46];
    private static readonly byte[] Png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    private static readonly byte[] Webp = [0x52, 0x49, 0x46, 0x46, 1, 2, 3, 4, 0x57, 0x45, 0x42, 0x50];

    [Fact]
    public void Real_image_bytes_are_recognised_whatever_the_declared_type()
    {
        VenueImageFile.Sniff(Jpeg).Should().Be("jpg");
        VenueImageFile.Sniff(Png).Should().Be("png");
        VenueImageFile.Sniff(Webp).Should().Be("webp");
    }

    [Fact]
    public void Other_bytes_are_not_an_image()
    {
        VenueImageFile.Sniff("<html><script>alert(1)</script>"u8.ToArray()).Should().BeNull();
        VenueImageFile.Sniff([]).Should().BeNull();
    }
}
