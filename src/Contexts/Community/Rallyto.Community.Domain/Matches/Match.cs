using System.Security.Cryptography;
using Rallyto.Core.Domain.Base;
using Rallyto.Core.Domain.Exceptions;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Community.Domain.Matches;

public enum MatchVisibility
{
    Public = 1,
    Private = 2,
}

public enum MatchStatus
{
    Open = 1,
    Pending = 2,
    Confirmed = 3,
    Completed = 4,
    Disputed = 5,
    Unconfirmed = 6,
    Cancelled = 7,
    Expired = 8,
}

public enum ParticipantState
{
    Host = 1,
    Invited = 2,
    Requested = 3,
    Accepted = 4,
    Declined = 5,
    Withdrawn = 6,
    Left = 7,
    Removed = 8,
    Expired = 9,
}

public enum PartnerGender
{
    Any = 0,
    Male = 1,
    Female = 2,
}

public sealed class MatchParticipant
{
    private MatchParticipant() { }

    public MatchParticipant(Guid playerId, ParticipantState state, string? message, bool outOfRange, DateTime now)
    {
        PlayerId = playerId;
        State = state;
        Message = message;
        OutOfRange = outOfRange;
        JoinedAt = now;
    }

    public Guid PlayerId { get; private set; }
    public ParticipantState State { get; internal set; }
    public string? Message { get; private set; }
    public bool OutOfRange { get; private set; }
    public DateTime JoinedAt { get; private set; }
    public DateTime? RespondedAt { get; internal set; }

    public AttendanceAnswer? Attendance { get; internal set; }

    /// <summary>The other players this participant reported as no-shows.</summary>
    public List<Guid> NoShowFlags { get; internal set; } = [];

    public DateTime? AnsweredAt { get; internal set; }

    /// <summary>Set when the match is resolved as Completed (spec match-lifecycle › Attendance confirmation).</summary>
    public AttendanceOutcome? Outcome { get; internal set; }

    /// <summary>Holds a place in the game: the host or an accepted player.</summary>
    public bool Plays => State is ParticipantState.Host or ParticipantState.Accepted;
}

/// <summary>The schedule and place of a game, validated against the sport's rules and today's Tehran time.</summary>
public sealed record MatchSlot(Guid SportId, PlayFormat Format, int Capacity, Guid VenueId, int CityId, DateTime StartsAt, int DurationMinutes)
{
    public const int MinDuration = 60;
    public const int MaxDuration = 240;
    public static readonly TimeSpan MinLeadTime = TimeSpan.FromMinutes(30);
    public const int MaxDaysAhead = 30;

    public DateTime EndsAt => StartsAt.AddMinutes(DurationMinutes);

    public static MatchSlot Create(Guid sportId, PlayFormat format, int capacity, Guid venueId, int cityId, DateTime startsAtUtc, int durationMinutes, DateTime now)
    {
        if (durationMinutes is < MinDuration or > MaxDuration || durationMinutes % 30 != 0)
            throw new BusinessRuleViolationException("INVALID_DURATION", "مدت بازی باید ۶۰ تا ۲۴۰ دقیقه و مضرب ۳۰ دقیقه باشد.");
        if (startsAtUtc < now + MinLeadTime)
            throw new BusinessRuleViolationException("START_TOO_SOON", "زمان شروع باید دست‌کم ۳۰ دقیقه بعد باشد.");
        if (startsAtUtc > now.AddDays(MaxDaysAhead))
            throw new BusinessRuleViolationException("START_TOO_FAR", $"زمان شروع حداکثر {MaxDaysAhead} روز بعد است.");
        return new MatchSlot(sportId, format, capacity, venueId, cityId, startsAtUtc, durationMinutes);
    }

    public bool Overlaps(DateTime start, DateTime end) => StartsAt < end && start < EndsAt;
}

