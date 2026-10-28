using System.Text.RegularExpressions;
using Rallyto.Core.Domain.Base;
using Rallyto.Core.Domain.Exceptions;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Community.Domain.Players;

public enum Gender
{
    Male = 1,
    Female = 2,
}

public enum ProfileVisibility
{
    Everyone = 1,
    SameGender = 2,
}

/// <summary>Mirrors the account's status: a suspended or banned account's profile is hidden; a deleted one is anonymised.</summary>
public enum ProfileStatus
{
    Active = 1,
    Hidden = 2,
    Deleted = 3,
}

public enum ExperienceBand
{
    UnderSixMonths = 1,
    SixToTwelveMonths = 2,
    OneToThreeYears = 3,
    ThreeToFiveYears = 4,
    OverFiveYears = 5,
}

[Flags]
public enum PlayGoals
{
    None = 0,
    RallyPractice = 1,
    FriendlyMatch = 2,
    Competitive = 4,
    Fitness = 8,
}

public enum AgeRange
{
    From18To24 = 1,
    From25To34 = 2,
    From35To44 = 3,
    From45To54 = 4,
    From55 = 5,
}

/// <summary>One sport a player plays: self-declared tier, experience, preferred formats and goals (spec player-profile).</summary>
public sealed record SportProfile(Guid SportId, LevelTier Level, ExperienceBand Experience, IReadOnlyList<PlayFormat> Formats, PlayGoals Goals);

public sealed record ProfileCreated(Guid UserId) : DomainEvent;

/// <summary>
/// A player's public identity (spec player-profile). The id is the account id. No phone number and no location:
/// players are matched by city, club and time.
/// </summary>
public sealed partial class PlayerProfile : AggregateRoot<Guid>
{
    public const int MaxHomeVenues = 5;
    public const string DeletedDisplayName = "کاربر حذف‌شده";

    private List<SportProfile> _sports = [];
    private List<Guid> _homeVenueIds = [];

    private PlayerProfile() { }

    public string DisplayName { get; private set; } = string.Empty;
    public Gender Gender { get; private set; }
    public DateOnly? BirthDate { get; private set; }
    public int CityId { get; private set; }
    public string? Bio { get; private set; }
    public string? PhotoKey { get; private set; }
    public ProfileVisibility Visibility { get; private set; }
    public ProfileStatus Status { get; private set; }
    public DateTime JoinedAt { get; private set; }
    public DateTime LastActiveAt { get; private set; }

    public IReadOnlyList<SportProfile> Sports => _sports;
    public IReadOnlyList<Guid> HomeVenueIds => _homeVenueIds;

    public static PlayerProfile Create(Guid userId, string displayName, Gender gender, DateOnly birthDate, DateOnly todayInTehran,
        int cityId, string? bio, IReadOnlyList<SportProfile> sports, DateTime now)
    {
        if (AgeOn(birthDate, todayInTehran) < 18)
            throw new BusinessRuleViolationException("UNDER_18", "برای استفاده از رالیتو باید دست‌کم ۱۸ سال داشته باشید.");
        if (sports.Count == 0)
            throw new BusinessRuleViolationException("SPORT_PROFILE_REQUIRED", "دست‌کم یک ورزش انتخاب کنید.");
        if (!Enum.IsDefined(gender))
            throw new BusinessRuleViolationException("GENDER_REQUIRED", "جنسیت را انتخاب کنید.");

        var profile = new PlayerProfile
        {
            Id = userId,
            Gender = gender,
            BirthDate = birthDate,
            Visibility = ProfileVisibility.Everyone,
            Status = ProfileStatus.Active,
            JoinedAt = now,
            LastActiveAt = now,
        };
        profile.UpdateDetails(displayName, cityId, bio);
        foreach (var sport in sports)
            profile.SetSportProfile(sport);
        profile.RaiseDomainEvent(new ProfileCreated(userId));
        return profile;
    }

    public void UpdateDetails(string displayName, int cityId, string? bio)
    {
        var name = (displayName ?? string.Empty).Trim();
        if (!DisplayNamePattern().IsMatch(name))
            throw new BusinessRuleViolationException("INVALID_DISPLAY_NAME", "نام نمایشی باید ۲ تا ۳۰ نویسه و فقط حرف، عدد و فاصله باشد.");
        if (bio is { Length: > 300 })
            throw new BusinessRuleViolationException("BIO_TOO_LONG", "معرفی حداکثر ۳۰۰ نویسه است.");
        DisplayName = name;
        CityId = cityId;
        Bio = string.IsNullOrWhiteSpace(bio) ? null : bio.Trim();
    }

