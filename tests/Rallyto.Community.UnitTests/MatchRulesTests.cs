using Rallyto.Community.Domain.Matches;
using Rallyto.Core.Domain.Exceptions;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Community.UnitTests;

public sealed class MatchRulesTests
{
    private static readonly DateTime Now = new(2026, 10, 23, 9, 0, 0, DateTimeKind.Utc);
    private static readonly Guid Host = Guid.NewGuid();
    private static readonly MatchTerms Terms = MatchTerms.Create(LevelTier.LowerIntermediate, LevelTier.Advanced, PartnerGender.Any, true, null, null);

    private static MatchSlot Slot(int capacity = 2, PlayFormat format = PlayFormat.Singles, double hoursAhead = 30) =>
        MatchSlot.Create(Guid.NewGuid(), format, capacity, Guid.NewGuid(), 428, Now.AddHours(hoursAhead), 90, Now);

    private static Match Post(int capacity = 2, int brought = 0, double hoursAhead = 30) =>
        Match.CreatePost(Host, Slot(capacity, capacity == 2 ? PlayFormat.Singles : PlayFormat.Doubles, hoursAhead), Terms, brought, Now);

    [Theory]
    [InlineData(2, 0, 1)]
    [InlineData(4, 0, 3)]
    [InlineData(4, 2, 1)]
    public void Open_spots_are_capacity_minus_host_and_players_brought(int capacity, int brought, int spots) =>
        Post(capacity, brought).OpenSpots.Should().Be(spots);

    [Fact]
    public void Bringing_more_players_than_capacity_allows_is_rejected()
    {
        var create = () => Post(2, 1);
        create.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("INVALID_PLAYERS_BROUGHT");
    }

    [Theory]
    [InlineData(0.25, "START_TOO_SOON")]
    [InlineData(24 * 31, "START_TOO_FAR")]
    public void Start_must_be_between_30_minutes_and_30_days_ahead(double hoursAhead, string code)
    {
        var create = () => Slot(hoursAhead: hoursAhead);
        create.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be(code);
    }

    [Fact]
    public void Accepting_the_last_request_confirms_and_declines_the_rest()
    {
        var match = Post();
        Guid a = Guid.NewGuid(), b = Guid.NewGuid();
        match.RequestToJoin(a, null, false, Now);
        match.RequestToJoin(b, null, false, Now);

        match.AcceptRequest(Host, a, Now);

        match.Status.Should().Be(MatchStatus.Confirmed);
        match.ParticipantOf(b)!.State.Should().Be(ParticipantState.Declined);
    }

    [Fact]
    public void Leaving_a_confirmed_public_match_reopens_it_and_is_late_within_12_hours()
    {
        var match = Post(hoursAhead: 5);
        var guest = Guid.NewGuid();
        match.RequestToJoin(guest, null, false, Now);
        match.AcceptRequest(Host, guest, Now);

        var late = match.Leave(guest, exemptFromLateCancellation: false, Now);

        late.Should().BeTrue();
        match.Status.Should().Be(MatchStatus.Open);
        match.OpenSpots.Should().Be(1);
    }

    [Fact]
    public void Leaving_a_match_that_was_not_confirmed_is_never_late()
    {
        var match = Post(4, hoursAhead: 5);
        var guest = Guid.NewGuid();
        match.RequestToJoin(guest, null, false, Now);
        match.AcceptRequest(Host, guest, Now);

        match.Leave(guest, false, Now).Should().BeFalse();
    }

    [Fact]
    public void At_start_a_lone_host_expires_and_two_players_confirm()
    {
        var alone = Post(hoursAhead: 1);
        var doubles = Post(4, hoursAhead: 1);
        var guest = Guid.NewGuid();
        doubles.RequestToJoin(guest, null, false, Now);
        doubles.AcceptRequest(Host, guest, Now);

        alone.StartReached(Now.AddHours(1));
        doubles.StartReached(Now.AddHours(1));

        alone.Status.Should().Be(MatchStatus.Expired);
        doubles.Status.Should().Be(MatchStatus.Confirmed);
    }

    [Fact]
    public void All_invitees_declining_cancels_a_private_match()
    {
        Guid a = Guid.NewGuid(), b = Guid.NewGuid();
        var match = Match.CreateInvitation(Host, Slot(4, PlayFormat.Doubles), Terms, 1, [a, b], null, Now);

        match.AnswerInvitation(a, false, Now);
        match.AnswerInvitation(b, false, Now);

        match.Status.Should().Be(MatchStatus.Cancelled);
    }

    [Fact]
    public void Only_the_host_can_accept_requests()
    {
        var match = Post();
        var guest = Guid.NewGuid();
        match.RequestToJoin(guest, null, false, Now);

        var accept = () => match.AcceptRequest(Guid.NewGuid(), guest, Now);

        accept.Should().Throw<InvalidAggregateStateException>().Which.ErrorCode.Should().Be("NOT_THE_HOST");
    }

    [Fact]
    public void Schedule_is_locked_once_someone_accepted()
    {
        var match = Post(4);
        var guest = Guid.NewGuid();
        match.RequestToJoin(guest, null, false, Now);
        match.AcceptRequest(Host, guest, Now);

        var edit = () => match.EditSlot(Host, Slot(4, PlayFormat.Doubles, 40), 0, Now);

        edit.Should().Throw<InvalidAggregateStateException>().Which.ErrorCode.Should().Be("SCHEDULE_LOCKED");
    }

    [Fact]
    public void A_banned_host_cancels_and_a_banned_guest_is_removed()
    {
        var hosted = Post(4);
        var joined = Match.CreatePost(Guid.NewGuid(), Slot(4, PlayFormat.Doubles), Terms, 0, Now);
        joined.RequestToJoin(Host, null, false, Now);
        joined.AcceptRequest(joined.HostId, Host, Now);

        hosted.RemoveForAccount(Host, Now);
        joined.RemoveForAccount(Host, Now);

        hosted.Status.Should().Be(MatchStatus.Cancelled);
        joined.ParticipantOf(Host)!.State.Should().Be(ParticipantState.Removed);
    }
}