public sealed record MatchTerms(LevelTier MinLevel, LevelTier MaxLevel, PartnerGender PartnerGender, bool CourtBooked, string? CostNote, string? Description)
{
    public static MatchTerms Create(LevelTier min, LevelTier max, PartnerGender gender, bool courtBooked, string? costNote, string? description)
    {
        if (costNote is { Length: > 200 })
            throw new BusinessRuleViolationException("COST_NOTE_TOO_LONG", "یادداشت هزینه حداکثر ۲۰۰ نویسه است.");
        if (description is { Length: > 500 })
            throw new BusinessRuleViolationException("DESCRIPTION_TOO_LONG", "توضیحات حداکثر ۵۰۰ نویسه است.");
        if (max < min)
            (min, max) = (max, min);
        return new MatchTerms(min, max, gender, courtBooked, string.IsNullOrWhiteSpace(costNote) ? null : costNote.Trim(), string.IsNullOrWhiteSpace(description) ? null : description.Trim());
    }
}

/// <summary>
/// A game (design D4): a public play post with open spots, or a private invitation. One participant model, one
/// capacity rule and one lifecycle for both (spec play-posts, spec match-lifecycle).
/// </summary>
public sealed partial class Match : AggregateRoot<Guid>
{
    public const int MaxMessageLength = 200;
    public static readonly TimeSpan LateCancellationWindow = TimeSpan.FromHours(12);

    private List<MatchParticipant> _participants = [];

    private Match() { }

    public Guid HostId { get; private set; }
    public MatchVisibility Visibility { get; private set; }
    public MatchStatus Status { get; private set; }
    public Guid SportId { get; private set; }
    public PlayFormat Format { get; private set; }
    public int Capacity { get; private set; }
    public Guid VenueId { get; private set; }
    public int CityId { get; private set; }
    public DateTime StartsAt { get; private set; }
    public int DurationMinutes { get; private set; }
    public DateTime EndsAt { get; private set; }
    public int PlayersBrought { get; private set; }
    public LevelTier MinLevel { get; private set; }
    public LevelTier MaxLevel { get; private set; }
    public PartnerGender PartnerGender { get; private set; }
    public bool CourtBooked { get; private set; }
    public string? CostNote { get; private set; }
    public string? Description { get; private set; }
    public string ShareToken { get; private set; } = string.Empty;
    public string? CancelReason { get; private set; }
    public uint Version { get; private set; }

    public IReadOnlyList<MatchParticipant> Participants => _participants;

    /// <summary>Everyone who holds a place: the host, players they bring, accepted players.</summary>
    public int PlayerCount => _participants.Count(p => p.Plays) + PlayersBrought;

    public int OpenSpots => Math.Max(0, Capacity - PlayerCount);

    public bool IsFinished => Status is MatchStatus.Completed or MatchStatus.Disputed or MatchStatus.Unconfirmed or MatchStatus.Cancelled or MatchStatus.Expired;

    public MatchParticipant? ParticipantOf(Guid playerId) => _participants.FirstOrDefault(p => p.PlayerId == playerId);

    public static Match CreatePost(Guid hostId, MatchSlot slot, MatchTerms terms, int playersBrought, DateTime now)
    {
        var match = Create(hostId, MatchVisibility.Public, MatchStatus.Open, slot, terms, playersBrought, now);
        match.RaiseDomainEvent(new MatchPublished(match.Id, hostId));
        return match;
    }

    public static Match CreateInvitation(Guid hostId, MatchSlot slot, MatchTerms terms, int playersBrought, IReadOnlyCollection<Guid> invitees, string? message, DateTime now)
    {
        var match = Create(hostId, MatchVisibility.Private, MatchStatus.Pending, slot, terms, playersBrought, now);
        match.Invite(hostId, invitees, message, now);
        return match;
    }

    private static Match Create(Guid hostId, MatchVisibility visibility, MatchStatus status, MatchSlot slot, MatchTerms terms, int playersBrought, DateTime now)
    {
        if (playersBrought < 0 || playersBrought > slot.Capacity - 2)
            throw new BusinessRuleViolationException("INVALID_PLAYERS_BROUGHT", "تعداد همراهان با ظرفیت بازی جور نیست.");
        var match = new Match
        {
            Id = Guid.NewGuid(),
            HostId = hostId,
            Visibility = visibility,
            Status = status,
            PlayersBrought = playersBrought,
            ShareToken = NewShareToken(),
        };
        match.ApplySlot(slot);
        match.ApplyTerms(terms);
        match._participants.Add(new MatchParticipant(hostId, ParticipantState.Host, null, false, now));
        return match;
    }

