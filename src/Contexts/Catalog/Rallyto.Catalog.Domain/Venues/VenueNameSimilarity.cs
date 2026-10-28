using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Catalog.Domain.Venues;

/// <summary>
/// Decides whether two club names in the same city probably mean the same club, so an admin sees the existing one
/// before adding another (spec venue-catalog). Generic words such as «باشگاه» or «تنیس» are ignored.
/// </summary>
public static class VenueNameSimilarity
{
    private static readonly HashSet<string> GenericWords = new(StringComparer.Ordinal)
    {
        "باشگاه", "مجموعه", "ورزشی", "ورزش", "تنیس", "پدل", "بدمینتون", "اسکواش", "سالن", "زمین", "زمینهای", "کلوپ",
        "کلاب", "مرکز", "آکادمی", "اکادمی", "خانه", "club", "tennis", "padel", "squash", "badminton", "sport", "sports", "center", "academy",
    };

    public static bool AreSimilar(string a, string b)
    {
        var left = DistinctiveWords(a);
        var right = DistinctiveWords(b);
        if (left.Count == 0 || right.Count == 0)
            return PersianText.Normalize(a) == PersianText.Normalize(b);
        return left.Overlaps(right);
    }

    public static HashSet<string> DistinctiveWords(string name) =>
        PersianText.Normalize(name)
            .Split(' ', StringSplitOptions.RemoveEmptyEntries)
            .Where(w => w.Length > 1 && !GenericWords.Contains(w))
            .ToHashSet(StringComparer.Ordinal);
}
