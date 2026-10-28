using System.Text;

namespace Rallyto.Core.Domain.SharedKernel;

/// <summary>
/// Normalises Persian text for matching (spec venue-catalog › Venue listing and search): Arabic yeh and kaf become
/// Persian, the zero-width non-joiner and tatweel are removed, digits become ASCII and whitespace collapses.
/// </summary>
public static class PersianText
{
    public static string Normalize(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return string.Empty;

        var builder = new StringBuilder(text.Length);
        var lastWasSpace = false;
        foreach (var raw in text.Trim())
        {
            var c = raw switch
            {
                'ي' or 'ى' => 'ی',
                'ك' => 'ک',
                'ة' => 'ه',
                'أ' or 'إ' or 'آ' => 'ا',
                >= '۰' and <= '۹' => (char)('0' + (raw - '۰')),
                >= '٠' and <= '٩' => (char)('0' + (raw - '٠')),
                _ => char.ToLowerInvariant(raw),
            };

            if (c is '‌' or '‍' or 'ـ' || char.GetUnicodeCategory(c) == System.Globalization.UnicodeCategory.NonSpacingMark)
                continue;

            if (char.IsWhiteSpace(c))
            {
                if (!lastWasSpace)
                    builder.Append(' ');
                lastWasSpace = true;
                continue;
            }

            builder.Append(c);
            lastWasSpace = false;
        }

        return builder.ToString().Trim();
    }
}