    /// <summary>Host invites players into a private match or into remaining spots of their own post.</summary>
    public void Invite(Guid actorId, IReadOnlyCollection<Guid> playerIds, string? message, DateTime now)
    {
        EnsureHost(actorId);
        EnsureAcceptingPlayers(now);
        EnsureMessage(message);
        var newcomers = playerIds.Distinct().Where(id => id != HostId).ToList();
        var outstanding = _participants.Count(p => p.State == ParticipantState.Invited);
        if (newcomers.Count == 0 || newcomers.Count + outstanding > OpenSpots)
            throw new BusinessRuleViolationException("TOO_MANY_INVITEES", $"ظرفیت این بازی برای {OpenSpots} نفر دیگر جا دارد.");
        foreach (var playerId in newcomers)
        {
            var existing = ParticipantOf(playerId);
            if (existing is { State: ParticipantState.Accepted or ParticipantState.Invited or ParticipantState.Requested })
                continue;
            if (existing is not null)
                _participants.Remove(existing);
            _participants.Add(new MatchParticipant(playerId, ParticipantState.Invited, message?.Trim(), false, now));
            RaiseDomainEvent(new InvitationSent(Id, HostId, playerId));
        }
    }

    public void RequestToJoin(Guid playerId, string? message, bool outOfRange, DateTime now)
    {
        if (Visibility != MatchVisibility.Public)
            throw new InvalidAggregateStateException("NOT_A_POST", "این بازی دعوت خصوصی است.");
        if (HiddenAt is not null)
            throw new InvalidAggregateStateException("MATCH_CLOSED", "این بازی دیگر بازیکن نمی‌پذیرد.");
        EnsureAcceptingPlayers(now);
        EnsureMessage(message);
        if (playerId == HostId)
            throw new InvalidAggregateStateException("ALREADY_IN_MATCH", "شما میزبان این بازی هستید.");
        if (OpenSpots == 0)
            throw new InvalidAggregateStateException("NO_OPEN_SPOT", "جای خالی در این بازی نمانده است.");
        var existing = ParticipantOf(playerId);
        if (existing is { State: ParticipantState.Accepted or ParticipantState.Requested or ParticipantState.Invited })
            throw new InvalidAggregateStateException("ALREADY_IN_MATCH", "قبلاً در این بازی هستید یا درخواست داده‌اید.");
        if (existing is not null)
            _participants.Remove(existing);
        _participants.Add(new MatchParticipant(playerId, ParticipantState.Requested, message?.Trim(), outOfRange, now));
        RaiseDomainEvent(new JoinRequested(Id, HostId, playerId));
    }

    public void WithdrawRequest(Guid playerId, DateTime now)
    {
        var participant = Require(playerId, ParticipantState.Requested);
        Transition(participant, ParticipantState.Withdrawn, now);
    }

    /// <summary>Host accepts a join request. Filling the last spot confirms the match and declines the rest.</summary>
    public void AcceptRequest(Guid actorId, Guid playerId, DateTime now)
    {
        EnsureHost(actorId);
        EnsureAcceptingPlayers(now);
        var participant = Require(playerId, ParticipantState.Requested);
        if (OpenSpots == 0)
            throw new InvalidAggregateStateException("NO_OPEN_SPOT", "جای خالی در این بازی نمانده است.");
        Transition(participant, ParticipantState.Accepted, now);
        RaiseDomainEvent(new JoinAnswered(Id, playerId, Accepted: true));
        AfterPlayerAdded(now);
    }

    public void DeclineRequest(Guid actorId, Guid playerId, DateTime now)
    {
        EnsureHost(actorId);
        var participant = Require(playerId, ParticipantState.Requested);
        Transition(participant, ParticipantState.Declined, now);
        RaiseDomainEvent(new JoinAnswered(Id, playerId, Accepted: false));
    }

