using Rallyto.Community.Domain.Matches;
using Rallyto.Community.Domain.Ratings;
using Rallyto.Community.Domain.Search;
using Rallyto.Core.Domain.Exceptions;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Community.UnitTests;

public sealed class AttendanceResolutionPolicyTests
{
    private static readonly Guid A = Guid.NewGuid(), B = Guid.NewGuid(), C = Guid.NewGuid(), D = Guid.NewGuid();

    private static AttendanceInput In(Guid id, AttendanceAnswer? answer, params Guid[] flags) => new(id, answer, flags);

    [Fact]
    public void Both_played_is_completed()
    {
        var result = AttendanceResolutionPolicy.Resolve([In(A, AttendanceAnswer.Played), In(B, AttendanceAnswer.Played)]);

        result.Status.Should().Be(MatchStatus.Completed);
        result.Outcomes.Values.Should().OnlyContain(o => o == AttendanceOutcome.Played);
    }

    [Fact]
    public void A_silent_unflagged_player_counts_as_played()
    {
        var result = AttendanceResolutionPolicy.Resolve([In(A, AttendanceAnswer.Played), In(B, null)]);

        result.Outcomes[B].Should().Be(AttendanceOutcome.Played);
    }

    [Fact]
    public void Played_and_did_not_happen_is_disputed_with_no_outcomes()
    {
        var result = AttendanceResolutionPolicy.Resolve([In(A, AttendanceAnswer.Played), In(B, AttendanceAnswer.DidNotHappen)]);

        result.Status.Should().Be(MatchStatus.Disputed);
        result.Outcomes.Should().BeEmpty();
    }

    [Theory]
    [InlineData(null, null)]
    [InlineData(AttendanceAnswer.DidNotHappen, null)]
    [InlineData(AttendanceAnswer.DidNotHappen, AttendanceAnswer.DidNotHappen)]
    public void No_played_answer_is_unconfirmed(AttendanceAnswer? a, AttendanceAnswer? b) =>
        AttendanceResolutionPolicy.Resolve([In(A, a), In(B, b)]).Status.Should().Be(MatchStatus.Unconfirmed);

    [Fact]
    public void A_flagged_silent_player_is_a_no_show()
    {
        var result = AttendanceResolutionPolicy.Resolve([
            In(A, AttendanceAnswer.Played, D), In(B, AttendanceAnswer.Played, D), In(C, AttendanceAnswer.Played, D), In(D, null)]);

        result.Status.Should().Be(MatchStatus.Completed);
        result.Outcomes[D].Should().Be(AttendanceOutcome.NoShow);
        result.Outcomes[A].Should().Be(AttendanceOutcome.Played);
    }

    [Fact]
    public void A_flagged_player_who_says_played_is_contested()
    {
        var result = AttendanceResolutionPolicy.Resolve([In(A, AttendanceAnswer.Played, D), In(D, AttendanceAnswer.Played)]);

        result.Outcomes[D].Should().Be(AttendanceOutcome.Contested);
    }

    [Fact]
    public void A_flag_from_one_participant_is_enough()
    {
        var result = AttendanceResolutionPolicy.Resolve([In(A, AttendanceAnswer.Played, D), In(B, AttendanceAnswer.Played), In(D, null)]);

        result.Outcomes[D].Should().Be(AttendanceOutcome.NoShow);
    }
}

public sealed class AttendanceOnMatchTests
{
    private static readonly DateTime Now = new(2026, 10, 23, 9, 0, 0, DateTimeKind.Utc);
    private static readonly Guid Host = Guid.NewGuid();
    private static readonly Guid Guest = Guid.NewGuid();

    private static Match ConfirmedSingles()
    {
        var slot = MatchSlot.Create(Guid.NewGuid(), PlayFormat.Singles, 2, Guid.NewGuid(), 428, Now.AddHours(30), 90, Now);
        var match = Match.CreatePost(Host, slot, MatchTerms.Create(LevelTier.Beginner, LevelTier.Professional, PartnerGender.Any, false, null, null), 0, Now);
        match.RequestToJoin(Guest, null, false, Now);
        match.AcceptRequest(Host, Guest, Now);
        return match;
    }

