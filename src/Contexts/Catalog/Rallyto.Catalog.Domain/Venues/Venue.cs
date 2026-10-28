using Rallyto.Catalog.Domain.Sports;
using Rallyto.Core.Domain.Base;
using Rallyto.Core.Domain.Exceptions;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Catalog.Domain.Venues;

public enum VenueStatus
{
    Active = 1,
    Hidden = 2,
}

public enum CourtSetting
{
    Indoor = 1,
    Outdoor = 2,
    Both = 3,
}

public sealed record VenueSport(Guid SportId, int? CourtCount, CourtSetting Setting, CourtSurface? Surface, bool HasLighting);

public sealed record VenueDetails(string Name, string? Address, string? Phone, double? Latitude, double? Longitude);

/// <summary>Descriptive, optional information shown on a club's page. Links are http(s) only.</summary>
public sealed record VenueProfile(
    string? Tagline,
    string? Description,
    string? Website,
    string? Instagram,
    string? Telegram,
    string? WorkingHours,
    IReadOnlyList<string> Amenities,
    IReadOnlyList<string> CourtTypes)
{
    public static readonly VenueProfile Empty = new(null, null, null, null, null, null, [], []);
}

public sealed record VenueImage(string Path, int SortOrder);

public sealed record VenueHidden(Guid VenueId) : DomainEvent;

/// <summary>
/// A club and the sports it offers (spec venue-catalog). Only the Rallyto team creates or edits venues; a club
/// has no account. Coordinates locate the club, never a player.
/// </summary>
public sealed class Venue : AggregateRoot<Guid>
{
    public const int MaxImages = 20;
    private const int MaxAmenities = 30;

    private List<VenueSport> _sports = [];
    private List<VenueImage> _images = [];

    private Venue() { }

    public string Name { get; private set; } = string.Empty;
    public string NormalizedName { get; private set; } = string.Empty;
    public int CityId { get; private set; }
    public string? Address { get; private set; }
    public string? Phone { get; private set; }
    public double? Latitude { get; private set; }
    public double? Longitude { get; private set; }
    public VenueStatus Status { get; private set; }
    public string? GooglePlaceId { get; private set; }
    public VenueProfile Profile { get; private set; } = VenueProfile.Empty;

    /// <summary>Where an imported club came from, for example <c>tennix.ir:enghelab</c>; makes re-imports idempotent.</summary>
    public string? SourceRef { get; private set; }
    public string? SourceUrl { get; private set; }

    /// <summary>The place's rating on Google Maps (1–5) and how many reviews it rests on; shown labelled as Google's.</summary>
    public double? GoogleRating { get; private set; }
    public int? GoogleReviewCount { get; private set; }
    public uint Version { get; private set; }

    public IReadOnlyList<VenueSport> Sports => _sports;
    public IReadOnlyList<VenueImage> Images => _images;
    public string? CoverImage => _images.OrderBy(i => i.SortOrder).FirstOrDefault()?.Path;

    public static Venue Create(int cityId, VenueDetails details, IEnumerable<VenueSport> sports, string? googlePlaceId)
    {
        var venue = new Venue { Id = Guid.NewGuid(), CityId = cityId, Status = VenueStatus.Active, GooglePlaceId = googlePlaceId };
        venue.Update(details, sports);
        return venue;
    }

    public void Update(VenueDetails details, IEnumerable<VenueSport> sports)
    {
        if (string.IsNullOrWhiteSpace(details.Name) || details.Name.Length > 120)
            throw new BusinessRuleViolationException("VENUE_NAME_REQUIRED", "نام باشگاه لازم است (حداکثر ۱۲۰ نویسه).");
        if (details.Latitude is < -90 or > 90 || details.Longitude is < -180 or > 180 || details.Latitude.HasValue != details.Longitude.HasValue)
            throw new BusinessRuleViolationException("INVALID_COORDINATES", "مختصات باشگاه معتبر نیست.");

        var sportList = sports.ToList();
        if (sportList.Count == 0 || sportList.Select(s => s.SportId).Distinct().Count() != sportList.Count)
            throw new BusinessRuleViolationException("VENUE_SPORTS_REQUIRED", "دست‌کم یک ورزش برای باشگاه لازم است.");
        if (sportList.Any(s => s.CourtCount is < 1 or > 100))
            throw new BusinessRuleViolationException("INVALID_COURT_COUNT", "تعداد زمین معتبر نیست.");

        Name = details.Name.Trim();
        NormalizedName = PersianText.Normalize(details.Name);
        Address = string.IsNullOrWhiteSpace(details.Address) ? null : details.Address.Trim();
        Phone = string.IsNullOrWhiteSpace(details.Phone) ? null : details.Phone.Trim();
        Latitude = details.Latitude;
        Longitude = details.Longitude;
        _sports = sportList;
    }