    public void AnswerInvitation(Guid playerId, bool accept, DateTime now)
    {
        var participant = Require(playerId, ParticipantState.Invited);
        if (!accept)
        {
            Transition(participant, ParticipantState.Declined, now);
            RaiseDomainEvent(new InvitationAnswered(Id, HostId, playerId, Accepted: false));
            if (Visibility == MatchVisibility.Private && _participants.All(p => p.State is not (ParticipantState.Invited or ParticipantState.Accepted)))
                SetStatus(MatchStatus.Cancelled, "invitees declined");
            return;
        }

        EnsureAcceptingPlayers(now);
        if (OpenSpots == 0)
            throw new InvalidAggregateStateException("NO_OPEN_SPOT", "جای خالی در این بازی نمانده است.");
        Transition(participant, ParticipantState.Accepted, now);
        RaiseDomainEvent(new InvitationAnswered(Id, HostId, playerId, Accepted: true));
        AfterPlayerAdded(now);
    }

    /// <summary>Host starts the game with fewer players than capacity (at least 2 including the host).</summary>
    public void ConfirmEarly(Guid actorId, DateTime now)
    {
        EnsureHost(actorId);
        EnsureAcceptingPlayers(now);
        if (PlayerCount < 2)
            throw new InvalidAggregateStateException("NOT_ENOUGH_PLAYERS", "برای تأیید بازی دست‌کم دو بازیکن لازم است.");
        Confirm(now);
    }

    /// <summary>An accepted player leaves. Returns whether it counts as a late cancellation.</summary>
    public bool Leave(Guid playerId, bool exemptFromLateCancellation, DateTime now)
    {
        EnsureNotStarted(now);
        var participant = Require(playerId, ParticipantState.Accepted);
        var late = !exemptFromLateCancellation && IsLate(now);
        Transition(participant, ParticipantState.Left, now);
        RaiseDomainEvent(new ParticipantLeft(Id, HostId, playerId));
        AfterPlayerRemoved();
        return late;
    }

    public void RemoveParticipant(Guid actorId, Guid playerId, DateTime now)
    {
        EnsureHost(actorId);
        EnsureNotStarted(now);
        var participant = ParticipantOf(playerId);
        if (participant is not { State: ParticipantState.Accepted or ParticipantState.Invited or ParticipantState.Requested })
            throw new InvalidAggregateStateException("NOT_A_PARTICIPANT", "این بازیکن در بازی نیست.");
        var wasPlaying = participant.Plays;
        Transition(participant, ParticipantState.Removed, now);
        RaiseDomainEvent(new ParticipantRemoved(Id, playerId));
        if (wasPlaying)
            AfterPlayerRemoved();
    }

    /// <summary>The player's account was suspended, banned or deleted: drop them, or cancel the match they host.</summary>
    public void RemoveForAccount(Guid playerId, DateTime now)
    {
        if (IsFinished || now >= StartsAt)
            return;
        if (playerId == HostId)
        {
            Cancel(HostId, "host unavailable", now);
            return;
        }

        var participant = ParticipantOf(playerId);
        if (participant is not { State: ParticipantState.Accepted or ParticipantState.Invited or ParticipantState.Requested })
            return;
        var wasPlaying = participant.Plays;
        Transition(participant, ParticipantState.Removed, now);
        RaiseDomainEvent(new ParticipantRemoved(Id, playerId));
        if (wasPlaying)
            AfterPlayerRemoved();
    }

    /// <summary>Host cancels before the start. Returns whether it counts as a late cancellation for the host.</summary>
    public bool Cancel(Guid actorId, string? reason, DateTime now)
    {
        EnsureHost(actorId);
        if (IsFinished)
            throw new InvalidAggregateStateException("MATCH_FINISHED", "این بازی تمام شده است.");
        EnsureNotStarted(now);
        var late = actorId == HostId && reason != "host unavailable" && IsLate(now);
        SetStatus(MatchStatus.Cancelled, string.IsNullOrWhiteSpace(reason) ? null : reason.Trim());
        foreach (var pending in _participants.Where(p => p.State is ParticipantState.Requested or ParticipantState.Invited))
            Transition(pending, ParticipantState.Expired, now);
        RaiseDomainEvent(new MatchCancelled(Id, HostId, PlayerIds(), reason));
        return late;
    }