    [Fact]
    public void Only_players_of_the_game_answer()
    {
        var match = ConfirmedSingles();
        var answer = () => match.AnswerAttendance(Guid.NewGuid(), AttendanceAnswer.Played, [], match.EndsAt);
        answer.Should().Throw<InvalidAggregateStateException>().Which.ErrorCode.Should().Be("NOT_A_PARTICIPANT");
    }

    [Fact]
    public void No_shows_can_only_be_flagged_with_played_and_among_other_players()
    {
        var match = ConfirmedSingles();

        var withNotHappened = () => match.AnswerAttendance(Host, AttendanceAnswer.DidNotHappen, [Guest], match.EndsAt);
        var self = () => match.AnswerAttendance(Host, AttendanceAnswer.Played, [Host], match.EndsAt);

        withNotHappened.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("INVALID_NO_SHOW");
        self.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("INVALID_NO_SHOW");
    }

    [Fact]
    public void The_window_closes_after_72_hours()
    {
        var match = ConfirmedSingles();

        var late = () => match.AnswerAttendance(Host, AttendanceAnswer.Played, [], match.EndsAt.AddHours(72));
        match.CloseAttendance(match.EndsAt.AddHours(71));

        late.Should().Throw<InvalidAggregateStateException>().Which.ErrorCode.Should().Be("ATTENDANCE_CLOSED");
        match.Status.Should().Be(MatchStatus.Confirmed);
        match.CloseAttendance(match.EndsAt.AddHours(72));
        match.Status.Should().Be(MatchStatus.Unconfirmed);
        match.ResolvedAt.Should().Be(match.EndsAt.AddHours(72));
    }

    [Fact]
    public void Rating_needs_both_played_and_an_open_window()
    {
        var match = ConfirmedSingles();
        match.AnswerAttendance(Host, AttendanceAnswer.Played, [], match.EndsAt);
        match.AnswerAttendance(Guest, AttendanceAnswer.Played, [], match.EndsAt);

        var ok = () => match.EnsureCanRate(Host, Guest, match.EndsAt.AddDays(7));
        var late = () => match.EnsureCanRate(Host, Guest, match.EndsAt.AddDays(7).AddMinutes(1));

        ok.Should().NotThrow();
        late.Should().Throw<InvalidAggregateStateException>().Which.ErrorCode.Should().Be("RATING_WINDOW_CLOSED");
    }
}

public sealed class ReliabilityPolicyTests
{
    private static IEnumerable<CommitmentKind> Of(int played, int noShows = 0, int late = 0) =>
        Enumerable.Repeat(CommitmentKind.Played, played).Concat(Enumerable.Repeat(CommitmentKind.NoShow, noShows)).Concat(Enumerable.Repeat(CommitmentKind.LateCancellation, late));

    [Theory]
    [InlineData(10, 1, 0, ReliabilityTier.High)]
    [InlineData(6, 2, 0, ReliabilityTier.Good)]
    [InlineData(9, 0, 2, ReliabilityTier.High)]
    [InlineData(3, 2, 0, ReliabilityTier.Low)]
    [InlineData(2, 0, 0, ReliabilityTier.New)]
    [InlineData(0, 0, 0, ReliabilityTier.New)]
    public void Tiers_follow_the_spec_numbers(int played, int noShows, int late, ReliabilityTier tier) =>
        ReliabilityPolicy.Tier(Of(played, noShows, late).ToList()).Should().Be(tier);

    [Theory]
    [InlineData(10, 1, 0, 0.909)]
    [InlineData(6, 2, 0, 0.75)]
    [InlineData(9, 0, 2, 0.90)]
    [InlineData(3, 2, 0, 0.60)]
    public void Scores_follow_the_formula(int played, int noShows, int late, double score) =>
        ReliabilityPolicy.Score(Of(played, noShows, late).ToList()).Should().BeApproximately(score, 0.001);

