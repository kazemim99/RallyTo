using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Rallyto.Community.Application.Matches;
using Rallyto.Community.Domain.Matches;

namespace Rallyto.Community.Infrastructure.Persistence;

internal sealed class MatchConfiguration : IEntityTypeConfiguration<Match>
{
    public void Configure(EntityTypeBuilder<Match> builder)
    {
        builder.ToTable("matches");
        builder.HasKey(m => m.Id);
        builder.Property(m => m.Id).ValueGeneratedNever();
        builder.Property(m => m.Visibility).HasConversion<string>().HasMaxLength(16);
        builder.Property(m => m.Status).HasConversion<string>().HasMaxLength(16);
        builder.Property(m => m.Format).HasConversion<string>().HasMaxLength(16);
        builder.Property(m => m.PartnerGender).HasConversion<string>().HasMaxLength(8);
        builder.Property(m => m.MinLevel).HasConversion<int>();
        builder.Property(m => m.MaxLevel).HasConversion<int>();
        builder.Property(m => m.CostNote).HasMaxLength(200);
        builder.Property(m => m.Description).HasMaxLength(500);
        builder.Property(m => m.CancelReason).HasMaxLength(300);
        builder.Property(m => m.ShareToken).HasMaxLength(32).IsRequired();
        // Concurrent accepts of the last spot are serialised by PostgreSQL's row version (design D4).
        builder.Property(m => m.Version).IsRowVersion();
        builder.HasIndex(m => m.ShareToken).IsUnique();
        builder.HasIndex(m => new { m.SportId, m.Status, m.CityId, m.StartsAt });
        builder.HasIndex(m => new { m.Status, m.StartsAt });
        builder.HasIndex(m => m.HostId);
        builder.Ignore(m => m.PlayerCount);
        builder.Ignore(m => m.OpenSpots);
        builder.Ignore(m => m.IsFinished);
        builder.Ignore(m => m.AttendanceClosesAt);
        builder.Ignore(m => m.RatingClosesAt);
        builder.HasIndex(m => new { m.Status, m.ResolvedAt });

        builder.OwnsMany(m => m.Participants, p =>
        {
            p.ToTable("match_participants");
            p.WithOwner().HasForeignKey("match_id");
            p.Property<int>("id").ValueGeneratedOnAdd();
            p.HasKey("id");
            p.Property(x => x.State).HasConversion<string>().HasMaxLength(16);
            p.Property(x => x.Message).HasMaxLength(200);
            p.HasIndex(x => new { x.PlayerId, x.State });
            p.Ignore(x => x.Plays);
            p.Property(x => x.Attendance).HasConversion<string>().HasMaxLength(16);
            p.Property(x => x.Outcome).HasConversion<string>().HasMaxLength(16);
            p.Property(x => x.NoShowFlags).HasColumnType("uuid[]");
        });
        builder.Navigation(m => m.Participants).HasField("_participants");
    }
}

internal sealed class LateCancellationConfiguration : IEntityTypeConfiguration<LateCancellation>
{
    public void Configure(EntityTypeBuilder<LateCancellation> builder)
    {
        builder.ToTable("late_cancellations");
        builder.HasKey(l => l.Id);
        builder.Property(l => l.Id).ValueGeneratedNever();
        builder.HasIndex(l => l.PlayerId);
    }
}

internal sealed class MatchRepository(CommunityDbContext db) : IMatchRepository
{
    private static readonly MatchStatus[] Live = [MatchStatus.Open, MatchStatus.Pending, MatchStatus.Confirmed];

    /// <summary>FindAsync also returns a match added earlier in this unit of work (needed by domain event handlers).</summary>
    public async Task<Match?> GetAsync(Guid id, CancellationToken cancellationToken) => await db.Matches.FindAsync([id], cancellationToken);

    public Task<Match?> GetByShareTokenAsync(string token, CancellationToken cancellationToken) =>
        db.Matches.FirstOrDefaultAsync(m => m.ShareToken == token && m.HiddenAt == null, cancellationToken);

