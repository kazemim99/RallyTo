using Rallyto.Core.Domain.Base;
using Rallyto.Core.Domain.Exceptions;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Community.Domain.Availabilities;

public enum AvailabilityKind
{
    Recurring = 1,
    OneOff = 2,
}

public enum AvailabilityStatus
{
    Active = 1,
    Paused = 2,
    Expired = 3,
}

public sealed record AvailabilityPublished(Guid AvailabilityId, Guid PlayerId, Guid SportId) : DomainEvent;

/// <summary>
/// When and where a player can play one sport (spec availability): weekly or on one date, at 1–3 clubs of one
/// city, in Tehran wall-clock time. Recurring windows must be reconfirmed every 30 days or they pause.
/// </summary>
public sealed class Availability : AggregateRoot<Guid>
{
    public const int MaxVenues = 3;
    public const int MaxActivePerPlayer = 10;
    public const int MaxDaysAhead = 60;
    public static readonly TimeSpan ReconfirmAfter = TimeSpan.FromDays(30);
    public static readonly TimeSpan ReminderAfter = TimeSpan.FromDays(27);

    private List<Guid> _venueIds = [];
    private List<PlayFormat> _formats = [];

    private Availability() { }

    public Guid PlayerId { get; private set; }
    public Guid SportId { get; private set; }
    public int CityId { get; private set; }
    public AvailabilityKind Kind { get; private set; }
    public IranianWeekdays Weekdays { get; private set; }
    public DateOnly? Date { get; private set; }
    public int StartMinute { get; private set; }
    public int EndMinute { get; private set; }
    public string? Note { get; private set; }
    public DateOnly? ValidUntil { get; private set; }
    public AvailabilityStatus Status { get; private set; }
    public DateTime LastConfirmedAt { get; private set; }
    public DateTime? ReminderSentAt { get; private set; }

    public IReadOnlyList<Guid> VenueIds => _venueIds;
    public IReadOnlyList<PlayFormat> Formats => _formats;
    public TimeWindow Window => TimeWindow.Create(StartMinute, EndMinute);

    public static Availability Create(Guid playerId, Guid sportId, int cityId, AvailabilitySchedule schedule, IReadOnlyCollection<Guid> venueIds,
        IReadOnlyCollection<PlayFormat> formats, string? note, DateTime now)
    {
        var availability = new Availability { Id = Guid.NewGuid(), PlayerId = playerId, SportId = sportId, Status = AvailabilityStatus.Active };
        availability.Apply(cityId, schedule, venueIds, formats, note);
        availability.LastConfirmedAt = now;
        availability.RaiseDomainEvent(new AvailabilityPublished(availability.Id, playerId, sportId));
        return availability;
    }

    public void Update(int cityId, AvailabilitySchedule schedule, IReadOnlyCollection<Guid> venueIds, IReadOnlyCollection<PlayFormat> formats, string? note, DateTime now)
    {
        if (Status == AvailabilityStatus.Expired)
            throw new InvalidAggregateStateException("WINDOW_EXPIRED", "این بازه منقضی شده است.");
        Apply(cityId, schedule, venueIds, formats, note);
        Confirm(now);
    }

    public void Pause()
    {
        if (Status == AvailabilityStatus.Active)
            Status = AvailabilityStatus.Paused;
    }

    public void Resume(DateTime now)
    {
        if (Status == AvailabilityStatus.Expired)
            throw new InvalidAggregateStateException("WINDOW_EXPIRED", "این بازه منقضی شده است.");
        if (_venueIds.Count == 0)
            throw new InvalidAggregateStateException("WINDOW_HAS_NO_VENUE", "باشگاهی برای این بازه نمانده است؛ آن را ویرایش کنید.");
        var wasPaused = Status == AvailabilityStatus.Paused;
        Status = AvailabilityStatus.Active;
        Confirm(now);
        if (wasPaused)
            RaiseDomainEvent(new AvailabilityPublished(Id, PlayerId, SportId));
    }

    /// <summary>"Still available": resets the 30-day reconfirmation clock.</summary>
    public void Confirm(DateTime now)
    {
        LastConfirmedAt = now;
        ReminderSentAt = null;
    }

    public bool NeedsReminder(DateTime now) =>
        Kind == AvailabilityKind.Recurring && Status == AvailabilityStatus.Active && ReminderSentAt is null && now - LastConfirmedAt >= ReminderAfter;

    public void MarkReminderSent(DateTime now) => ReminderSentAt = now;

    public bool IsStale(DateTime now) =>
        Kind == AvailabilityKind.Recurring && Status == AvailabilityStatus.Active && now - LastConfirmedAt >= ReconfirmAfter;

    /// <summary>One-off windows expire when they end; recurring ones after their end date.</summary>
    public bool IsOver(DateOnly todayTehran, int nowMinuteTehran) => Kind switch
    {
        AvailabilityKind.OneOff => Date < todayTehran || (Date == todayTehran && EndMinute <= nowMinuteTehran),
        _ => ValidUntil is { } until && until < todayTehran,
    };

