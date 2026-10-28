using System.Globalization;
using Rallyto.Core.Domain.Base;
using Rallyto.Core.Domain.Exceptions;

namespace Rallyto.Community.Domain.Availabilities;

/// <summary>
/// A span of Tehran wall-clock time within one day, in minutes from midnight (spec availability): 30-minute steps,
/// at least 60 minutes, ending at or before 24:00, never crossing midnight.
/// </summary>
public sealed class TimeWindow : ValueObject
{
    public const int Step = 30;
    public const int MinimumLength = 60;
    public const int EndOfDay = 24 * 60;

    private TimeWindow(int startMinute, int endMinute)
    {
        StartMinute = startMinute;
        EndMinute = endMinute;
    }

    public int StartMinute { get; }
    public int EndMinute { get; }
    public int Length => EndMinute - StartMinute;

    public static TimeWindow Create(int startMinute, int endMinute)
    {
        if (startMinute is < 0 or >= EndOfDay || endMinute is <= 0 or > EndOfDay)
            throw new BusinessRuleViolationException("INVALID_TIME", "ساعت واردشده معتبر نیست.");
        if (endMinute <= startMinute)
            throw new BusinessRuleViolationException("WINDOW_CROSSES_MIDNIGHT", "بازه نباید از نیمه‌شب بگذرد؛ آن را به دو بازه تقسیم کنید.");
        if (startMinute % Step != 0 || endMinute % Step != 0)
            throw new BusinessRuleViolationException("INVALID_TIME_STEP", "ساعت‌ها باید مضرب ۳۰ دقیقه باشند.");
        if (endMinute - startMinute < MinimumLength)
            throw new BusinessRuleViolationException("WINDOW_TOO_SHORT", "هر بازه دست‌کم ۶۰ دقیقه است.");
        return new TimeWindow(startMinute, endMinute);
    }

    /// <summary>Parses <c>HH:mm</c>; <c>24:00</c> is allowed as an end.</summary>
    public static TimeWindow Parse(string start, string end) => Create(ParseMinute(start), ParseMinute(end));

    public static int ParseMinute(string? text)
    {
        var parts = (text ?? string.Empty).Trim().Split(':');
        if (parts.Length != 2
            || !int.TryParse(parts[0], NumberStyles.None, CultureInfo.InvariantCulture, out var hours)
            || !int.TryParse(parts[1], NumberStyles.None, CultureInfo.InvariantCulture, out var minutes)
            || hours is < 0 or > 24 || minutes is < 0 or > 59 || (hours == 24 && minutes != 0))
            throw new BusinessRuleViolationException("INVALID_TIME", "ساعت واردشده معتبر نیست.");
        return hours * 60 + minutes;
    }

    public static string Format(int minute) => $"{minute / 60:00}:{minute % 60:00}";

    public int OverlapMinutes(TimeWindow other) =>
        Math.Max(0, Math.Min(EndMinute, other.EndMinute) - Math.Max(StartMinute, other.StartMinute));

    public bool Overlaps(TimeWindow other) => OverlapMinutes(other) > 0;

    public override string ToString() => $"{Format(StartMinute)}–{Format(EndMinute)}";

    protected override IEnumerable<object?> GetAtomicValues()
    {
        yield return StartMinute;
        yield return EndMinute;
    }
}

/// <summary>Days of the Iranian week, Saturday first.</summary>
[Flags]
public enum IranianWeekdays
{
    None = 0,
    Saturday = 1,
    Sunday = 2,
    Monday = 4,
    Tuesday = 8,
    Wednesday = 16,
    Thursday = 32,
    Friday = 64,
}

public static class IranianWeek
{
    public static readonly IranianWeekdays[] Ordered =
    [
        IranianWeekdays.Saturday, IranianWeekdays.Sunday, IranianWeekdays.Monday, IranianWeekdays.Tuesday,
        IranianWeekdays.Wednesday, IranianWeekdays.Thursday, IranianWeekdays.Friday,
    ];

    public static IranianWeekdays Of(DateOnly date) => date.DayOfWeek switch
    {
        DayOfWeek.Saturday => IranianWeekdays.Saturday,
        DayOfWeek.Sunday => IranianWeekdays.Sunday,
        DayOfWeek.Monday => IranianWeekdays.Monday,
        DayOfWeek.Tuesday => IranianWeekdays.Tuesday,
        DayOfWeek.Wednesday => IranianWeekdays.Wednesday,
        DayOfWeek.Thursday => IranianWeekdays.Thursday,
        _ => IranianWeekdays.Friday,
    };

    public static IEnumerable<IranianWeekdays> Split(IranianWeekdays days) => Ordered.Where(d => days.HasFlag(d));
}