    /// <summary>The start time arrived: stop accepting players, then confirm with 2+ players or expire.</summary>
    public void StartReached(DateTime now)
    {
        if (now < StartsAt || Status is not (MatchStatus.Open or MatchStatus.Pending or MatchStatus.Confirmed))
            return;
        foreach (var pending in _participants.Where(p => p.State is ParticipantState.Requested or ParticipantState.Invited))
            Transition(pending, pending.State == ParticipantState.Requested ? ParticipantState.Declined : ParticipantState.Expired, now);
        if (Status == MatchStatus.Confirmed)
            return;
        if (PlayerCount >= 2)
            Confirm(now);
        else
        {
            SetStatus(MatchStatus.Expired, null);
            RaiseDomainEvent(new MatchExpired(Id, HostId));
        }
    }

    public void EditTerms(Guid actorId, MatchTerms terms, DateTime now)
    {
        EnsureHost(actorId);
        EnsureNotStarted(now);
        if (IsFinished)
            throw new InvalidAggregateStateException("MATCH_FINISHED", "این بازی تمام شده است.");
        ApplyTerms(terms);
    }

    /// <summary>Changing when, where or what is only allowed while nobody else has joined (spec play-posts › Editing a post).</summary>
    public void EditSlot(Guid actorId, MatchSlot slot, int playersBrought, DateTime now)
    {
        EnsureHost(actorId);
        var unchanged = slot.SportId == SportId && slot.Format == Format && slot.VenueId == VenueId && slot.StartsAt == StartsAt
                        && slot.DurationMinutes == DurationMinutes && playersBrought == PlayersBrought;
        if (unchanged)
            return;
        if (_participants.Any(p => p.State == ParticipantState.Accepted))
            throw new InvalidAggregateStateException("SCHEDULE_LOCKED", "بعد از پیوستن بازیکنان، زمان و مکان قابل تغییر نیست. بازی را لغو و دوباره ثبت کنید.");
        if (playersBrought < 0 || playersBrought > slot.Capacity - 2)
            throw new BusinessRuleViolationException("INVALID_PLAYERS_BROUGHT", "تعداد همراهان با ظرفیت بازی جور نیست.");
        PlayersBrought = playersBrought;
        ApplySlot(slot);
    }

    public void RegenerateShareToken(Guid actorId)
    {
        EnsureHost(actorId);
        ShareToken = NewShareToken();
    }

    public bool AcceptsPlayers(DateTime now) => Status == MatchStatus.Open && now < StartsAt && OpenSpots > 0 && HiddenAt is null;

    /// <summary>Set when an admin hid the post: it leaves search and share links, and existing participants keep the match.</summary>
    public DateTime? HiddenAt { get; private set; }

    public void Hide(DateTime now)
    {
        if (Visibility != MatchVisibility.Public)
            throw new InvalidAggregateStateException("NOT_A_POST", "این بازی دعوت خصوصی است.");
        HiddenAt ??= now;
        foreach (var pending in _participants.Where(p => p.State == ParticipantState.Requested))
        {
            Transition(pending, ParticipantState.Declined, now);
            RaiseDomainEvent(new JoinAnswered(Id, pending.PlayerId, Accepted: false));
        }
    }

    public IReadOnlyList<Guid> PlayerIds() => _participants.Where(p => p.Plays).Select(p => p.PlayerId).ToList();

    private void AfterPlayerAdded(DateTime now)
    {
        if (OpenSpots == 0)
            Confirm(now);
    }

    private void AfterPlayerRemoved()
    {
        if (Visibility == MatchVisibility.Public && Status == MatchStatus.Confirmed && OpenSpots > 0)
            SetStatus(MatchStatus.Open, null);
        else if (Visibility == MatchVisibility.Private && Status == MatchStatus.Confirmed && PlayerCount < 2)
            SetStatus(MatchStatus.Pending, null);
    }

    private void Confirm(DateTime now)
    {
        if (Status == MatchStatus.Confirmed)
            return;
        SetStatus(MatchStatus.Confirmed, null);
        foreach (var pending in _participants.Where(p => p.State == ParticipantState.Requested))
        {
            Transition(pending, ParticipantState.Declined, now);
            RaiseDomainEvent(new JoinAnswered(Id, pending.PlayerId, Accepted: false));
        }

        RaiseDomainEvent(new MatchConfirmed(Id, HostId, PlayerIds()));
    }

    private bool IsLate(DateTime now) => Status == MatchStatus.Confirmed && StartsAt - now < LateCancellationWindow;