    [Fact]
    public void Only_the_last_20_commitments_count()
    {
        // Newest first: 20 played, then 10 old no-shows that fall out of the window.
        var commitments = Of(20).Concat(Enumerable.Repeat(CommitmentKind.NoShow, 10)).ToList();

        ReliabilityPolicy.Tier(commitments).Should().Be(ReliabilityTier.High);
    }
}

public sealed class ReputationPolicyTests
{
    private static RatingFacts R(int stars, RatingTags tags = RatingTags.None, LevelAccuracy level = LevelAccuracy.AboutRight) => new(stars, tags, level);

    [Fact]
    public void Two_ratings_are_a_new_player()
    {
        var summary = ReputationPolicy.Summarise([R(5), R(5)]);

        summary.IsNew.Should().BeTrue();
        summary.StarAverage.Should().BeNull();
        summary.TopTags.Should().BeEmpty();
        summary.LevelStatement.Should().BeNull();
    }

    [Fact]
    public void Three_ratings_show_the_average_to_one_decimal()
    {
        var summary = ReputationPolicy.Summarise([R(5), R(4), R(4)]);

        summary.StarAverage.Should().Be(4.3);
        summary.RatingCount.Should().Be(3);
    }

    [Fact]
    public void Top_three_tags_by_frequency()
    {
        var summary = ReputationPolicy.Summarise([
            R(5, RatingTags.OnTime | RatingTags.Friendly | RatingTags.GoodRally),
            R(4, RatingTags.OnTime | RatingTags.Friendly),
            R(4, RatingTags.OnTime | RatingTags.WellOrganised | RatingTags.FairCalls)]);

        summary.TopTags.Should().HaveCount(3);
        summary.TopTags.Take(2).Should().Equal(RatingTags.OnTime, RatingTags.Friendly);
    }

    [Fact]
    public void A_level_statement_needs_a_60_percent_majority()
    {
        ReputationPolicy.Summarise([R(4, level: LevelAccuracy.Higher), R(4, level: LevelAccuracy.Higher), R(4, level: LevelAccuracy.Higher),
            R(4, level: LevelAccuracy.Higher), R(4)]).LevelStatement.Should().Be(LevelAccuracy.Higher);
        ReputationPolicy.Summarise([R(4, level: LevelAccuracy.Higher), R(4, level: LevelAccuracy.Lower), R(4), R(4, level: LevelAccuracy.Higher), R(4)])
            .LevelStatement.Should().BeNull();
    }
}

public sealed class RatingRulesTests
{
    private static readonly DateTime Now = new(2026, 10, 23, 9, 0, 0, DateTimeKind.Utc);

    [Theory]
    [InlineData(0, "INVALID_STARS")]
    [InlineData(6, "INVALID_STARS")]
    public void Stars_are_one_to_five(int stars, string code)
    {
        var create = () => Rating.Create(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), stars, [], LevelAccuracy.AboutRight, null, Now, Now.AddDays(7));
        create.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be(code);
    }

    [Fact]
    public void At_most_three_tags_and_a_short_private_note()
    {
        var tags = () => Rating.Create(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), 4,
            [RatingTags.OnTime, RatingTags.Friendly, RatingTags.GoodRally, RatingTags.FairCalls], LevelAccuracy.AboutRight, null, Now, Now.AddDays(7));
        var note = () => Rating.Create(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), 4, [], LevelAccuracy.AboutRight, new string('ن', 501), Now, Now.AddDays(7));

        tags.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("TOO_MANY_TAGS");
        note.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("NOTE_TOO_LONG");
    }

    [Fact]
    public void A_removed_rating_stays_hidden_from_aggregates()
    {
        var rating = Rating.Create(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), 1, [], LevelAccuracy.Lower, null, Now, Now.AddDays(7));
        rating.Reveal(Now);

        rating.Remove(Guid.NewGuid(), "retaliation after a dispute", Now);

        rating.Counts.Should().BeFalse();
        rating.RemovalReason.Should().Be("retaliation after a dispute");
    }
}
