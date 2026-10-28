using Rallyto.Community.Domain.Ratings;
using Rallyto.Community.Domain.Search;

namespace Rallyto.Community.Application.Ratings;

public sealed record SportReputationView(Guid SportId, bool IsNew, double? StarAverage, int RatingCount, IReadOnlyList<RatingTags> TopTags, LevelAccuracy? LevelStatement);

/// <summary>Public aggregates only: never individual ratings or their authors (spec player-ratings).</summary>
public sealed record ReputationView(ReliabilityTier Reliability, IReadOnlyList<SportReputationView> Sports);

public sealed record RatingReceiptView(Guid Id);

public sealed record AdminRatingView(
    Guid Id,
    Guid MatchId,
    Guid SportId,
    Guid RaterId,
    string RaterName,
    Guid RateeId,
    int Stars,
    IReadOnlyList<RatingTags> Tags,
    LevelAccuracy LevelAccuracy,
    string? PrivateNote,
    DateTime SubmittedAt,
    bool Revealed,
    DateTime? RemovedAt,
    string? RemovalReason);

public interface IRatingRepository
{
    Task<Rating?> GetAsync(Guid id, CancellationToken cancellationToken);
    Task<Rating?> FindAsync(Guid matchId, Guid raterId, Guid rateeId, CancellationToken cancellationToken);
    Task<IReadOnlySet<Guid>> RateesOfAsync(Guid matchId, Guid raterId, CancellationToken cancellationToken);
    Task<IReadOnlyList<Rating>> ListReceivedAsync(Guid rateeId, CancellationToken cancellationToken);
    Task<IReadOnlyList<Rating>> ListDueForRevealAsync(DateTime now, CancellationToken cancellationToken);
    void Add(Rating rating);
}

/// <summary>
/// Source rows for reputation and reliability, which are computed on read by the pure policies instead of being
/// kept in a separate read model (see design.md deviations).
/// </summary>
public interface IReputationReader
{
    /// <summary>Revealed, non-removed ratings received, by player and sport.</summary>
    Task<IReadOnlyDictionary<(Guid PlayerId, Guid SportId), IReadOnlyList<RatingFacts>>> CountingRatingsAsync(
        IReadOnlyCollection<Guid> playerIds, Guid? sportId, CancellationToken cancellationToken);

    /// <summary>Played and No-show participations in Completed matches and late cancellations, newest first, per player.</summary>
    Task<IReadOnlyDictionary<Guid, IReadOnlyList<CommitmentKind>>> CommitmentsAsync(IReadOnlyCollection<Guid> playerIds, CancellationToken cancellationToken);

    /// <summary>Which of <paramref name="others"/> were Played with <paramref name="playerId"/> in a Completed match.</summary>
    Task<IReadOnlySet<Guid>> PlayedWithAsync(Guid playerId, IReadOnlyCollection<Guid> others, CancellationToken cancellationToken);
}

/// <summary>Search signals for one candidate.</summary>
/// <param name="RatingCount">Revealed ratings in the sport; 0 below the public threshold, like the profile.</param>
public sealed record RankingSignals(ReliabilityTier Reliability, double? PublicRatingAverage, int RatingCount, bool PlayedTogether);

public sealed class ReputationService(IReputationReader reader)
{
    public async Task<ReputationView> ViewAsync(Guid playerId, IEnumerable<Guid> sportIds, CancellationToken cancellationToken)
    {
        var ratings = await reader.CountingRatingsAsync([playerId], null, cancellationToken);
        var commitments = await reader.CommitmentsAsync([playerId], cancellationToken);
        var sports = sportIds.Select(sportId =>
        {
            var summary = ReputationPolicy.Summarise(ratings.GetValueOrDefault((playerId, sportId)) ?? []);
            return new SportReputationView(sportId, summary.IsNew, summary.StarAverage, summary.RatingCount, summary.TopTags, summary.LevelStatement);
        }).ToList();
        return new ReputationView(ReliabilityPolicy.Tier(commitments.GetValueOrDefault(playerId) ?? []), sports);
    }

    public async Task<IReadOnlyDictionary<Guid, RankingSignals>> RankingSignalsAsync(Guid searcherId, IReadOnlyCollection<Guid> candidates, Guid sportId, CancellationToken cancellationToken)
    {
        if (candidates.Count == 0)
            return new Dictionary<Guid, RankingSignals>();
        var ratings = await reader.CountingRatingsAsync(candidates, sportId, cancellationToken);
        var commitments = await reader.CommitmentsAsync(candidates, cancellationToken);
        var playedWith = await reader.PlayedWithAsync(searcherId, candidates, cancellationToken);
        return candidates.ToDictionary(id => id, id =>
        {
            var summary = ReputationPolicy.Summarise(ratings.GetValueOrDefault((id, sportId)) ?? []);
            return new RankingSignals(ReliabilityPolicy.Tier(commitments.GetValueOrDefault(id) ?? []), summary.StarAverage, summary.RatingCount, playedWith.Contains(id));
        });
    }
}
