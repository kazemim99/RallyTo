using Rallyto.Core.Domain.Base;
using Rallyto.Core.Domain.Exceptions;

namespace Rallyto.Community.Domain.Matches;

public enum AttendanceAnswer
{
    Played = 1,
    DidNotHappen = 2,
}

/// <summary>What a participant's attendance counted as in a Completed match.</summary>
public enum AttendanceOutcome
{
    Played = 1,
    NoShow = 2,
    Contested = 3,
}

public sealed record AttendanceInput(Guid PlayerId, AttendanceAnswer? Answer, IReadOnlyCollection<Guid> NoShowFlags);

/// <summary>Outcomes are set only for a Completed match; Disputed and Unconfirmed have none.</summary>
public sealed record AttendanceResolution(MatchStatus Status, IReadOnlyDictionary<Guid, AttendanceOutcome> Outcomes);

/// <summary>The attendance rules of spec match-lifecycle › Attendance confirmation, as one pure function.</summary>
public static class AttendanceResolutionPolicy
{
    public static AttendanceResolution Resolve(IReadOnlyCollection<AttendanceInput> participants)
    {
        var anyPlayed = participants.Any(p => p.Answer == AttendanceAnswer.Played);
        var anyNotHappened = participants.Any(p => p.Answer == AttendanceAnswer.DidNotHappen);
        if (anyPlayed && anyNotHappened)
            return new AttendanceResolution(MatchStatus.Disputed, new Dictionary<Guid, AttendanceOutcome>());
        if (!anyPlayed)
            return new AttendanceResolution(MatchStatus.Unconfirmed, new Dictionary<Guid, AttendanceOutcome>());

        var flagged = participants.SelectMany(p => p.NoShowFlags.Where(f => f != p.PlayerId)).ToHashSet();
        var outcomes = participants.ToDictionary(p => p.PlayerId, p => !flagged.Contains(p.PlayerId)
            ? AttendanceOutcome.Played
            : p.Answer == AttendanceAnswer.Played ? AttendanceOutcome.Contested : AttendanceOutcome.NoShow);
        return new AttendanceResolution(MatchStatus.Completed, outcomes);
    }
}

public sealed partial class Match
{
    public static readonly TimeSpan AttendanceWindow = TimeSpan.FromHours(72);
    public static readonly TimeSpan RatingWindow = TimeSpan.FromDays(7);
    public static readonly TimeSpan RatingReminderAfter = TimeSpan.FromDays(5);

    public DateTime? AttendanceOpenedAt { get; private set; }
    public DateTime? ResolvedAt { get; private set; }
    public DateTime? RatingRemindersSentAt { get; private set; }

    public DateTime AttendanceClosesAt => EndsAt + AttendanceWindow;

    public DateTime? RatingClosesAt => Status == MatchStatus.Completed ? ResolvedAt + RatingWindow : null;

    public bool IsAttendanceOpen(DateTime now) => Status == MatchStatus.Confirmed && now >= EndsAt && now < AttendanceClosesAt;

    /// <summary>The game ended: ask its players whether it was played (once).</summary>
    public void OpenAttendance(DateTime now)
    {
        if (Status != MatchStatus.Confirmed || now < EndsAt || AttendanceOpenedAt is not null)
            return;
        AttendanceOpenedAt = now;
        RaiseDomainEvent(new AttendanceOpened(Id, PlayerIds()));
    }