    public void SetProfile(VenueProfile profile)
    {
        var website = Link(profile.Website);
        var instagram = Link(profile.Instagram);
        var telegram = Link(profile.Telegram);
        var amenities = Clean(profile.Amenities);
        var courtTypes = Clean(profile.CourtTypes);
        var tagline = Text(profile.Tagline, 200);
        var description = Text(profile.Description, 4000);
        var hours = Text(profile.WorkingHours, 200);
        if (amenities.Count > MaxAmenities || courtTypes.Count > MaxAmenities || amenities.Concat(courtTypes).Any(a => a.Length > 60))
            throw TooLong();

        Profile = new VenueProfile(tagline, description, website, instagram, telegram, hours, amenities, courtTypes);
    }

    public void SetSource(string sourceRef, string? sourceUrl)
    {
        if (string.IsNullOrWhiteSpace(sourceRef) || sourceRef.Trim().Length > 200)
            throw new BusinessRuleViolationException("INVALID_VENUE_SOURCE", "منبع باشگاه معتبر نیست.");
        SourceRef = sourceRef.Trim();
        SourceUrl = Link(sourceUrl);
    }

    public void SetGoogleRating(double? rating, int? reviewCount)
    {
        if (rating is null)
        {
            GoogleRating = null;
            GoogleReviewCount = null;
            return;
        }

        if (rating is < 1 or > 5 || reviewCount is null or < 0)
            throw new BusinessRuleViolationException("INVALID_GOOGLE_RATING", "امتیاز گوگل باید بین ۱ تا ۵ و همراه با تعداد نظرها باشد.");
        GoogleRating = Math.Round(rating.Value, 1);
        GoogleReviewCount = reviewCount;
    }

    /// <summary>Appends a photo; the first one is the cover.</summary>
    public void AddImage(string path)
    {
        if (_images.Count >= MaxImages)
            throw new BusinessRuleViolationException("VENUE_PHOTO_LIMIT", $"هر باشگاه حداکثر {MaxImages} عکس می‌تواند داشته باشد.");
        _images.Add(new VenueImage(path, _images.Count == 0 ? 0 : _images.Max(i => i.SortOrder) + 1));
    }

    public bool RemoveImage(string path) => _images.RemoveAll(i => i.Path == path) > 0;

    private static string? Text(string? value, int max)
    {
        var trimmed = string.IsNullOrWhiteSpace(value) ? null : value.Trim();
        return trimmed is not null && trimmed.Length > max ? throw TooLong() : trimmed;
    }

    private static string? Link(string? value)
    {
        var trimmed = Text(value, 300);
        if (trimmed is null)
            return null;
        return Uri.TryCreate(trimmed, UriKind.Absolute, out var uri) && (uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps)
            ? trimmed
            : throw new BusinessRuleViolationException("INVALID_VENUE_LINK", "نشانی لینک باید با http یا https شروع شود.");
    }

    private static List<string> Clean(IEnumerable<string>? values) =>
        (values ?? []).Where(v => !string.IsNullOrWhiteSpace(v)).Select(v => v.Trim()).Distinct().ToList();

    private static BusinessRuleViolationException TooLong() => new("VENUE_PROFILE_TOO_LONG", "اطلاعات باشگاه بیش از حد طولانی است.");

    public bool Offers(Guid sportId) => Status == VenueStatus.Active && _sports.Any(s => s.SportId == sportId);

    /// <summary>A duplicate import of this club was merged into it.</summary>
    public void AttachPlace(string placeId) => GooglePlaceId ??= placeId;

    public void Hide()
    {
        if (Status == VenueStatus.Hidden)
            return;
        Status = VenueStatus.Hidden;
        RaiseDomainEvent(new VenueHidden(Id));
    }

    public void Unhide() => Status = VenueStatus.Active;
}
