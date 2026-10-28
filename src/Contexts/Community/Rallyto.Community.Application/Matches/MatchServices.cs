using Rallyto.Community.Application.Abstractions;
using Rallyto.Community.Application.Players;
using Rallyto.Community.Domain.Availabilities;
using Rallyto.Community.Domain.Matches;
using Rallyto.Community.Domain.Players;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Core.Application.Localization;
using Rallyto.Core.Domain.Exceptions;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Community.Application.Matches;

public sealed record MatchInput(
    Guid SportId,
    Guid VenueId,
    PlayFormat Format,
    string Date,
    string StartTime,
    int? DurationMinutes,
    int PlayersBrought,
    LevelTier? MinLevel,
    LevelTier? MaxLevel,
    PartnerGender PartnerGender,
    bool CourtBooked,
    string? CostNote,
    string? Description);

public sealed record InvitationInput(
    Guid SportId,
    Guid VenueId,
    PlayFormat Format,
    string Date,
    string StartTime,
    int? DurationMinutes,
    int PlayersBrought,
    IReadOnlyList<Guid> Invitees,
    string? Message);

public sealed record SportRef(Guid Id, string Code, string Name);

public sealed record HostRef(Guid UserId, string DisplayName, LevelTier? Level);

public sealed record ParticipantView(Guid UserId, string DisplayName, ParticipantState State, bool OutOfRange, string? Message, AttendanceOutcome? Outcome);

/// <summary>The viewer's attendance and rating state, once the game has ended (spec match-lifecycle › Attendance confirmation).</summary>
public sealed record MatchAttendanceView(bool Open, DateTime ClosesAt, AttendanceAnswer? MyAnswer, AttendanceOutcome? MyOutcome, DateTime? ResolvedAt, IReadOnlyList<Guid> CanRate);

public sealed record MatchView(
    Guid Id,
    MatchVisibility Visibility,
    MatchStatus Status,
    SportRef Sport,
    PlayFormat Format,
    int Capacity,
    int OpenSpots,
    NamedRef Venue,
    string Date,
    string StartTime,
    string EndTime,
    int DurationMinutes,
    DateTime StartsAt,
    HostRef Host,
    LevelTier MinLevel,
    LevelTier MaxLevel,
    PartnerGender PartnerGender,
    bool CourtBooked,
    string? CostNote,
    string? Description,
    int PlayersBrought,
    string? ShareUrl,
    IReadOnlyList<ParticipantView>? Participants,
    ParticipantState? MyState,
    MatchAttendanceView? Attendance,
    string? CancelReason);

/// <summary>What anyone with a share link sees: no photo, age or contact detail (spec play-posts › Share link).</summary>
public sealed record ShareSummaryView(string Sport, PlayFormat Format, string Venue, string City, string Date, string StartTime, LevelTier MinLevel, LevelTier MaxLevel, int OpenSpots, bool CourtBooked, string HostName, string? HostLevel);

/// <summary>Public base URL for share links (PublicBaseUrl; no domain is provisioned yet).</summary>
public sealed record PublicLinks(string BaseUrl);

public interface IMatchRepository
{
    Task<Match?> GetAsync(Guid id, CancellationToken cancellationToken);
    Task<Match?> GetByShareTokenAsync(string token, CancellationToken cancellationToken);
    Task<bool> HasAcceptedOverlapAsync(Guid playerId, DateTime startsAt, DateTime endsAt, Guid? excludeMatchId, CancellationToken cancellationToken);
    Task<int> CountOpenHostedAsync(Guid hostId, DateTime now, CancellationToken cancellationToken);
    Task<int> CountPendingRequestsAsync(Guid playerId, DateTime now, CancellationToken cancellationToken);
    Task<IReadOnlyList<Match>> ListForPlayerAsync(Guid playerId, bool upcoming, DateTime now, CancellationToken cancellationToken);
    Task<IReadOnlyList<Match>> ListFutureInvolvingAsync(Guid playerId, DateTime now, CancellationToken cancellationToken);
    Task<IReadOnlyList<Match>> ListOpenPostsAsync(Guid sportId, int cityId, DateTime fromUtc, DateTime toUtc, CancellationToken cancellationToken);
    Task<bool> HasFutureMatchInSportAsync(Guid playerId, Guid sportId, DateTime now, CancellationToken cancellationToken);
    Task<IReadOnlySet<Guid>> BusyPlayersAsync(IReadOnlyCollection<Guid> playerIds, DateTime startsAt, DateTime endsAt, CancellationToken cancellationToken);
    void Add(Match match);
    void AddLateCancellation(LateCancellation lateCancellation);
}