    private void SetStatus(MatchStatus status, string? reason)
    {
        Status = status;
        if (status == MatchStatus.Cancelled)
            CancelReason = reason;
    }

    private static void Transition(MatchParticipant participant, ParticipantState state, DateTime now)
    {
        participant.State = state;
        participant.RespondedAt = now;
    }

    private MatchParticipant Require(Guid playerId, ParticipantState state) =>
        ParticipantOf(playerId) is { } p && p.State == state
            ? p
            : throw new InvalidAggregateStateException("INVALID_PARTICIPANT_STATE", "این کار در وضعیت فعلی شما در بازی ممکن نیست.");

    private void EnsureHost(Guid actorId)
    {
        if (actorId != HostId)
            throw new InvalidAggregateStateException("NOT_THE_HOST", "فقط میزبان این کار را می‌تواند انجام دهد.");
    }

    private void EnsureAcceptingPlayers(DateTime now)
    {
        if (Status is not (MatchStatus.Open or MatchStatus.Pending) || now >= StartsAt)
            throw new InvalidAggregateStateException("MATCH_CLOSED", "این بازی دیگر بازیکن نمی‌پذیرد.");
    }

    private void EnsureNotStarted(DateTime now)
    {
        if (now >= StartsAt)
            throw new InvalidAggregateStateException("MATCH_STARTED", "این بازی شروع شده است.");
    }

    private static void EnsureMessage(string? message)
    {
        if (message is { Length: > MaxMessageLength })
            throw new BusinessRuleViolationException("MESSAGE_TOO_LONG", $"پیام حداکثر {MaxMessageLength} نویسه است.");
    }

    private void ApplySlot(MatchSlot slot)
    {
        SportId = slot.SportId;
        Format = slot.Format;
        Capacity = slot.Capacity;
        VenueId = slot.VenueId;
        CityId = slot.CityId;
        StartsAt = slot.StartsAt;
        DurationMinutes = slot.DurationMinutes;
        EndsAt = slot.EndsAt;
    }

    private void ApplyTerms(MatchTerms terms)
    {
        MinLevel = terms.MinLevel;
        MaxLevel = terms.MaxLevel;
        PartnerGender = terms.PartnerGender;
        CourtBooked = terms.CourtBooked;
        CostNote = terms.CostNote;
        Description = terms.Description;
    }

    private static string NewShareToken() => Convert.ToHexString(RandomNumberGenerator.GetBytes(12)).ToLowerInvariant();
}

/// <summary>A late cancellation, kept for the reliability tier (spec match-lifecycle › Late cancellations are recorded).</summary>
public sealed class LateCancellation : Entity<Guid>
{
    private LateCancellation() { }

    public Guid PlayerId { get; private set; }
    public Guid MatchId { get; private set; }
    public DateTime RecordedAt { get; private set; }

    public static LateCancellation Record(Guid playerId, Guid matchId, DateTime now) =>
        new() { Id = Guid.NewGuid(), PlayerId = playerId, MatchId = matchId, RecordedAt = now };
}

public sealed record MatchPublished(Guid MatchId, Guid HostId) : DomainEvent;
public sealed record JoinRequested(Guid MatchId, Guid HostId, Guid PlayerId) : DomainEvent;
public sealed record JoinAnswered(Guid MatchId, Guid PlayerId, bool Accepted) : DomainEvent;
public sealed record InvitationSent(Guid MatchId, Guid HostId, Guid PlayerId) : DomainEvent;
public sealed record InvitationAnswered(Guid MatchId, Guid HostId, Guid PlayerId, bool Accepted) : DomainEvent;
public sealed record MatchConfirmed(Guid MatchId, Guid HostId, IReadOnlyList<Guid> PlayerIds) : DomainEvent;
public sealed record MatchCancelled(Guid MatchId, Guid HostId, IReadOnlyList<Guid> PlayerIds, string? Reason) : DomainEvent;
public sealed record MatchExpired(Guid MatchId, Guid HostId) : DomainEvent;
public sealed record ParticipantLeft(Guid MatchId, Guid HostId, Guid PlayerId) : DomainEvent;
public sealed record ParticipantRemoved(Guid MatchId, Guid PlayerId) : DomainEvent;
