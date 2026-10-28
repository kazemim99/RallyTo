using Rallyto.Core.Application.Localization;

namespace Rallyto.BuildingBlocks.UnitTests;

public sealed class PersianFormatTests
{
    [Fact]
    public void Today_is_1405_08_01()
    {
        PersianFormat.Date(new DateTime(2026, 10, 23, 9, 0, 0, DateTimeKind.Utc)).Should().Be("۱۴۰۵/۰۸/۰۱");
    }

    [Fact]
    public void Date_uses_tehran_time_not_utc()
    {
        // 21:00 UTC is already 00:30 the next day in Tehran (UTC+03:30).
        PersianFormat.Date(new DateTime(2026, 10, 23, 21, 0, 0, DateTimeKind.Utc)).Should().Be("۱۴۰۵/۰۸/۰۲");
        PersianFormat.Time(new DateTime(2026, 10, 23, 15, 30, 0, DateTimeKind.Utc)).Should().Be("۱۹:۰۰");
    }

    [Fact]
    public void Digits_convert_both_ways()
    {
        PersianFormat.Digits("1405/09/01").Should().Be("۱۴۰۵/۰۹/۰۱");
        PersianFormat.ToAsciiDigits("۱۲۳٤٥٦abc").Should().Be("123456abc");
    }
}
