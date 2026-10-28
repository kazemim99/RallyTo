using System.Globalization;

namespace Rallyto.Core.Application.Localization;

/// <summary>
/// Jalali dates and Persian digits in Asia/Tehran, for text that reaches users (errors, notifications).
/// Iran has used a fixed UTC+03:30 since 2022; the time zone is still resolved so a tzdata change is enough.
/// </summary>
public static class PersianFormat
{
    private static readonly PersianCalendar Calendar = new();

    public static readonly TimeZoneInfo Tehran = ResolveTehran();

    public static DateTime ToTehran(DateTime utc) =>
        TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(utc, DateTimeKind.Utc), Tehran);

    /// <summary>For example <c>۱۴۰۵/۰۹/۰۱</c>.</summary>
    public static string Date(DateTime utc)
    {
        var local = ToTehran(utc);
        return Digits($"{Calendar.GetYear(local):0000}/{Calendar.GetMonth(local):00}/{Calendar.GetDayOfMonth(local):00}");
    }

    /// <summary>For example <c>۱۹:۰۰</c>.</summary>
    public static string Time(DateTime utc) => Digits(ToTehran(utc).ToString("HH:mm", CultureInfo.InvariantCulture));

    /// <summary>Today's date in Tehran.</summary>
    public static DateOnly TehranToday(DateTime utcNow) => DateOnly.FromDateTime(ToTehran(utcNow));

    /// <summary>Parses a Jalali date such as <c>1375/05/10</c> (Persian digits allowed) into a Gregorian date.</summary>
    public static bool TryParseJalali(string? text, out DateOnly date)
    {
        date = default;
        var parts = ToAsciiDigits(text ?? string.Empty).Trim().Split('/', '-');
        if (parts.Length != 3
            || !int.TryParse(parts[0], NumberStyles.None, CultureInfo.InvariantCulture, out var year)
            || !int.TryParse(parts[1], NumberStyles.None, CultureInfo.InvariantCulture, out var month)
            || !int.TryParse(parts[2], NumberStyles.None, CultureInfo.InvariantCulture, out var day))
            return false;
        try
        {
            date = DateOnly.FromDateTime(Calendar.ToDateTime(year, month, day, 0, 0, 0, 0));
            return true;
        }
        catch (ArgumentOutOfRangeException)
        {
            return false;
        }
    }

    /// <summary>A Gregorian date as Jalali with ASCII digits, for example <c>1375/05/10</c> (for APIs, not display).</summary>
    public static string JalaliAscii(DateOnly date)
    {
        var d = date.ToDateTime(TimeOnly.MinValue);
        return $"{Calendar.GetYear(d):0000}/{Calendar.GetMonth(d):00}/{Calendar.GetDayOfMonth(d):00}";
    }

    public static string Digits(string text) =>
        string.Create(text.Length, text, (span, source) =>
        {
            for (var i = 0; i < source.Length; i++)
                span[i] = source[i] is >= '0' and <= '9' ? (char)('۰' + (source[i] - '0')) : source[i];
        });

    /// <summary>Converts Persian (۰-۹) and Arabic-Indic (٠-٩) digits to ASCII; everything else is left alone.</summary>
    public static string ToAsciiDigits(string text) =>
        string.Create(text.Length, text, (span, source) =>
        {
            for (var i = 0; i < source.Length; i++)
            {
                var c = source[i];
                span[i] = c switch
                {
                    >= '۰' and <= '۹' => (char)('0' + (c - '۰')),
                    >= '٠' and <= '٩' => (char)('0' + (c - '٠')),
                    _ => c,
                };
            }
        });

    private static TimeZoneInfo ResolveTehran()
    {
        foreach (var id in new[] { "Asia/Tehran", "Iran Standard Time" })
        {
            if (TimeZoneInfo.TryFindSystemTimeZoneById(id, out var zone))
                return zone;
        }

        return TimeZoneInfo.CreateCustomTimeZone("Asia/Tehran", TimeSpan.FromMinutes(210), "Tehran", "Tehran");
    }
}
