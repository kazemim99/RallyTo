using Rallyto.Catalog.Domain.Sports;
using Rallyto.Catalog.Domain.Venues;
using Rallyto.Core.Domain.Exceptions;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Catalog.UnitTests;

public sealed class PersianTextTests
{
    [Theory]
    [InlineData("باشگاه تنيس", "باشگاه تنیس")]
    [InlineData("كرمان", "کرمان")]
    [InlineData("حرفه‌ای", "حرفهای")]
    [InlineData("  باشگاه    تنیس  ", "باشگاه تنیس")]
    [InlineData("سالن ۱۲", "سالن 12")]
    [InlineData("Club ONE", "club one")]
    public void Normalisation_makes_variants_match(string input, string expected)
    {
        PersianText.Normalize(input).Should().Be(expected);
    }
}

public sealed class VenueNameSimilarityTests
{
    [Theory]
    [InlineData("باشگاه تنیس آفتاب", "باشگاه آفتاب")]
    [InlineData("مجموعه ورزشی انقلاب", "انقلاب")]
    [InlineData("باشگاه تنيس شهيد پازوکي", "شهید پازوکی")]
    public void Same_distinctive_word_means_similar(string a, string b)
    {
        VenueNameSimilarity.AreSimilar(a, b).Should().BeTrue();
    }

    [Theory]
    [InlineData("باشگاه تنیس آفتاب", "باشگاه تنیس مهتاب")]
    [InlineData("مجموعه ورزشی انقلاب", "مجموعه ورزشی آزادی")]
    public void Only_generic_words_in_common_is_not_similar(string a, string b)
    {
        VenueNameSimilarity.AreSimilar(a, b).Should().BeFalse();
    }
}

public sealed class SportRulesTests
{
    private static Sport Padel() => Sport.Create("padel", "پدل", "Padel", 2, 90,
        [new SportFormat(PlayFormat.Doubles, 2)],
        Enumerable.Range(1, 5).Select(i => new LevelDescription((LevelTier)i, $"سطح {i}")),
        []);

    [Fact]
    public void Capacity_is_twice_the_players_per_side()
    {
        Padel().CapacityOf(PlayFormat.Doubles).Should().Be(4);
    }

    [Fact]
    public void A_format_the_sport_does_not_allow_is_rejected()
    {
        var padel = Padel();

        padel.Allows(PlayFormat.Singles).Should().BeFalse();
        var capacity = () => padel.CapacityOf(PlayFormat.Singles);
        capacity.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("FORMAT_NOT_ALLOWED");
    }

    [Fact]
    public void All_five_tiers_are_required()
    {
        var create = () => Sport.Create("x", "ایکس", "X", 1, 60, [new SportFormat(PlayFormat.Singles, 1)],
            [new LevelDescription(LevelTier.Beginner, "a")], []);

        create.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("LEVELS_INCOMPLETE");
    }

    [Theory]
    [InlineData(LevelTier.Beginner, LevelTier.Intermediate, 2)]
    [InlineData(LevelTier.Professional, LevelTier.Beginner, 4)]
    [InlineData(LevelTier.Advanced, LevelTier.Advanced, 0)]
    public void Level_distance_counts_tiers(LevelTier a, LevelTier b, int expected)
    {
        LevelTiers.Distance(a, b).Should().Be(expected);
    }
}

public sealed class VenueRulesTests
{
    private static readonly Guid Tennis = Guid.NewGuid();

    [Fact]
    public void A_hidden_venue_offers_nothing_and_raises_an_event_once()
    {
        var venue = Venue.Create(428, new VenueDetails("باشگاه", null, null, null, null), [new VenueSport(Tennis, 4, CourtSetting.Outdoor, null, true)], null);

        venue.Hide();
        venue.Hide();

        venue.Offers(Tennis).Should().BeFalse();
        venue.DomainEvents.OfType<VenueHidden>().Should().ContainSingle();
    }

    [Fact]
    public void Latitude_without_longitude_is_rejected()
    {
        var create = () => Venue.Create(428, new VenueDetails("باشگاه", null, null, 35.7, null), [new VenueSport(Tennis, null, CourtSetting.Indoor, null, false)], null);

        create.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("INVALID_COORDINATES");
    }

    [Fact]
    public void A_reviewed_candidate_cannot_be_reviewed_again()
    {
        var candidate = VenueCandidate.Import(152, "باشگاه", null, null, null, "p1", "باشگاه تنیس", DateTime.UtcNow);
        candidate.Reject("not a club", Guid.NewGuid(), DateTime.UtcNow);

        var approve = () => candidate.MarkApproved(Guid.NewGuid(), Guid.NewGuid(), DateTime.UtcNow);

        approve.Should().Throw<InvalidAggregateStateException>();
    }
}
