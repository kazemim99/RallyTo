using System.Reflection;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Rallyto.Catalog.Domain.Locations;
using Rallyto.Catalog.Domain.Sports;
using Rallyto.Core.Domain.SharedKernel;
using Rallyto.Infrastructure.Core.Persistence;

namespace Rallyto.Catalog.Infrastructure.Persistence;

/// <summary>
/// Seeds Iran's provinces and cities (dataset taken from AsanRezerve's ProvinceCity-ParentChild.json) and the four
/// launch sports with their Persian tier wording (spec sport-catalog). Adds only what is missing.
/// </summary>
internal sealed class CatalogSeeder(CatalogDbContext db) : IDataSeeder
{
    public async Task SeedAsync(CancellationToken cancellationToken = default)
    {
        if (!await db.Provinces.AnyAsync(cancellationToken))
            await SeedLocationsAsync(cancellationToken);

        var existing = await db.Sports.Select(s => s.Code).ToListAsync(cancellationToken);
        foreach (var sport in LaunchSports().Where(s => !existing.Contains(s.Code)))
            db.Sports.Add(sport);
        await db.SaveChangesAsync(cancellationToken);
    }

    private async Task SeedLocationsAsync(CancellationToken cancellationToken)
    {
        await using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("Rallyto.Catalog.Infrastructure.Seed.provinces-cities.json")
            ?? throw new InvalidOperationException("Embedded provinces-cities.json is missing.");
        var rows = await JsonSerializer.DeserializeAsync<List<LocationRow>>(stream, cancellationToken: cancellationToken) ?? [];
        foreach (var row in rows.Where(r => r.Type == "Province"))
            db.Provinces.Add(new Province(row.Id, Persian(row.Name)));
        foreach (var row in rows.Where(r => r.Type == "City" && r.ParentId is not null))
            db.Cities.Add(new City(row.Id, row.ParentId!.Value, Persian(row.Name)));
        await db.SaveChangesAsync(cancellationToken);
    }

    /// <summary>The dataset mixes Arabic kaf and yeh into some names (for example «كرمان»).</summary>
    private static string Persian(string name) => name.Replace('ك', 'ک').Replace('ي', 'ی').Trim();

    private static IEnumerable<Sport> LaunchSports()
    {
        yield return Sport.Create("tennis", "تنیس", "Tennis", 1, 90,
            [new SportFormat(PlayFormat.Singles, 1), new SportFormat(PlayFormat.Doubles, 2)],
            Levels(
                "تازه شروع کرده‌اید؛ ضربه‌های پایه و رالی‌های کوتاه را تمرین می‌کنید.",
                "فورهند و بک‌هند را می‌زنید و رالی چندضربه‌ای دارید، اما ثبات و جهت توپ هنوز کامل نیست.",
                "رالی پایدار با سرعت متوسط، سرویس قابل اتکا و آشنایی با بازی تور و حرکت در زمین.",
                "کنترل جهت، عمق و اسپین؛ سرویس قوی و بازی تاکتیکی در مسابقه.",
                "سابقهٔ مسابقات رسمی یا مربیگری؛ تسلط کامل بر همهٔ ضربه‌ها و تاکتیک‌ها."),
            [CourtSurface.Hard, CourtSurface.Clay, CourtSurface.Grass, CourtSurface.ArtificialGrass, CourtSurface.Carpet], SeededIds.Tennis);

        yield return Sport.Create("padel", "پدل", "Padel", 2, 90,
            [new SportFormat(PlayFormat.Doubles, 2)],
            Levels(
                "با قوانین و دیوارها تازه آشنا شده‌اید و توپ را بیشتر از روی زمین برمی‌گردانید.",
                "بازی با دیوار پشتی را شروع کرده‌اید و رالی‌های کوتاه دارید.",
                "از دیوارها استفاده می‌کنید، والی و لوب قابل اتکا دارید و جای‌گیری دونفره را می‌دانید.",
                "باندخا و ویبورا می‌زنید و بازی را با تاکتیک دونفره کنترل می‌کنید.",
                "سابقهٔ مسابقات رسمی؛ تسلط بر همهٔ ضربه‌ها از جمله اسمش‌های پیشرفته."),
            [CourtSurface.ArtificialGrass, CourtSurface.Glass], SeededIds.Padel);

        yield return Sport.Create("badminton", "بدمینتون", "Badminton", 3, 60,
            [new SportFormat(PlayFormat.Singles, 1), new SportFormat(PlayFormat.Doubles, 2)],
            Levels(
                "ضربه‌های پایه و سرویس را یاد می‌گیرید و رالی کوتاه دارید.",
                "کلیر و دراپ ساده می‌زنید اما حرکت پا و ثبات هنوز کامل نیست.",
                "رالی پایدار، اسمش و دراپ قابل اتکا و حرکت پای مناسب در زمین.",
                "بازی سریع و تاکتیکی، فریب در ضربه‌ها و دفاع خوب در برابر اسمش.",
                "سابقهٔ مسابقات رسمی؛ سرعت و دقت بالا در همهٔ ضربه‌ها."),
            [CourtSurface.Wood, CourtSurface.Synthetic], SeededIds.Badminton);

        yield return Sport.Create("squash", "اسکواش", "Squash", 4, 60,
            [new SportFormat(PlayFormat.Singles, 1)],
            Levels(
                "با زمین و دیوارها تازه آشنا شده‌اید و توپ را به دیوار جلو برمی‌گردانید.",
                "درایو و سرویس ساده می‌زنید و رالی‌های چندضربه‌ای دارید.",
                "کنترل عمق، بوست و دراپ؛ برگشتن به وسط زمین را رعایت می‌کنید.",
                "ضربه‌های دقیق در گوشه‌ها، تغییر ریتم و آمادگی جسمانی بالا.",
                "سابقهٔ مسابقات رسمی؛ تسلط کامل بر همهٔ ضربه‌ها و تاکتیک‌ها."),
            [CourtSurface.Wood], SeededIds.Squash);
    }

    private static IEnumerable<LevelDescription> Levels(params string[] descriptions) =>
        descriptions.Select((d, i) => new LevelDescription((LevelTier)(i + 1), d));

    /// <summary>Fixed ids of the launch sports, identical in every environment.</summary>
    public static class SeededIds
    {
        public static readonly Guid Tennis = new("5e1a0001-0000-4000-8000-000000000001");
        public static readonly Guid Padel = new("5e1a0001-0000-4000-8000-000000000002");
        public static readonly Guid Badminton = new("5e1a0001-0000-4000-8000-000000000003");
        public static readonly Guid Squash = new("5e1a0001-0000-4000-8000-000000000004");
    }

    private sealed record LocationRow(int Id, string Name, int? ParentId, string Type);
}
