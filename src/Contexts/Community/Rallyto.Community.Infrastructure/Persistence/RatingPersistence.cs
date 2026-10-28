using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Rallyto.Community.Application.Ratings;
using Rallyto.Community.Domain.Matches;
using Rallyto.Community.Domain.Ratings;

namespace Rallyto.Community.Infrastructure.Persistence;

internal sealed class RatingConfiguration : IEntityTypeConfiguration<Rating>
{
    public void Configure(EntityTypeBuilder<Rating> builder)
    {
        builder.ToTable("ratings");
        builder.HasKey(r => r.Id);
        builder.Property(r => r.Id).ValueGeneratedNever();
        builder.Property(r => r.Tags).HasConversion<int>();
        builder.Property(r => r.Level).HasConversion<string>().HasMaxLength(16);
        builder.Property(r => r.PrivateNote).HasMaxLength(Rating.MaxNoteLength);
        builder.Property(r => r.RemovalReason).HasMaxLength(300);
        builder.HasIndex(r => new { r.MatchId, r.RaterId, r.RateeId }).IsUnique();
        builder.HasIndex(r => new { r.RateeId, r.SportId });
        builder.HasIndex(r => r.WindowClosesAt).HasFilter("revealed_at IS NULL");
        builder.Ignore(r => r.IsRevealed);
        builder.Ignore(r => r.Counts);
    }
}

internal sealed class RatingRepository(CommunityDbContext db) : IRatingRepository
{
    public async Task<Rating?> GetAsync(Guid id, CancellationToken cancellationToken) => await db.Ratings.FindAsync([id], cancellationToken);

    public Task<Rating?> FindAsync(Guid matchId, Guid raterId, Guid rateeId, CancellationToken cancellationToken) =>
        db.Ratings.FirstOrDefaultAsync(r => r.MatchId == matchId && r.RaterId == raterId && r.RateeId == rateeId, cancellationToken);

    public async Task<IReadOnlySet<Guid>> RateesOfAsync(Guid matchId, Guid raterId, CancellationToken cancellationToken) =>
        (await db.Ratings.Where(r => r.MatchId == matchId && r.RaterId == raterId).Select(r => r.RateeId).ToListAsync(cancellationToken)).ToHashSet();

    public async Task<IReadOnlyList<Rating>> ListReceivedAsync(Guid rateeId, CancellationToken cancellationToken) =>
        await db.Ratings.AsNoTracking().Where(r => r.RateeId == rateeId).OrderByDescending(r => r.SubmittedAt).ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<Rating>> ListDueForRevealAsync(DateTime now, CancellationToken cancellationToken) =>
        await db.Ratings.Where(r => r.RevealedAt == null && r.WindowClosesAt <= now).ToListAsync(cancellationToken);

    public void Add(Rating rating) => db.Ratings.Add(rating);
}

internal sealed class ReputationReader(CommunityDbContext db) : IReputationReader
{
    public async Task<IReadOnlyDictionary<(Guid PlayerId, Guid SportId), IReadOnlyList<RatingFacts>>> CountingRatingsAsync(
        IReadOnlyCollection<Guid> playerIds, Guid? sportId, CancellationToken cancellationToken)
    {
        var ids = playerIds.ToList();
        var rows = await db.Ratings.AsNoTracking()
            .Where(r => r.RevealedAt != null && r.RemovedAt == null && ids.Contains(r.RateeId) && (sportId == null || r.SportId == sportId))
            .Select(r => new { r.RateeId, r.SportId, r.Stars, r.Tags, r.Level })
            .ToListAsync(cancellationToken);
        return rows.GroupBy(r => (r.RateeId, r.SportId))
            .ToDictionary(g => g.Key, g => (IReadOnlyList<RatingFacts>)g.Select(r => new RatingFacts(r.Stars, r.Tags, r.Level)).ToList());
    }

    public async Task<IReadOnlyDictionary<Guid, IReadOnlyList<CommitmentKind>>> CommitmentsAsync(IReadOnlyCollection<Guid> playerIds, CancellationToken cancellationToken)
    {
        var ids = playerIds.ToList();
        var participations = await db.Matches.AsNoTracking()
            .Where(m => m.Status == MatchStatus.Completed)
            .SelectMany(m => m.Participants
                .Where(p => ids.Contains(p.PlayerId) && (p.Outcome == AttendanceOutcome.Played || p.Outcome == AttendanceOutcome.NoShow))
                .Select(p => new { p.PlayerId, NoShow = p.Outcome == AttendanceOutcome.NoShow, At = m.ResolvedAt!.Value }))
            .ToListAsync(cancellationToken);
        var late = await db.LateCancellations.AsNoTracking()
            .Where(l => ids.Contains(l.PlayerId))
            .Select(l => new { l.PlayerId, l.RecordedAt })
            .ToListAsync(cancellationToken);
        return participations.Select(p => (p.PlayerId, Kind: p.NoShow ? CommitmentKind.NoShow : CommitmentKind.Played, p.At))
            .Concat(late.Select(l => (l.PlayerId, Kind: CommitmentKind.LateCancellation, At: l.RecordedAt)))
            .GroupBy(c => c.PlayerId)
            .ToDictionary(g => g.Key, g => (IReadOnlyList<CommitmentKind>)g.OrderByDescending(c => c.At).Select(c => c.Kind).ToList());
    }

    public async Task<IReadOnlySet<Guid>> PlayedWithAsync(Guid playerId, IReadOnlyCollection<Guid> others, CancellationToken cancellationToken)
    {
        var ids = others.ToList();
        var together = await db.Matches.AsNoTracking()
            .Where(m => m.Status == MatchStatus.Completed && m.Participants.Any(p => p.PlayerId == playerId && p.Outcome == AttendanceOutcome.Played))
            .SelectMany(m => m.Participants.Where(p => ids.Contains(p.PlayerId) && p.Outcome == AttendanceOutcome.Played).Select(p => p.PlayerId))
            .Distinct()
            .ToListAsync(cancellationToken);
        return together.ToHashSet();
    }
}