    /// <summary>Adds or replaces the player's profile for one sport. Format validity is checked by the caller against the catalog.</summary>
    public void SetSportProfile(SportProfile sport)
    {
        if (sport.Formats.Count == 0)
            throw new BusinessRuleViolationException("FORMAT_REQUIRED", "دست‌کم یک قالب بازی انتخاب کنید.");
        if (sport.Goals == PlayGoals.None)
            throw new BusinessRuleViolationException("GOAL_REQUIRED", "دست‌کم یک هدف انتخاب کنید.");
        _sports = [.. _sports.Where(s => s.SportId != sport.SportId), sport with { Formats = sport.Formats.Distinct().Order().ToList() }];
    }

    public void RemoveSportProfile(Guid sportId)
    {
        if (_sports.All(s => s.SportId != sportId))
            return;
        if (_sports.Count == 1)
            throw new InvalidAggregateStateException("LAST_SPORT_PROFILE", "دست‌کم یک ورزش باید در پروفایل بماند.");
        _sports = _sports.Where(s => s.SportId != sportId).ToList();
    }

    public SportProfile? SportProfileFor(Guid sportId) => _sports.FirstOrDefault(s => s.SportId == sportId);

    public void SetHomeVenues(IReadOnlyCollection<Guid> venueIds)
    {
        var distinct = venueIds.Distinct().ToList();
        if (distinct.Count > MaxHomeVenues)
            throw new BusinessRuleViolationException("TOO_MANY_HOME_VENUES", $"حداکثر {MaxHomeVenues} باشگاه را می‌توانید انتخاب کنید.");
        _homeVenueIds = distinct;
    }

    public void RemoveHomeVenue(Guid venueId) => _homeVenueIds.Remove(venueId);

    public void SetVisibility(ProfileVisibility visibility) => Visibility = visibility;

    /// <summary>Only an admin may change gender after onboarding (spec player-profile › Gender is fixed after onboarding).</summary>
    public void CorrectGender(Gender gender) => Gender = gender;

    public void SetPhoto(string key) => PhotoKey = key;

    public void RemovePhoto() => PhotoKey = null;

    public void TouchActivity(DateTime now)
    {
        if (now > LastActiveAt)
            LastActiveAt = now;
    }

    public void Hide()
    {
        if (Status == ProfileStatus.Active)
            Status = ProfileStatus.Hidden;
    }

    public void Show()
    {
        if (Status == ProfileStatus.Hidden)
            Status = ProfileStatus.Active;
    }

    /// <summary>The account was deleted: keep the row for match history, forget everything personal.</summary>
    public void Anonymize()
    {
        Status = ProfileStatus.Deleted;
        DisplayName = DeletedDisplayName;
        Bio = null;
        PhotoKey = null;
        BirthDate = null;
        _homeVenueIds = [];
    }

    /// <summary>
    /// Age in completed Jalali years, as counted in Iran: born 1387/08/02, a player turns 18 on 1405/08/02. Gregorian
    /// arithmetic can disagree by a day because the two calendars' years do not start together.
    /// </summary>
    public static int AgeOn(DateOnly birthDate, DateOnly today)
    {
        var calendar = new System.Globalization.PersianCalendar();
        DateTime b = birthDate.ToDateTime(TimeOnly.MinValue), t = today.ToDateTime(TimeOnly.MinValue);
        var age = calendar.GetYear(t) - calendar.GetYear(b);
        var (bm, bd) = (calendar.GetMonth(b), calendar.GetDayOfMonth(b));
        var (tm, td) = (calendar.GetMonth(t), calendar.GetDayOfMonth(t));
        if (tm < bm || (tm == bm && td < bd))
            age--;
        return age;
    }

    public static AgeRange RangeOf(int age) => age switch
    {
        < 25 => AgeRange.From18To24,
        < 35 => AgeRange.From25To34,
        < 45 => AgeRange.From35To44,
        < 55 => AgeRange.From45To54,
        _ => AgeRange.From55,
    };

    [GeneratedRegex(@"^[\p{L}\p{Mn}\p{Nd}‌ ]{2,30}$")]
    private static partial Regex DisplayNamePattern();
}