/// <summary>Validates games against the catalog and builds views (spec play-posts, spec match-lifecycle).</summary>
public sealed class MatchAssembler(ICatalogReader catalog, IPlayerProfileRepository profiles, Ratings.IRatingRepository ratings, TimeProvider clock, PublicLinks links)
{
    public DateTime Now => clock.GetUtcNow().UtcDateTime;

    public async Task<(MatchSlot Slot, CatalogSport Sport)> ValidateSlotAsync(Guid sportId, Guid venueId, PlayFormat format, string date, string startTime, int? duration, CancellationToken cancellationToken)
    {
        var sport = (await catalog.SportsAsync(cancellationToken)).FirstOrDefault(s => s.Id == sportId && s.IsActive)
            ?? throw new ValidationFailedException("UNKNOWN_SPORT", "ورزش انتخاب‌شده وجود ندارد.");
        if (!sport.Allows(format))
            throw new BusinessRuleViolationException("FORMAT_NOT_ALLOWED", $"این قالب بازی برای {sport.NameFa} مجاز نیست.");
        var venues = await catalog.VenuesAsync([venueId], cancellationToken);
        if (!venues.TryGetValue(venueId, out var venue) || !venue.IsActive)
            throw new ValidationFailedException("UNKNOWN_VENUE", "باشگاه انتخاب‌شده در دسترس نیست.");
        if (!venue.Offers(sportId))
            throw new BusinessRuleViolationException("VENUE_DOES_NOT_OFFER_SPORT", $"باشگاه انتخاب‌شده {sport.NameFa} ندارد.");
        if (!PersianFormat.TryParseJalali(date, out var day))
            throw new ValidationFailedException("INVALID_DATE", "تاریخ معتبر نیست.");
        var minute = TimeWindow.ParseMinute(startTime);
        if (minute >= TimeWindow.EndOfDay || minute % 30 != 0)
            throw new ValidationFailedException("INVALID_TIME", "ساعت شروع باید مضرب ۳۰ دقیقه باشد.");
        var local = day.ToDateTime(TimeOnly.MinValue).AddMinutes(minute);
        var startsAt = TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(local, DateTimeKind.Unspecified), PersianFormat.Tehran);
        return (MatchSlot.Create(sportId, format, sport.CapacityOf(format), venueId, venue.CityId, startsAt, duration ?? sport.DefaultSessionMinutes, Now), sport);
    }

    /// <summary>Whether the viewer may see the match at all, and whether they get the full (participant) view.</summary>
    public async Task<(bool CanSee, bool Involved)> AccessAsync(PlayerProfile viewer, Match match, VisibilityService visibility, CancellationToken cancellationToken)
    {
        // Anyone the match knows (host, invited, requested, even declined) sees it with their own state.
        if (match.HostId == viewer.Id || match.ParticipantOf(viewer.Id) is not null)
            return (true, true);
        if (match.Visibility != MatchVisibility.Public || match.HiddenAt is not null)
            return (false, false);
        var host = await profiles.GetAsync(match.HostId, cancellationToken);
        if (host is null || !await visibility.CanSeeAsync(viewer, host, cancellationToken))
            return (false, false);
        return (AcceptsGender(match, viewer.Gender), false);
    }

    public static bool AcceptsGender(Match match, Gender gender) =>
        match.PartnerGender == PartnerGender.Any || (int)match.PartnerGender == (int)gender;

    public string ShareUrl(Match match) =>
        $"{links.BaseUrl.TrimEnd('/')}/m/{match.ShareToken}";

    public async Task<MatchView> ViewAsync(Match match, Guid? viewerId, bool involved, CancellationToken cancellationToken) =>
        (await ViewsAsync([(match, involved)], viewerId, cancellationToken))[0];

    public async Task<IReadOnlyList<MatchView>> ViewsAsync(IReadOnlyList<(Match Match, bool Involved)> matches, Guid? viewerId, CancellationToken cancellationToken)
    {
        var sports = (await catalog.SportsAsync(cancellationToken)).ToDictionary(s => s.Id);
        var venues = await catalog.VenuesAsync(matches.Select(m => m.Match.VenueId).Distinct().ToList(), cancellationToken);
        var people = await profiles.DisplayNamesAsync(matches.SelectMany(m => m.Match.Participants.Select(p => p.PlayerId)).Distinct().ToList(), cancellationToken);
        var views = new List<MatchView>();
        foreach (var (match, involved) in matches)
        {
            sports.TryGetValue(match.SportId, out var sport);
            var host = await profiles.GetAsync(match.HostId, cancellationToken);
            var localStart = PersianFormat.ToTehran(match.StartsAt);
            var localEnd = PersianFormat.ToTehran(match.EndsAt);
            views.Add(new MatchView(
                match.Id,
                match.Visibility,
                match.Status,
                new SportRef(match.SportId, sport?.Code ?? string.Empty, sport?.NameFa ?? string.Empty),
                match.Format,
                match.Capacity,
                match.OpenSpots,
                new NamedRef(match.VenueId, venues.GetValueOrDefault(match.VenueId)?.Name ?? string.Empty),
                PersianFormat.JalaliAscii(DateOnly.FromDateTime(localStart)),
                localStart.ToString("HH:mm", System.Globalization.CultureInfo.InvariantCulture),
                localEnd.Date > localStart.Date && localEnd.TimeOfDay == TimeSpan.Zero ? "24:00" : localEnd.ToString("HH:mm", System.Globalization.CultureInfo.InvariantCulture),
                match.DurationMinutes,
                match.StartsAt,
                new HostRef(match.HostId, people.GetValueOrDefault(match.HostId, PlayerProfile.DeletedDisplayName), host?.SportProfileFor(match.SportId)?.Level),
                match.MinLevel,
                match.MaxLevel,
                match.PartnerGender,
                match.CourtBooked,
                match.CostNote,
                match.Description,
                match.PlayersBrought,
                match.Visibility == MatchVisibility.Public ? ShareUrl(match) : null,
                involved
                    ? match.Participants.Select(p => new ParticipantView(p.PlayerId, people.GetValueOrDefault(p.PlayerId, PlayerProfile.DeletedDisplayName), p.State, p.OutOfRange, p.Message, p.Outcome)).ToList()
                    : null,
                involved && viewerId is { } id ? match.ParticipantOf(id)?.State : null,
                involved && viewerId is { } viewer ? await AttendanceAsync(match, viewer, cancellationToken) : null,
                match.CancelReason));
        }

        return views;
    }

    private async Task<MatchAttendanceView?> AttendanceAsync(Match match, Guid viewerId, CancellationToken cancellationToken)
    {
        var me = match.ParticipantOf(viewerId);
        var now = Now;
        if (me is null || (!me.Plays && me.Outcome is null) || now < match.EndsAt
            || match.Status is not (MatchStatus.Confirmed or MatchStatus.Completed or MatchStatus.Disputed or MatchStatus.Unconfirmed))
            return null;
        var partners = match.RateablePartnersOf(viewerId, now);
        IReadOnlySet<Guid> rated = partners.Count == 0 ? new HashSet<Guid>() : await ratings.RateesOfAsync(match.Id, viewerId, cancellationToken);
        return new MatchAttendanceView(match.IsAttendanceOpen(now), match.AttendanceClosesAt, me.Attendance, me.Outcome, match.ResolvedAt,
            partners.Where(p => !rated.Contains(p)).ToList());
    }
}
