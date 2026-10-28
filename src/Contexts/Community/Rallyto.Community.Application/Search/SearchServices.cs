using System.Text;
using Rallyto.Community.Application.Abstractions;
using Rallyto.Community.Application.Players;
using Rallyto.Community.Domain.Availabilities;
using Rallyto.Community.Domain.Players;
using Rallyto.Community.Domain.Search;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Core.Application.Localization;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Community.Application.Search;

public sealed record SearchCriteriaInput(
    Guid SportId,
    int? CityId,
    IReadOnlyList<Guid>? VenueIds,
    string? Date,
    IReadOnlyList<IranianWeekdays>? Weekdays,
    string? From,
    string? To,
    LevelTier? MinLevel,
    LevelTier? MaxLevel,
    Gender? Gender,
    PlayFormat? Format);

/// <summary>A window from the search store, with what a result card shows about its owner.</summary>
public sealed record CandidateRow(
    WindowCandidate Window,
    string DisplayName,
    string? PhotoKey,
    DateOnly? BirthDate,
    DateTime LastActiveAt,
    ExperienceBand? Experience);

public interface IPartnerSearchReader
{
    /// <summary>
    /// SQL prefilter (sport, city, status, day, time, level, gender, visibility, blocks), newest activity first.
    /// The authoritative check is <see cref="PartnerMatchRules"/>, applied by the caller.
    /// </summary>
    Task<IReadOnlyList<CandidateRow>> FindCandidatesAsync(SearchCriteria criteria, PlayerVisibilityFacts searcher, DateOnly todayTehran, int limit, CancellationToken cancellationToken);
}

public sealed record MatchingWindowView(
    Guid AvailabilityId,
    IReadOnlyList<NamedRef> Venues,
    IReadOnlyList<IranianWeekdays> Weekdays,
    string? Date,
    string StartTime,
    string EndTime,
    string OverlapStart,
    string OverlapEnd,
    IReadOnlyList<PlayFormat> Formats);

public sealed record PartnerResultView(
    Guid UserId,
    string DisplayName,
    string? PhotoUrl,
    Gender Gender,
    string AgeRange,
    LevelTier Level,
    string LevelName,
    ExperienceBand? Experience,
    LastActiveBucket LastActive,
    IReadOnlyList<MatchingWindowView> Windows,
    ReliabilityTier Reliability,
    double? RatingAverage,
    int RatingCount);

public sealed record SearchResultsView(IReadOnlyList<PartnerResultView> Players, IReadOnlyList<Matches.MatchView> Posts, string? NextCursor);

/// <summary>Applies the defaults of spec partner-search › Search input and defaults.</summary>
public sealed class SearchCriteriaResolver(ICatalogReader catalog, TimeProvider clock)
{
    public const int MaxDaysAhead = 30;

    public DateOnly TehranToday() => PersianFormat.TehranToday(clock.GetUtcNow().UtcDateTime);

    public async Task<SearchCriteria> ResolveAsync(PlayerProfile searcher, SearchCriteriaInput input, CancellationToken cancellationToken)
    {
        var sport = (await catalog.SportsAsync(cancellationToken)).FirstOrDefault(s => s.Id == input.SportId && s.IsActive)
            ?? throw new ValidationFailedException("UNKNOWN_SPORT", "ورزش انتخاب‌شده وجود ندارد.");

        DateOnly? date = null;
        if (!string.IsNullOrWhiteSpace(input.Date))
        {
            if (!PersianFormat.TryParseJalali(input.Date, out var parsed))
                throw new ValidationFailedException("INVALID_DATE", "تاریخ معتبر نیست.");
            var today = TehranToday();
            if (parsed < today || parsed > today.AddDays(MaxDaysAhead))
                throw new ValidationFailedException("DATE_OUT_OF_RANGE", $"تاریخ جستجو باید از امروز تا {MaxDaysAhead} روز آینده باشد.");
            date = parsed;
        }

        var from = string.IsNullOrWhiteSpace(input.From) ? 0 : TimeWindow.ParseMinute(input.From);
        var to = string.IsNullOrWhiteSpace(input.To) ? TimeWindow.EndOfDay : TimeWindow.ParseMinute(input.To);
        if (to <= from)
            throw new ValidationFailedException("INVALID_TIME_RANGE", "ساعت پایان باید بعد از ساعت شروع باشد.");

        var own = searcher.SportProfileFor(sport.Id)?.Level;
        var min = input.MinLevel ?? (own is { } l1 ? LevelTiers.Clamp((int)l1 - 1) : LevelTier.Beginner);
        var max = input.MaxLevel ?? (own is { } l2 ? LevelTiers.Clamp((int)l2 + 1) : LevelTier.Professional);
        if (max < min)
            (min, max) = (max, min);

        var gender = searcher.Visibility == ProfileVisibility.SameGender ? searcher.Gender : input.Gender;
        var format = input.Format is { } f && sport.Allows(f) ? f : (PlayFormat?)null;
        var weekdays = (input.Weekdays ?? []).Aggregate(IranianWeekdays.None, (all, d) => all | d);

        return new SearchCriteria(sport.Id, input.CityId ?? searcher.CityId, (input.VenueIds ?? []).Distinct().ToList(),
            date, date is null ? weekdays : IranianWeekdays.None, from, to, min, max, gender, format);
    }
}

