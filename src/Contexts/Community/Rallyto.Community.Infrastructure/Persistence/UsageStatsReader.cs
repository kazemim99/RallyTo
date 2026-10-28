using Microsoft.EntityFrameworkCore;
using Rallyto.Community.Application.Safety;
using Rallyto.Community.Domain.Matches;
using Rallyto.Community.Domain.Safety;

namespace Rallyto.Community.Infrastructure.Persistence;

internal sealed class UsageStatsReader(CommunityDbContext db) : IUsageStatsReader
{
    private static readonly MatchStatus[] Resolved = [MatchStatus.Completed, MatchStatus.Disputed, MatchStatus.Unconfirmed];
    private static readonly MatchStatus[] Confirmed = [MatchStatus.Confirmed, MatchStatus.Completed, MatchStatus.Disputed, MatchStatus.Unconfirmed];

    public async Task<UsageCounts> CountAsync(DateTime fromUtc, DateTime toUtc, CancellationToken cancellationToken)
    {
        var created = db.Matches.AsNoTracking().Where(m => m.CreatedAt >= fromUtc && m.CreatedAt < toUtc);
        var resolved = db.Matches.AsNoTracking().Where(m => m.ResolvedAt >= fromUtc && m.ResolvedAt < toUtc && Resolved.Contains(m.Status));
        return new UsageCounts(
            await db.PlayerProfiles.CountAsync(p => p.JoinedAt >= fromUtc && p.JoinedAt < toUtc, cancellationToken),
            await db.PlayerProfiles.CountAsync(p => p.LastActiveAt >= fromUtc && p.LastActiveAt < toUtc, cancellationToken),
            await created.CountAsync(m => m.Visibility == MatchVisibility.Public, cancellationToken),
            await created.CountAsync(m => m.Visibility == MatchVisibility.Private, cancellationToken),
            await db.Matches.CountAsync(m => m.StartsAt >= fromUtc && m.StartsAt < toUtc && Confirmed.Contains(m.Status), cancellationToken),
            await resolved.CountAsync(m => m.Status == MatchStatus.Completed, cancellationToken),
            await resolved.CountAsync(cancellationToken),
            await db.Reports.CountAsync(r => r.ReportedAt >= fromUtc && r.ReportedAt < toUtc, cancellationToken),
            await db.Reports.CountAsync(r => r.Status == ReportStatus.Open, cancellationToken));
    }
}
