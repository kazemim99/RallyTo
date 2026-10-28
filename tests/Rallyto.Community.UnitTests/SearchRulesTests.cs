using Rallyto.Community.Domain.Availabilities;
using Rallyto.Community.Domain.Players;
using Rallyto.Community.Domain.Search;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Community.UnitTests;

public sealed class PartnerRankingPolicyTests
{
    private static readonly DateTime Now = new(2026, 10, 23, 9, 0, 0, DateTimeKind.Utc);
    private static readonly RankingWeights Weights = new();

    private static RankingInput Candidate(int levelDistance = 0, ReliabilityTier reliability = ReliabilityTier.Unknown, int overlap = 120, double daysAgo = 1, Guid? id = null) =>
        new(id ?? Guid.NewGuid(), levelDistance, overlap, 120, reliability, null, daysAgo, false, Now.AddDays(-daysAgo));

    [Fact]
    public void Closer_level_ranks_first()
    {
        var near = Candidate(levelDistance: 0);
        var far = Candidate(levelDistance: 2);

        PartnerRankingPolicy.Rank([far, near], Weights).Should().Equal(near, far);
    }

    [Fact]
    public void Better_reliability_ranks_first()
    {
        var high = Candidate(reliability: ReliabilityTier.High);
        var low = Candidate(reliability: ReliabilityTier.Low);

        PartnerRankingPolicy.Rank([low, high], Weights).Should().Equal(high, low);
    }

    [Fact]
    public void Longer_overlap_ranks_first()
    {
        var full = Candidate(overlap: 120);
        var partial = Candidate(overlap: 60);

        PartnerRankingPolicy.Rank([partial, full], Weights).Should().Equal(full, partial);
    }

    [Fact]
    public void Ties_break_on_recent_activity_then_id()
    {
        var a = Candidate(daysAgo: 40, id: Guid.Parse("00000000-0000-0000-0000-000000000002"));
        var b = Candidate(daysAgo: 40, id: Guid.Parse("00000000-0000-0000-0000-000000000001"));

        PartnerRankingPolicy.Rank([a, b], Weights).Should().Equal(b, a);
    }
}

public sealed class PartnerMatchRulesTests
{
    private static readonly DateOnly Today = new(2026, 10, 23);
    private static readonly DateOnly Saturday = new(2026, 10, 24);
    private static readonly Guid Tennis = Guid.NewGuid();
    private static readonly Guid Venue = Guid.NewGuid();
    private static readonly PlayerVisibilityFacts Searcher = new(Guid.NewGuid(), Gender.Male, ProfileVisibility.Everyone, ProfileStatus.Active);

    private static SearchCriteria Criteria(int from = 0, int to = 1440, DateOnly? date = null) =>
        new(Tennis, 428, [], date ?? Saturday, IranianWeekdays.None, from, to, LevelTier.LowerIntermediate, LevelTier.Advanced, null, null);

    private static WindowCandidate Window(LevelTier level = LevelTier.Intermediate, Gender gender = Gender.Male, ProfileVisibility visibility = ProfileVisibility.Everyone,
        IranianWeekdays days = IranianWeekdays.Saturday, int start = 1080, int end = 1440, int city = 428) =>
        new(Guid.NewGuid(), Guid.NewGuid(), gender, visibility, ProfileStatus.Active, level, Tennis, city, AvailabilityStatus.Active, AvailabilityKind.Recurring,
            days, null, null, start, end, [Venue], [PlayFormat.Singles]);

    [Fact]
    public void Overlap_of_two_hours_matches() =>
        PartnerMatchRules.Match(Criteria(1200, 1320), Searcher, Window(), false, Today).Should().Be(120);

    [Fact]
    public void Overlap_under_an_hour_does_not() =>
        PartnerMatchRules.Match(Criteria(1410, 1440), Searcher, Window(), false, Today).Should().Be(0);

    [Fact]
    public void Level_outside_the_range_does_not() =>
        PartnerMatchRules.Match(Criteria(), Searcher, Window(level: LevelTier.Beginner), false, Today).Should().Be(0);

    [Fact]
    public void Another_city_does_not() =>
        PartnerMatchRules.Match(Criteria(), Searcher, Window(city: 507), false, Today).Should().Be(0);

    [Fact]
    public void Another_weekday_does_not() =>
        PartnerMatchRules.Match(Criteria(), Searcher, Window(days: IranianWeekdays.Monday), false, Today).Should().Be(0);

    [Fact]
    public void Blocked_or_hidden_players_do_not()
    {
        PartnerMatchRules.Match(Criteria(), Searcher, Window(), blockedEitherWay: true, Today).Should().Be(0);
        PartnerMatchRules.Match(Criteria(), Searcher, Window(gender: Gender.Female, visibility: ProfileVisibility.SameGender), false, Today).Should().Be(0);
    }
}

public sealed class SavedSearchTests
{
    private static readonly DateTime Now = new(2026, 10, 23, 9, 0, 0, DateTimeKind.Utc);
    private static readonly DateOnly Today = new(2026, 10, 23);

    private static SavedSearch Create() => SavedSearch.Create(Guid.NewGuid(), "شنبه‌ها",
        new SearchCriteria(Guid.NewGuid(), 428, [], null, IranianWeekdays.Saturday, 0, 1440, LevelTier.Beginner, LevelTier.Professional, null, null), true);

    [Fact]
    public void First_match_alerts_then_matches_are_held_for_six_hours()
    {
        var search = Create();

        search.RecordMatch(Now, Today).Should().Be(1);
        search.RecordMatch(Now.AddHours(2), Today).Should().Be(0);
        search.RecordMatch(Now.AddHours(3), Today).Should().Be(0);
        search.FlushDigest(Now.AddHours(5)).Should().Be(0);
        search.FlushDigest(Now.AddHours(6)).Should().Be(2);
        search.AlertsSent.Should().Be(2);
        search.PendingMatches.Should().Be(0);
    }

    [Fact]
    public void A_match_after_the_interval_alerts_with_the_held_matches()
    {
        var search = Create();
        search.RecordMatch(Now, Today);
        search.RecordMatch(Now.AddHours(1), Today);

        search.RecordMatch(Now.AddHours(7), Today).Should().Be(2);
    }

    [Fact]
    public void Disabled_alerts_never_alert()
    {
        var search = SavedSearch.Create(Guid.NewGuid(), "بی‌هشدار", Create().Criteria, alertsEnabled: false);

        search.RecordMatch(Now, Today).Should().Be(0);
    }
}
