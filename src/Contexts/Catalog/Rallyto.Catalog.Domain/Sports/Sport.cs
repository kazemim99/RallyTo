using Rallyto.Core.Domain.Base;
using Rallyto.Core.Domain.Exceptions;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Catalog.Domain.Sports;

public enum CourtSurface
{
    Hard = 1,
    Clay = 2,
    Grass = 3,
    ArtificialGrass = 4,
    Carpet = 5,
    Wood = 6,
    Synthetic = 7,
    Glass = 8,
}

public sealed record SportFormat(PlayFormat Format, int PlayersPerSide)
{
    public int Capacity => PlayersPerSide * 2;
}

public sealed record LevelDescription(LevelTier Tier, string Description);

/// <summary>A racket sport with its play formats and the wording of the five level tiers (spec sport-catalog).</summary>
public sealed class Sport : AggregateRoot<Guid>
{
    private List<SportFormat> _formats = [];
    private List<LevelDescription> _levels = [];

    private Sport() { }

    public string Code { get; private set; } = string.Empty;
    public string NameFa { get; private set; } = string.Empty;
    public string NameEn { get; private set; } = string.Empty;
    public int SortOrder { get; private set; }
    public bool IsActive { get; private set; }
    public int DefaultSessionMinutes { get; private set; }
    public CourtSurface[] Surfaces { get; private set; } = [];

    public IReadOnlyList<SportFormat> Formats => _formats;
    public IReadOnlyList<LevelDescription> Levels => _levels;

    /// <param name="id">A fixed id for seeded sports, so ids are the same in every environment.</param>
    public static Sport Create(string code, string nameFa, string nameEn, int sortOrder, int defaultSessionMinutes,
        IEnumerable<SportFormat> formats, IEnumerable<LevelDescription> levels, IEnumerable<CourtSurface> surfaces, Guid? id = null)
    {
        if (string.IsNullOrWhiteSpace(code) || code.Any(c => !(char.IsAsciiLetterLower(c) || char.IsAsciiDigit(c) || c == '-')))
            throw new BusinessRuleViolationException("INVALID_SPORT_CODE", "کد ورزش فقط حروف کوچک انگلیسی، عدد و خط تیره است.");
        var sport = new Sport { Id = id ?? Guid.NewGuid(), Code = code, IsActive = true };
        sport.Update(nameFa, nameEn, sortOrder, defaultSessionMinutes, levels, surfaces);
        sport.SetFormats(formats);
        return sport;
    }

    public void Update(string nameFa, string nameEn, int sortOrder, int defaultSessionMinutes, IEnumerable<LevelDescription> levels, IEnumerable<CourtSurface> surfaces)
    {
        if (string.IsNullOrWhiteSpace(nameFa) || string.IsNullOrWhiteSpace(nameEn))
            throw new BusinessRuleViolationException("SPORT_NAME_REQUIRED", "نام فارسی و انگلیسی ورزش لازم است.");
        if (defaultSessionMinutes is < 30 or > 240 || defaultSessionMinutes % 30 != 0 && defaultSessionMinutes % 15 != 0)
            throw new BusinessRuleViolationException("INVALID_SESSION_LENGTH", "طول پیش‌فرض جلسه باید بین ۳۰ تا ۲۴۰ دقیقه باشد.");

        var levelList = levels.OrderBy(l => l.Tier).ToList();
        if (levelList.Select(l => l.Tier).Distinct().Count() != 5 || levelList.Any(l => string.IsNullOrWhiteSpace(l.Description)))
            throw new BusinessRuleViolationException("LEVELS_INCOMPLETE", "توضیح هر پنج سطح لازم است.");

        NameFa = nameFa.Trim();
        NameEn = nameEn.Trim();
        SortOrder = sortOrder;
        DefaultSessionMinutes = defaultSessionMinutes;
        _levels = levelList;
        Surfaces = surfaces.Distinct().ToArray();
    }

    public void SetFormats(IEnumerable<SportFormat> formats)
    {
        var list = formats.OrderBy(f => f.Format).ToList();
        if (list.Count == 0 || list.Select(f => f.Format).Distinct().Count() != list.Count || list.Any(f => f.PlayersPerSide is < 1 or > 2))
            throw new BusinessRuleViolationException("INVALID_FORMATS", "دست‌کم یک قالب بازی معتبر لازم است.");
        _formats = list;
    }

    public void Activate() => IsActive = true;

    public void Deactivate() => IsActive = false;

    public bool Allows(PlayFormat format) => _formats.Any(f => f.Format == format);

    public int CapacityOf(PlayFormat format) =>
        _formats.FirstOrDefault(f => f.Format == format)?.Capacity
        ?? throw new BusinessRuleViolationException("FORMAT_NOT_ALLOWED", $"این قالب برای {NameFa} مجاز نیست.");
}
