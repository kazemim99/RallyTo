using Rallyto.Community.Domain.Availabilities;
using Rallyto.Community.Domain.Players;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Community.Domain.Search;

/// <summary>A resolved search: defaults already applied (spec partner-search › Search input and defaults).</summary>
public sealed record SearchCriteria(
    Guid SportId,
    int CityId,
    IReadOnlyList<Guid> VenueIds,
    DateOnly? Date,
    IranianWeekdays Weekdays,
    int FromMinute,
    int ToMinute,
    LevelTier MinLevel,
    LevelTier MaxLevel,
    Gender? Gender,
    PlayFormat? Format);

/// <summary>Everything about one availability window and its owner that matching depends on.</summary>
public sealed record WindowCandidate(
    Guid AvailabilityId,
    Guid PlayerId,
    Gender Gender,
    ProfileVisibility Visibility,
    ProfileStatus ProfileStatus,
    LevelTier? Level,
    Guid SportId,
    int CityId,
    AvailabilityStatus Status,
    AvailabilityKind Kind,
    IranianWeekdays Weekdays,
    DateOnly? Date,
    DateOnly? ValidUntil,
    int StartMinute,
    int EndMinute,
    IReadOnlyList<Guid> VenueIds,
    IReadOnlyList<PlayFormat> Formats);

/// <summary>
/// The single definition of "this window is a result for this searcher" (spec partner-search › Player results and
/// Search exclusions). Search results and saved-search alerts both use it.
/// </summary>
public static class PartnerMatchRules
{
    public const int MinimumOverlap = 60;

    /// <returns>The overlapping minutes, or 0 when the window is not a result.</returns>
    public static int Match(SearchCriteria criteria, PlayerVisibilityFacts searcher, WindowCandidate window, bool blockedEitherWay, DateOnly todayTehran)
    {
        if (window.PlayerId == searcher.UserId || window.SportId != criteria.SportId || window.Status != AvailabilityStatus.Active)
            return 0;
        if (!VisibilityPolicy.CanSee(searcher, new PlayerVisibilityFacts(window.PlayerId, window.Gender, window.Visibility, window.ProfileStatus), blockedEitherWay))
            return 0;
        if (window.CityId != criteria.CityId)
            return 0;
        if (criteria.VenueIds.Count > 0 && !window.VenueIds.Intersect(criteria.VenueIds).Any())
            return 0;
        if (window.Level is not { } level || !LevelTiers.IsWithin(level, criteria.MinLevel, criteria.MaxLevel))
            return 0;
        if (criteria.Gender is { } gender && window.Gender != gender)
            return 0;
        if (criteria.Format is { } format && !window.Formats.Contains(format))
            return 0;
        if (!SharesDay(criteria, window, todayTehran))
            return 0;

        var overlap = Math.Min(window.EndMinute, criteria.ToMinute) - Math.Max(window.StartMinute, criteria.FromMinute);
        return overlap >= MinimumOverlap ? overlap : 0;
    }

    private static bool SharesDay(SearchCriteria criteria, WindowCandidate window, DateOnly todayTehran)
    {
        if (criteria.Date is { } date)
        {
            return window.Kind == AvailabilityKind.OneOff
                ? window.Date == date
                : window.Weekdays.HasFlag(IranianWeek.Of(date)) && (window.ValidUntil is null || window.ValidUntil >= date);
        }

        var days = criteria.Weekdays == IranianWeekdays.None ? (IranianWeekdays)127 : criteria.Weekdays;
        return window.Kind == AvailabilityKind.OneOff
            ? window.Date is { } d && d >= todayTehran && days.HasFlag(IranianWeek.Of(d))
            : (window.Weekdays & days) != IranianWeekdays.None && (window.ValidUntil is null || window.ValidUntil >= todayTehran);
    }
}

public enum ReliabilityTier
{
    Unknown = 0,
    New = 1,
    Low = 2,
    Good = 3,
    High = 4,
}

public sealed record RankingInput(
    Guid PlayerId,
    int LevelDistance,
    int OverlapMinutes,
    int RequestedMinutes,
    ReliabilityTier Reliability,
    double? PublicRatingAverage,
    double DaysSinceActive,
    bool PlayedTogether,
    DateTime LastActiveAt);

/// <summary>Weights of the fit score; configurable (design D6).</summary>
public sealed record RankingWeights(double Level = 0.35, double Overlap = 0.25, double Reliability = 0.15, double Rating = 0.10, double Activity = 0.10, double PlayedTogether = 0.05);

/// <summary>Deterministic fit score for player results (spec partner-search › Ranking of player results).</summary>
public static class PartnerRankingPolicy
{
    public static double Score(RankingInput input, RankingWeights weights)
    {
        var level = 1.0 - Math.Min(input.LevelDistance, 4) / 4.0;
        var overlap = input.RequestedMinutes <= 0 ? 1.0 : Math.Min(1.0, input.OverlapMinutes / (double)input.RequestedMinutes);
        var reliability = input.Reliability switch
        {
            ReliabilityTier.High => 1.0,
            ReliabilityTier.Good => 0.75,
            ReliabilityTier.Low => 0.0,
            _ => 0.5,
        };
        var rating = input.PublicRatingAverage is { } avg ? Math.Clamp((avg - 1) / 4, 0, 1) : 0.5;
        var activity = Math.Max(0, 1 - input.DaysSinceActive / 30);
        return weights.Level * level + weights.Overlap * overlap + weights.Reliability * reliability
               + weights.Rating * rating + weights.Activity * activity + weights.PlayedTogether * (input.PlayedTogether ? 1 : 0);
    }

    /// <summary>Highest score first; ties by most recent activity, then by player id.</summary>
    public static IReadOnlyList<RankingInput> Rank(IEnumerable<RankingInput> inputs, RankingWeights weights) =>
        inputs.Select(i => (Input: i, Score: Math.Round(Score(i, weights), 6)))
            .OrderByDescending(x => x.Score)
            .ThenByDescending(x => x.Input.LastActiveAt)
            .ThenBy(x => x.Input.PlayerId)
            .Select(x => x.Input)
            .ToList();
}