/// <summary>Player results: prefilter, authoritative match rules, ranking, paging (design D6).</summary>
public sealed class PartnerSearchService(
    IPartnerSearchReader reader,
    ICatalogReader catalog,
    Matches.IMatchRepository matchRepository,
    Ratings.ReputationService reputation,
    TimeProvider clock,
    RankingWeights weights)
{
    public const int PageSize = 20;
    public const int CandidateLimit = 500;

    public async Task<SearchResultsView> SearchAsync(PlayerProfile searcher, SearchCriteria criteria, string? cursor, CancellationToken cancellationToken)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var today = PersianFormat.TehranToday(now);
        var facts = VisibilityPolicy.FactsOf(searcher);
        var rows = await reader.FindCandidatesAsync(criteria, facts, today, CandidateLimit, cancellationToken);

        // Blocks were excluded in SQL, so the in-memory check runs with blockedEitherWay: false.
        var matches = rows
            .Select(r => (Row: r, Overlap: PartnerMatchRules.Match(criteria, facts, r.Window, blockedEitherWay: false, today)))
            .Where(m => m.Overlap > 0)
            .GroupBy(m => m.Row.Window.PlayerId)
            .ToList();

        // On a specific date, players who already have a game at that time are not available (spec partner-search).
        if (criteria.Date is { } date && matches.Count > 0)
        {
            var start = TehranToUtc(date, criteria.FromMinute);
            var end = TehranToUtc(date, criteria.ToMinute);
            var busy = await matchRepository.BusyPlayersAsync(matches.Select(g => g.Key).ToList(), start, end, cancellationToken);
            matches = matches.Where(g => !busy.Contains(g.Key)).ToList();
        }

        var searcherLevel = searcher.SportProfileFor(criteria.SportId)?.Level;
        var requested = criteria.ToMinute - criteria.FromMinute;
        var signals = await reputation.RankingSignalsAsync(searcher.Id, matches.Select(g => g.Key).ToList(), criteria.SportId, cancellationToken);
        var ranked = PartnerRankingPolicy.Rank(matches.Select(g =>
        {
            var best = g.MaxBy(m => m.Overlap);
            var row = best.Row;
            var signal = signals[row.Window.PlayerId];
            return new RankingInput(row.Window.PlayerId,
                searcherLevel is { } own ? LevelTiers.Distance(own, row.Window.Level!.Value) : 0,
                best.Overlap, requested, signal.Reliability, signal.PublicRatingAverage, (now - row.LastActiveAt).TotalDays, signal.PlayedTogether, row.LastActiveAt);
        }), weights);

        var offset = DecodeCursor(cursor);
        var page = ranked.Skip(offset).Take(PageSize).ToList();
        var byPlayer = matches.ToDictionary(g => g.Key, g => g.OrderByDescending(m => m.Overlap).ToList());
        var views = await ToViewsAsync(page.Select(p => byPlayer[p.PlayerId]).ToList(), criteria, signals, now, cancellationToken);
        var next = offset + page.Count < ranked.Count ? EncodeCursor(offset + page.Count) : null;
        return new SearchResultsView(views, [], next);
    }

    private async Task<IReadOnlyList<PartnerResultView>> ToViewsAsync(
        IReadOnlyList<List<(CandidateRow Row, int Overlap)>> players, SearchCriteria criteria, IReadOnlyDictionary<Guid, Ratings.RankingSignals> signals, DateTime now,
        CancellationToken cancellationToken)
    {
        var sport = (await catalog.SportsAsync(cancellationToken)).First(s => s.Id == criteria.SportId);
        var venues = await catalog.VenuesAsync(players.SelectMany(p => p).SelectMany(m => m.Row.Window.VenueIds).Distinct().ToList(), cancellationToken);
        var today = PersianFormat.TehranToday(now);

        return players.Select(windows =>
        {
            var first = windows[0].Row;
            var level = first.Window.Level!.Value;
            return new PartnerResultView(
                first.Window.PlayerId,
                first.DisplayName,
                first.PhotoKey,
                first.Window.Gender,
                first.BirthDate is { } b ? AgeRangeText.Of(PlayerProfile.RangeOf(PlayerProfile.AgeOn(b, today))) : string.Empty,
                level,
                sport.Levels.FirstOrDefault(l => l.Tier == level)?.Name ?? level.ToString(),
                first.Experience,
                LastActivity.Bucket(first.LastActiveAt, now, PersianFormat.TehranToday),
                windows.Select(m =>
                {
                    var w = m.Row.Window;
                    var start = Math.Max(w.StartMinute, criteria.FromMinute);
                    return new MatchingWindowView(
                        w.AvailabilityId,
                        w.VenueIds.Where(venues.ContainsKey).Select(id => new NamedRef(id, venues[id].Name)).ToList(),
                        IranianWeek.Split(w.Weekdays).ToList(),
                        w.Date is { } d ? PersianFormat.JalaliAscii(d) : null,
                        TimeWindow.Format(w.StartMinute),
                        TimeWindow.Format(w.EndMinute),
                        TimeWindow.Format(start),
                        TimeWindow.Format(start + m.Overlap),
                        w.Formats);
                }).ToList(),
                signals[first.Window.PlayerId].Reliability,
                signals[first.Window.PlayerId].PublicRatingAverage,
                signals[first.Window.PlayerId].RatingCount);
        }).ToList();
    }

    private static DateTime TehranToUtc(DateOnly day, int minute) =>
        TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(day.ToDateTime(TimeOnly.MinValue).AddMinutes(minute), DateTimeKind.Unspecified), PersianFormat.Tehran);

    private static string EncodeCursor(int offset) => Convert.ToBase64String(Encoding.UTF8.GetBytes($"o:{offset}"));

    private static int DecodeCursor(string? cursor)
    {
        if (string.IsNullOrWhiteSpace(cursor))
            return 0;
        try
        {
            var text = Encoding.UTF8.GetString(Convert.FromBase64String(cursor));
            return text.StartsWith("o:", StringComparison.Ordinal) && int.TryParse(text[2..], out var offset) && offset >= 0 ? offset : 0;
        }
        catch (FormatException)
        {
            return 0;
        }
    }
}
