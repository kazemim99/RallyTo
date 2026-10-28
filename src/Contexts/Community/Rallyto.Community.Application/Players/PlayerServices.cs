using Rallyto.Community.Application.Abstractions;
using Rallyto.Community.Domain.Players;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Core.Application.Localization;
using Rallyto.Core.Domain.Exceptions;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Community.Application.Players;

/// <summary>The signed-in player's profile; everything in Community except onboarding needs one (spec player-profile).</summary>
public sealed class PlayerContext(ICurrentUserService currentUser, IPlayerProfileRepository profiles)
{
    public Guid UserId => currentUser.RequireUserId();

    public async Task<PlayerProfile> RequireProfileAsync(CancellationToken cancellationToken) =>
        await profiles.GetAsync(UserId, cancellationToken) ?? throw ProfileRequired();

    public static ForbiddenException ProfileRequired() => new("ابتدا پروفایل خود را کامل کنید.", "PROFILE_REQUIRED");
}

/// <summary>Who may see whom, with blocks loaded from the database (design D11).</summary>
public sealed class VisibilityService(IBlockRepository blocks)
{
    public async Task<bool> CanSeeAsync(PlayerProfile viewer, PlayerProfile subject, CancellationToken cancellationToken)
    {
        var viewerFacts = VisibilityPolicy.FactsOf(viewer);
        var subjectFacts = VisibilityPolicy.FactsOf(subject);
        if (!VisibilityPolicy.CanSee(viewerFacts, subjectFacts, blockedEitherWay: false))
            return false;
        return viewer.Id == subject.Id || !await blocks.IsBlockedEitherWayAsync(viewer.Id, subject.Id, cancellationToken);
    }

    /// <summary>The same "not found" a missing player gets, so a block or a hidden profile is never revealed.</summary>
    public static NotFoundException PlayerNotFound() => new("بازیکن پیدا نشد.", "PLAYER_NOT_FOUND");
}

/// <summary>Checks sport profiles against the catalog and builds views.</summary>
public sealed class ProfileAssembler(ICatalogReader catalog, Ratings.ReputationService reputation, TimeProvider clock)
{
    public async Task<SportProfile> ToSportProfileAsync(SportProfileInput input, CancellationToken cancellationToken)
    {
        var sport = (await catalog.SportsAsync(cancellationToken)).FirstOrDefault(s => s.Id == input.SportId && s.IsActive)
            ?? throw new ValidationFailedException("UNKNOWN_SPORT", "ورزش انتخاب‌شده وجود ندارد.");
        if (!Enum.IsDefined(input.Level) || !Enum.IsDefined(input.Experience))
            throw new ValidationFailedException("INVALID_SPORT_PROFILE", "سطح یا سابقه معتبر نیست.");
        var formats = (input.Formats ?? []).Distinct().ToList();
        if (formats.Any(f => !sport.Allows(f)))
            throw new BusinessRuleViolationException("FORMAT_NOT_ALLOWED", $"این قالب بازی برای {sport.NameFa} مجاز نیست.");
        var goals = (input.Goals ?? []).Aggregate(PlayGoals.None, (all, g) => all | g);
        return new SportProfile(sport.Id, input.Level, input.Experience, formats, goals);
    }

    public async Task EnsureCityAsync(int cityId, CancellationToken cancellationToken)
    {
        if (await catalog.CityAsync(cityId, cancellationToken) is null)
            throw new ValidationFailedException("UNKNOWN_CITY", "شهر انتخاب‌شده وجود ندارد.");
    }

    public async Task EnsureActiveVenuesAsync(IReadOnlyCollection<Guid> venueIds, CancellationToken cancellationToken)
    {
        var venues = await catalog.VenuesAsync(venueIds, cancellationToken);
        if (venueIds.Any(id => !venues.TryGetValue(id, out var v) || !v.IsActive))
            throw new ValidationFailedException("UNKNOWN_VENUE", "یکی از باشگاه‌های انتخاب‌شده در دسترس نیست.");
    }

    public async Task<PlayerProfileView> PublicViewAsync(PlayerProfile profile, CancellationToken cancellationToken)
    {
        var (sports, city, venues) = await DetailsAsync(profile, cancellationToken);
        var now = clock.GetUtcNow().UtcDateTime;
        return new PlayerProfileView(profile.Id, profile.DisplayName, profile.PhotoKey, profile.Gender, AgeRangeOf(profile), city, profile.Bio,
            sports, venues, PersianFormat.JalaliAscii(DateOnly.FromDateTime(PersianFormat.ToTehran(profile.JoinedAt)))[..7],
            LastActivity.Bucket(profile.LastActiveAt, now, PersianFormat.TehranToday),
            await reputation.ViewAsync(profile.Id, profile.Sports.Select(s => s.SportId), cancellationToken));
    }

    public async Task<MyProfileView> OwnerViewAsync(PlayerProfile profile, CancellationToken cancellationToken)
    {
        var (sports, city, venues) = await DetailsAsync(profile, cancellationToken);
        return new MyProfileView(profile.Id, profile.DisplayName, profile.PhotoKey, profile.Gender,
            profile.BirthDate is { } b ? PersianFormat.JalaliAscii(b) : null, AgeRangeOf(profile), city, profile.Bio,
            profile.Visibility, profile.Status, sports, venues,
            await reputation.ViewAsync(profile.Id, profile.Sports.Select(s => s.SportId), cancellationToken));
    }

    public DateOnly TehranToday() => PersianFormat.TehranToday(clock.GetUtcNow().UtcDateTime);

    private string AgeRangeOf(PlayerProfile profile) =>
        profile.BirthDate is { } birth ? AgeRangeText.Of(PlayerProfile.RangeOf(PlayerProfile.AgeOn(birth, TehranToday()))) : string.Empty;

    private async Task<(IReadOnlyList<SportProfileView>, CityRef, IReadOnlyList<NamedRef>)> DetailsAsync(PlayerProfile profile, CancellationToken cancellationToken)
    {
        var catalogSports = (await catalog.SportsAsync(cancellationToken)).ToDictionary(s => s.Id);
        var sports = profile.Sports.Select(s =>
        {
            catalogSports.TryGetValue(s.SportId, out var sport);
            var level = sport?.Levels.FirstOrDefault(l => l.Tier == s.Level);
            return new SportProfileView(s.SportId, sport?.Code ?? string.Empty, s.Level, level?.Name ?? s.Level.ToString(), level?.Description,
                s.Experience, s.Formats, Enum.GetValues<PlayGoals>().Where(g => g != PlayGoals.None && s.Goals.HasFlag(g)).ToList());
        }).ToList();

        var city = await catalog.CityAsync(profile.CityId, cancellationToken);
        var venues = await catalog.VenuesAsync(profile.HomeVenueIds, cancellationToken);
        var venueRefs = profile.HomeVenueIds.Where(venues.ContainsKey).Select(id => new NamedRef(id, venues[id].Name)).ToList();
        return (sports, new CityRef(profile.CityId, city?.Name ?? string.Empty), venueRefs);
    }
}