    public Task<bool> HasAcceptedOverlapAsync(Guid playerId, DateTime startsAt, DateTime endsAt, Guid? excludeMatchId, CancellationToken cancellationToken) =>
        db.Matches.AnyAsync(m => m.Id != excludeMatchId
                                 && Live.Contains(m.Status)
                                 && m.StartsAt < endsAt && startsAt < m.EndsAt
                                 && m.Participants.Any(p => p.PlayerId == playerId && (p.State == ParticipantState.Accepted || p.State == ParticipantState.Host)),
            cancellationToken);

    public Task<bool> HasFutureMatchInSportAsync(Guid playerId, Guid sportId, DateTime now, CancellationToken cancellationToken) =>
        db.Matches.AnyAsync(m => m.SportId == sportId && m.StartsAt > now && Live.Contains(m.Status)
                                 && m.Participants.Any(p => p.PlayerId == playerId && (p.State == ParticipantState.Host || p.State == ParticipantState.Accepted)), cancellationToken);

    public async Task<IReadOnlySet<Guid>> BusyPlayersAsync(IReadOnlyCollection<Guid> playerIds, DateTime startsAt, DateTime endsAt, CancellationToken cancellationToken) =>
        (await db.Matches
            .Where(m => m.Status == MatchStatus.Confirmed && m.StartsAt < endsAt && startsAt < m.EndsAt)
            .SelectMany(m => m.Participants)
            .Where(p => playerIds.Contains(p.PlayerId) && (p.State == ParticipantState.Accepted || p.State == ParticipantState.Host))
            .Select(p => p.PlayerId)
            .ToListAsync(cancellationToken))
        .ToHashSet();

    public Task<int> CountOpenHostedAsync(Guid hostId, DateTime now, CancellationToken cancellationToken) =>
        db.Matches.CountAsync(m => m.HostId == hostId && m.Visibility == MatchVisibility.Public && m.Status == MatchStatus.Open && m.StartsAt > now, cancellationToken);

    public Task<int> CountPendingRequestsAsync(Guid playerId, DateTime now, CancellationToken cancellationToken) =>
        db.Matches.CountAsync(m => m.StartsAt > now && m.Participants.Any(p => p.PlayerId == playerId && p.State == ParticipantState.Requested), cancellationToken);

    public async Task<IReadOnlyList<Match>> ListForPlayerAsync(Guid playerId, bool upcoming, DateTime now, CancellationToken cancellationToken)
    {
        var query = db.Matches.Where(m => m.Participants.Any(p => p.PlayerId == playerId));
        query = upcoming ? query.Where(m => m.EndsAt > now && Live.Contains(m.Status)) : query.Where(m => m.EndsAt <= now || !Live.Contains(m.Status));
        return upcoming
            ? await query.OrderBy(m => m.StartsAt).Take(100).ToListAsync(cancellationToken)
            : await query.OrderByDescending(m => m.StartsAt).Take(100).ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<Match>> ListFutureInvolvingAsync(Guid playerId, DateTime now, CancellationToken cancellationToken) =>
        await db.Matches.Where(m => m.StartsAt > now && Live.Contains(m.Status) && m.Participants.Any(p => p.PlayerId == playerId)).ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<Match>> ListOpenPostsAsync(Guid sportId, int cityId, DateTime fromUtc, DateTime toUtc, CancellationToken cancellationToken) =>
        await db.Matches.AsNoTracking()
            .Where(m => m.SportId == sportId && m.CityId == cityId && m.Visibility == MatchVisibility.Public && m.Status == MatchStatus.Open
                        && m.HiddenAt == null && m.StartsAt >= fromUtc && m.StartsAt < toUtc)
            .OrderBy(m => m.StartsAt)
            .Take(200)
            .ToListAsync(cancellationToken);

    public void Add(Match match) => db.Matches.Add(match);

    public void AddLateCancellation(LateCancellation lateCancellation) => db.LateCancellations.Add(lateCancellation);
}
