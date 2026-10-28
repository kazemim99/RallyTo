using Microsoft.EntityFrameworkCore;
using Rallyto.Community.Application.Abstractions;
using Rallyto.Community.Domain.Matches;
using Rallyto.Community.Domain.Players;
using Rallyto.Community.Infrastructure.Persistence;
using Rallyto.Messaging.Application.Abstractions;

namespace Rallyto.Host.Composition;

/// <summary>Messaging's view of Community's players, in-process (design D3).</summary>
public sealed class InProcessPlayerRelationshipReader(CommunityDbContext community, IPlayerProfileRepository profiles) : IPlayerRelationshipReader
{
    /// <summary>A place in a game that is on or was played; cancelled and expired games do not count.</summary>
    private static readonly MatchStatus[] Shared = [MatchStatus.Open, MatchStatus.Pending, MatchStatus.Confirmed, MatchStatus.Completed, MatchStatus.Disputed, MatchStatus.Unconfirmed];

    public async Task<PlayerContact> FindContactAsync(Guid viewerId, Guid playerId, CancellationToken cancellationToken)
    {
        var viewer = await profiles.GetAsync(viewerId, cancellationToken);
        if (viewer is null)
            return new PlayerContact(false, null);
        var subject = await profiles.GetAsync(playerId, cancellationToken);
        if (subject is null)
            return new PlayerContact(true, null);
        var blocked = await community.Blocks.AnyAsync(b => (b.BlockerId == viewerId && b.BlockedId == playerId) || (b.BlockerId == playerId && b.BlockedId == viewerId), cancellationToken);
        return VisibilityPolicy.CanSee(VisibilityPolicy.FactsOf(viewer), VisibilityPolicy.FactsOf(subject), blocked)
            ? new PlayerContact(true, subject.DisplayName)
            : new PlayerContact(true, null);
    }

    public Task<bool> ShareMatchAsync(Guid a, Guid b, CancellationToken cancellationToken) =>
        community.Matches.AnyAsync(m => Shared.Contains(m.Status)
                                        && m.Participants.Any(p => p.PlayerId == a && (p.State == ParticipantState.Host || p.State == ParticipantState.Accepted))
                                        && m.Participants.Any(p => p.PlayerId == b && (p.State == ParticipantState.Host || p.State == ParticipantState.Accepted)),
            cancellationToken);

    public Task<IReadOnlyDictionary<Guid, string>> DisplayNamesAsync(IReadOnlyCollection<Guid> userIds, CancellationToken cancellationToken) =>
        profiles.DisplayNamesAsync(userIds, cancellationToken);
}

public sealed class InProcessBlockReader(CommunityDbContext community) : IBlockReader
{
    public Task<bool> IsBlockedEitherWayAsync(Guid a, Guid b, CancellationToken cancellationToken) =>
        community.Blocks.AnyAsync(x => (x.BlockerId == a && x.BlockedId == b) || (x.BlockerId == b && x.BlockedId == a), cancellationToken);

    public async Task<BlockSets> BlocksOfAsync(Guid userId, CancellationToken cancellationToken)
    {
        var blocks = await community.Blocks.AsNoTracking()
            .Where(x => x.BlockerId == userId || x.BlockedId == userId)
            .Select(x => new { x.BlockerId, x.BlockedId })
            .ToListAsync(cancellationToken);
        return new BlockSets(
            blocks.Where(x => x.BlockerId == userId).Select(x => x.BlockedId).ToHashSet(),
            blocks.Where(x => x.BlockedId == userId).Select(x => x.BlockerId).ToHashSet());
    }
}

/// <summary>A match's roster and a title for its group conversation, e.g. «پدل · مجموعه تنیس استقلال».</summary>
public sealed class InProcessMatchRosterReader(CommunityDbContext community, ICatalogReader catalog) : IMatchRosterReader
{
    public async Task<MatchRoster?> GetAsync(Guid matchId, CancellationToken cancellationToken)
    {
        var match = await community.Matches.AsNoTracking().FirstOrDefaultAsync(m => m.Id == matchId, cancellationToken);
        if (match is null)
            return null;
        var sport = (await catalog.SportsAsync(cancellationToken)).FirstOrDefault(s => s.Id == match.SportId);
        var venue = (await catalog.VenuesAsync([match.VenueId], cancellationToken)).GetValueOrDefault(match.VenueId);
        var title = string.Join(" · ", new[] { sport?.NameFa, venue?.Name }.OfType<string>());
        return new MatchRoster(match.Id, match.Capacity, title, match.PlayerIds());
    }
}
