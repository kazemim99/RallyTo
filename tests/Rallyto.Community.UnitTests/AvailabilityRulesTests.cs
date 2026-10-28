using Rallyto.Community.Domain.Availabilities;
using Rallyto.Core.Domain.Exceptions;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Community.UnitTests;

public sealed class TimeWindowTests
{
    [Theory]
    [InlineData("18:00", "24:00", 1080, 1440)]
    [InlineData("06:30", "08:00", 390, 480)]
    public void Valid_windows(string start, string end, int startMinute, int endMinute)
    {
        var window = TimeWindow.Parse(start, end);
        window.StartMinute.Should().Be(startMinute);
        window.EndMinute.Should().Be(endMinute);
    }

    [Theory]
    [InlineData("18:00", "18:30", "WINDOW_TOO_SHORT")]
    [InlineData("22:00", "02:00", "WINDOW_CROSSES_MIDNIGHT")]
    [InlineData("18:15", "20:00", "INVALID_TIME_STEP")]
    [InlineData("24:00", "24:00", "INVALID_TIME")]
    [InlineData("25:00", "26:00", "INVALID_TIME")]
    [InlineData("ab", "20:00", "INVALID_TIME")]
    public void Invalid_windows(string start, string end, string code)
    {
        var parse = () => TimeWindow.Parse(start, end);
        parse.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be(code);
    }

    [Theory]
    [InlineData("18:00", "24:00", "20:00", "22:00", 120)]
    [InlineData("18:00", "24:00", "23:00", "24:00", 60)]
    [InlineData("18:00", "20:00", "20:00", "22:00", 0)]
    [InlineData("08:00", "11:00", "10:00", "12:00", 60)]
    public void Overlap_minutes(string s1, string e1, string s2, string e2, int expected) =>
        TimeWindow.Parse(s1, e1).OverlapMinutes(TimeWindow.Parse(s2, e2)).Should().Be(expected);

    [Fact]
    public void Iranian_week_starts_on_saturday()
    {
        IranianWeek.Of(new DateOnly(2026, 10, 24)).Should().Be(IranianWeekdays.Saturday); // 1405/08/02
        IranianWeek.Of(new DateOnly(2026, 10, 23)).Should().Be(IranianWeekdays.Friday);   // 1405/08/01
        IranianWeek.Ordered.First().Should().Be(IranianWeekdays.Saturday);
    }
}

public sealed class AvailabilityRulesTests
{
    private static readonly DateOnly Today = new(2026, 10, 23);
    private static readonly DateTime Now = new(2026, 10, 23, 9, 0, 0, DateTimeKind.Utc);
    private static readonly Guid Tennis = Guid.NewGuid();
    private static readonly Guid Esteghlal = Guid.NewGuid();
    private static readonly Guid Enghelab = Guid.NewGuid();

    private static Availability SaturdayEvening() => Availability.Create(Guid.NewGuid(), Tennis, 428,
        AvailabilitySchedule.Recurring(IranianWeekdays.Saturday | IranianWeekdays.Monday, TimeWindow.Parse("18:00", "24:00"), null, Today),
        [Esteghlal], [PlayFormat.Singles], null, Now);

    [Fact]
    public void A_weekday_window_applies_on_matching_dates_only()
    {
        var window = SaturdayEvening();
        window.AppliesOn(new DateOnly(2026, 10, 24)).Should().BeTrue();  // Saturday
        window.AppliesOn(new DateOnly(2026, 10, 25)).Should().BeFalse(); // Sunday
    }

    [Fact]
    public void Same_sport_venue_day_and_overlapping_time_is_a_duplicate()
    {
        var window = SaturdayEvening();
        var schedule = AvailabilitySchedule.Recurring(IranianWeekdays.Saturday, TimeWindow.Parse("20:00", "22:00"), null, Today);

        window.DuplicatesWith(Tennis, [Esteghlal], schedule).Should().BeTrue();
        window.DuplicatesWith(Tennis, [Enghelab], schedule).Should().BeFalse();
        window.DuplicatesWith(Guid.NewGuid(), [Esteghlal], schedule).Should().BeFalse();
    }

    [Fact]
    public void A_one_off_on_a_covered_weekday_duplicates_a_recurring_window()
    {
        var window = SaturdayEvening();
        var oneOff = AvailabilitySchedule.OneOff(new DateOnly(2026, 10, 24), TimeWindow.Parse("19:00", "21:00"), Today, 750);

        window.DuplicatesWith(Tennis, [Esteghlal], oneOff).Should().BeTrue();
    }

    [Fact]
    public void Reminder_on_day_27_and_stale_on_day_30()
    {
        var window = SaturdayEvening();

        window.NeedsReminder(Now.AddDays(26)).Should().BeFalse();
        window.NeedsReminder(Now.AddDays(27)).Should().BeTrue();
        window.IsStale(Now.AddDays(29)).Should().BeFalse();
        window.IsStale(Now.AddDays(30)).Should().BeTrue();

        window.Confirm(Now.AddDays(28));
        window.IsStale(Now.AddDays(30)).Should().BeFalse();
    }

    [Fact]
    public void Removing_the_last_venue_pauses_the_window()
    {
        var window = SaturdayEvening();

        window.RemoveVenue(Esteghlal);

        window.Status.Should().Be(AvailabilityStatus.Paused);
    }

    [Fact]
    public void One_off_window_is_over_once_it_ends()
    {
        var window = Availability.Create(Guid.NewGuid(), Tennis, 428,
            AvailabilitySchedule.OneOff(Today, TimeWindow.Parse("18:00", "20:00"), Today, 750), [Esteghlal], [PlayFormat.Singles], null, Now);

        window.IsOver(Today, 1199).Should().BeFalse();
        window.IsOver(Today, 1200).Should().BeTrue();
        window.IsOver(Today.AddDays(1), 0).Should().BeTrue();
    }
}
