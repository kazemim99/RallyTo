using Rallyto.Community.Domain.Search;

namespace Rallyto.Community.Domain.Ratings;

public sealed record RatingFacts(int Stars, RatingTags Tags, LevelAccuracy Level);

/// <summary>A player's public summary in one sport. Below the threshold everything but <see cref="IsNew"/> is empty.</summary>
public sealed record SportReputation(bool IsNew, double? StarAverage, int RatingCount, IReadOnlyList<RatingTags> TopTags, LevelAccuracy? LevelStatement);

/// <summary>spec player-ratings › Public reputation summary per sport, over revealed, non-removed ratings.</summary>
public static class ReputationPolicy
{
    public const int Threshold = 3;
    public const double LevelMajority = 0.6;
    public const int TopTagCount = 3;

    public static SportReputation Summarise(IReadOnlyCollection<RatingFacts> ratings)
    {
        if (ratings.Count < Threshold)
            return new SportReputation(true, null, 0, [], null);
        var average = Math.Round(ratings.Average(r => r.Stars), 1, MidpointRounding.AwayFromZero);
        var topTags = Enum.GetValues<RatingTags>()
            .Where(t => t != RatingTags.None)
            .Select(t => (Tag: t, Count: ratings.Count(r => r.Tags.HasFlag(t))))
            .Where(x => x.Count > 0)
            .OrderByDescending(x => x.Count)
            .ThenBy(x => x.Tag)
            .Take(TopTagCount)
            .Select(x => x.Tag)
            .ToList();
        var majority = ratings.GroupBy(r => r.Level).OrderByDescending(g => g.Count()).First();
        LevelAccuracy? statement = majority.Count() >= LevelMajority * ratings.Count ? majority.Key : null;
        return new SportReputation(false, average, ratings.Count, topTags, statement);
    }
}

public enum CommitmentKind
{
    Played = 1,
    NoShow = 2,
    LateCancellation = 3,
}

/// <summary>spec player-ratings › Reliability tier. The numeric score is never shown to players.</summary>
public static class ReliabilityPolicy
{
    public const int Window = 20;
    public const int MinCommitments = 3;

    /// <param name="newestFirst">Resolved commitments, newest first; only the first 20 count.</param>
    public static double? Score(IReadOnlyList<CommitmentKind> newestFirst)
    {
        var recent = newestFirst.Take(Window).ToList();
        var played = recent.Count(k => k == CommitmentKind.Played);
        var denominator = played + recent.Count(k => k == CommitmentKind.NoShow) + 0.5 * recent.Count(k => k == CommitmentKind.LateCancellation);
        return denominator == 0 ? null : played / denominator;
    }

    public static ReliabilityTier Tier(IReadOnlyList<CommitmentKind> newestFirst)
    {
        if (newestFirst.Take(Window).Count() < MinCommitments || Score(newestFirst) is not { } score)
            return ReliabilityTier.New;
        return score >= 0.90 ? ReliabilityTier.High : score >= 0.75 ? ReliabilityTier.Good : ReliabilityTier.Low;
    }
}