    public void AnswerAttendance(Guid playerId, AttendanceAnswer answer, IReadOnlyCollection<Guid> noShows, DateTime now)
    {
        if (Status != MatchStatus.Confirmed || now < EndsAt)
            throw new InvalidAggregateStateException("ATTENDANCE_NOT_OPEN", "پرسش حضور بعد از پایان بازی باز می‌شود.");
        if (now >= AttendanceClosesAt)
            throw new InvalidAggregateStateException("ATTENDANCE_CLOSED", "مهلت اعلام حضور تمام شده است.");
        var participant = ParticipantOf(playerId);
        if (participant is not { Plays: true })
            throw new InvalidAggregateStateException("NOT_A_PARTICIPANT", "شما بازیکن این بازی نیستید.");
        if (participant.Attendance is not null)
            throw new InvalidAggregateStateException("ALREADY_ANSWERED", "قبلاً حضور را اعلام کرده‌اید.");
        var flagged = noShows.Distinct().ToList();
        var players = PlayerIds();
        if (flagged.Count > 0 && (answer != AttendanceAnswer.Played || flagged.Any(f => f == playerId || !players.Contains(f))))
            throw new BusinessRuleViolationException("INVALID_NO_SHOW", "غایب فقط از میان بازیکنان دیگرِ بازیِ انجام‌شده انتخاب می‌شود.");

        OpenAttendance(now);
        participant.Attendance = answer;
        participant.NoShowFlags = flagged;
        participant.AnsweredAt = now;
        if (_participants.Where(p => p.Plays).All(p => p.Attendance is not null))
            Resolve(now);
    }

    /// <summary>The 72-hour window closed: resolve with the answers given so far.</summary>
    public void CloseAttendance(DateTime now)
    {
        if (Status == MatchStatus.Confirmed && now >= AttendanceClosesAt)
            Resolve(now);
    }

    /// <summary>Both players were Played in this Completed match, and its 7-day rating window is open (spec player-ratings).</summary>
    public void EnsureCanRate(Guid raterId, Guid rateeId, DateTime now)
    {
        if (raterId == rateeId)
            throw new BusinessRuleViolationException("CANNOT_RATE_SELF", "نمی‌توانید به خودتان امتیاز بدهید.");
        if (Status != MatchStatus.Completed
            || ParticipantOf(raterId)?.Outcome != AttendanceOutcome.Played
            || ParticipantOf(rateeId)?.Outcome != AttendanceOutcome.Played)
            throw new InvalidAggregateStateException("RATING_NOT_ALLOWED", "امتیازدادن برای این بازیکن در این بازی ممکن نیست.");
        if (now > RatingClosesAt)
            throw new InvalidAggregateStateException("RATING_WINDOW_CLOSED", "مهلت امتیازدادن به این بازی تمام شده است.");
    }

    /// <summary>The Played participants other than <paramref name="raterId"/>, when the rater may rate at all.</summary>
    public IReadOnlyList<Guid> RateablePartnersOf(Guid raterId, DateTime now) =>
        Status == MatchStatus.Completed && now <= RatingClosesAt && ParticipantOf(raterId)?.Outcome == AttendanceOutcome.Played
            ? _participants.Where(p => p.PlayerId != raterId && p.Outcome == AttendanceOutcome.Played).Select(p => p.PlayerId).ToList()
            : [];

    /// <summary>Marks the day-5 reminder as sent; returns false when it was sent already or is not due.</summary>
    public bool MarkRatingRemindersSent(DateTime now)
    {
        if (Status != MatchStatus.Completed || RatingRemindersSentAt is not null || now < ResolvedAt + RatingReminderAfter)
            return false;
        RatingRemindersSentAt = now;
        return true;
    }

    private void Resolve(DateTime now)
    {
        var playing = _participants.Where(p => p.Plays).ToList();
        var result = AttendanceResolutionPolicy.Resolve(playing.Select(p => new AttendanceInput(p.PlayerId, p.Attendance, p.NoShowFlags)).ToList());
        Status = result.Status;
        ResolvedAt = now;
        foreach (var participant in playing)
            participant.Outcome = result.Outcomes.TryGetValue(participant.PlayerId, out var outcome) ? outcome : null;
        RaiseDomainEvent(new MatchResolved(Id, SportId, Status,
            playing.Where(p => p.Outcome == AttendanceOutcome.Played).Select(p => p.PlayerId).ToList(),
            playing.Where(p => p.Outcome == AttendanceOutcome.NoShow).Select(p => p.PlayerId).ToList()));
    }
}

public sealed record AttendanceOpened(Guid MatchId, IReadOnlyList<Guid> PlayerIds) : DomainEvent;
public sealed record MatchResolved(Guid MatchId, Guid SportId, MatchStatus Status, IReadOnlyList<Guid> PlayedIds, IReadOnlyList<Guid> NoShowIds) : DomainEvent;
