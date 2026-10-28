using Microsoft.EntityFrameworkCore;
using Rallyto.Community.Application.Abstractions;
using Rallyto.Community.Domain.Matches;
using Rallyto.Community.Infrastructure.Persistence;
using Rallyto.Notifications.Application.Abstractions;

namespace Rallyto.Host.Composition;

/// <summary>What notification texts need from Community and Catalog, in-process (design D3).</summary>
public sealed class InProcessNotificationContextReader(CommunityDbContext community, IPlayerProfileRepository profiles, ICatalogReader catalog) : INotificationContextReader
{
    private static readonly MatchStatus[] Live = [MatchStatus.Open, MatchStatus.Pending, MatchStatus.Confirmed];

    public async Task<MatchSummary?> MatchAsync(Guid matchId, CancellationToken cancellationToken)
    {
        var match = await community.Matches.AsNoTracking().FirstOrDefaultAsync(m => m.Id == matchId, cancellationToken);
        return match is null ? null : (await SummariesAsync([match], cancellationToken))[0];
    }

    public Task<IReadOnlyDictionary<Guid, string>> DisplayNamesAsync(IReadOnlyCollection<Guid> userIds, CancellationToken cancellationToken) =>
        profiles.DisplayNamesAsync(userIds, cancellationToken);

    public async Task<IReadOnlyList<MatchSummary>> FutureMatchesAtVenueAsync(Guid venueId, DateTime now, CancellationToken cancellationToken) =>
        await SummariesAsync(await community.Matches.AsNoTracking().Where(m => m.VenueId == venueId && m.StartsAt > now && Live.Contains(m.Status)).ToListAsync(cancellationToken),
            cancellationToken);

    public async Task<IReadOnlyList<MatchSummary>> ConfirmedStartingAsync(DateTime from, DateTime to, CancellationToken cancellationToken) =>
        await SummariesAsync(await community.Matches.AsNoTracking()
            .Where(m => m.Status == MatchStatus.Confirmed && m.StartsAt > from && m.StartsAt <= to).ToListAsync(cancellationToken), cancellationToken);

    private async Task<IReadOnlyList<MatchSummary>> SummariesAsync(IReadOnlyList<Match> matches, CancellationToken cancellationToken)
    {
        if (matches.Count == 0)
            return [];
        var sports = (await catalog.SportsAsync(cancellationToken)).ToDictionary(s => s.Id, s => s.NameFa);
        var venues = await catalog.VenuesAsync(matches.Select(m => m.VenueId).Distinct().ToList(), cancellationToken);
        return matches.Select(m => new MatchSummary(m.Id, sports.GetValueOrDefault(m.SportId, string.Empty), venues.GetValueOrDefault(m.VenueId)?.Name ?? string.Empty,
            m.StartsAt, m.HostId, m.PlayerIds())).ToList();
    }
}