    public void Expire() => Status = AvailabilityStatus.Expired;

    /// <summary>A club was hidden: drop it; a window left without clubs pauses (spec availability).</summary>
    public void RemoveVenue(Guid venueId)
    {
        if (!_venueIds.Remove(venueId))
            return;
        if (_venueIds.Count == 0)
            Pause();
    }

    /// <summary>Whether this window and another of the same player would be a duplicate (spec availability › Window limits and duplicates).</summary>
    public bool DuplicatesWith(Guid sportId, IReadOnlyCollection<Guid> venueIds, AvailabilitySchedule schedule) =>
        Status == AvailabilityStatus.Active
        && SportId == sportId
        && _venueIds.Intersect(venueIds).Any()
        && SharesDayWith(schedule)
        && Window.Overlaps(schedule.Window);

    /// <summary>Whether the window applies on a given Tehran date.</summary>
    public bool AppliesOn(DateOnly date) => Kind switch
    {
        AvailabilityKind.OneOff => Date == date,
        _ => Weekdays.HasFlag(IranianWeek.Of(date)) && (ValidUntil is null || date <= ValidUntil),
    };

    private bool SharesDayWith(AvailabilitySchedule other) => (Kind, other.Kind) switch
    {
        (AvailabilityKind.Recurring, AvailabilityKind.Recurring) => (Weekdays & other.Weekdays) != IranianWeekdays.None,
        (AvailabilityKind.Recurring, AvailabilityKind.OneOff) => Weekdays.HasFlag(IranianWeek.Of(other.Date!.Value)),
        (AvailabilityKind.OneOff, AvailabilityKind.Recurring) => other.Weekdays.HasFlag(IranianWeek.Of(Date!.Value)),
        _ => Date == other.Date,
    };

    private void Apply(int cityId, AvailabilitySchedule schedule, IReadOnlyCollection<Guid> venueIds, IReadOnlyCollection<PlayFormat> formats, string? note)
    {
        var venues = venueIds.Distinct().ToList();
        if (venues.Count is 0 or > MaxVenues)
            throw new BusinessRuleViolationException("INVALID_VENUE_COUNT", $"برای هر بازه ۱ تا {MaxVenues} باشگاه انتخاب کنید.");
        if (formats.Count == 0)
            throw new BusinessRuleViolationException("FORMAT_REQUIRED", "دست‌کم یک قالب بازی انتخاب کنید.");
        if (note is { Length: > 200 })
            throw new BusinessRuleViolationException("NOTE_TOO_LONG", "یادداشت حداکثر ۲۰۰ نویسه است.");

        CityId = cityId;
        Kind = schedule.Kind;
        Weekdays = schedule.Weekdays;
        Date = schedule.Date;
        ValidUntil = schedule.ValidUntil;
        StartMinute = schedule.Window.StartMinute;
        EndMinute = schedule.Window.EndMinute;
        _venueIds = venues;
        _formats = formats.Distinct().Order().ToList();
        Note = string.IsNullOrWhiteSpace(note) ? null : note.Trim();
    }
}

/// <summary>The "when" of a window, validated against today's Tehran date and time.</summary>
public sealed record AvailabilitySchedule(AvailabilityKind Kind, IranianWeekdays Weekdays, DateOnly? Date, DateOnly? ValidUntil, TimeWindow Window)
{
    public static AvailabilitySchedule Recurring(IranianWeekdays weekdays, TimeWindow window, DateOnly? validUntil, DateOnly todayTehran)
    {
        if (weekdays == IranianWeekdays.None)
            throw new BusinessRuleViolationException("WEEKDAY_REQUIRED", "دست‌کم یک روز هفته انتخاب کنید.");
        if (validUntil is { } until && until < todayTehran)
            throw new BusinessRuleViolationException("VALID_UNTIL_IN_PAST", "تاریخ پایان باید امروز یا بعد از آن باشد.");
        return new AvailabilitySchedule(AvailabilityKind.Recurring, weekdays, null, validUntil, window);
    }

    public static AvailabilitySchedule OneOff(DateOnly date, TimeWindow window, DateOnly todayTehran, int nowMinuteTehran)
    {
        if (date < todayTehran || (date == todayTehran && window.EndMinute <= nowMinuteTehran))
            throw new BusinessRuleViolationException("WINDOW_IN_PAST", "این بازه گذشته است.");
        if (date > todayTehran.AddDays(Availability.MaxDaysAhead))
            throw new BusinessRuleViolationException("DATE_TOO_FAR", $"حداکثر {Availability.MaxDaysAhead} روز آینده را می‌توانید انتخاب کنید.");
        return new AvailabilitySchedule(AvailabilityKind.OneOff, IranianWeekdays.None, date, null, window);
    }
}
