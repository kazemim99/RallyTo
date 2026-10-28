using Microsoft.EntityFrameworkCore;
using Rallyto.Catalog.Application.Abstractions;
using Rallyto.Community.Domain.Matches;
using Rallyto.Community.Infrastructure.Persistence;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Host.Composition;

/// <summary>Catalog's view of Community's future games, in-process (design D3).</summary>
public sealed class InProcessFutureMatchReader(CommunityDbContext community, TimeProvider clock) : IFutureMatchReader
{
    public Task<bool> FormatInUseAsync(Guid sportId, PlayFormat format, CancellationToken cancellationToken)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        return community.Matches.AnyAsync(m => m.SportId == sportId && m.Format == format && m.StartsAt > now
                                               && (m.Status == MatchStatus.Open || m.Status == MatchStatus.Pending || m.Status == MatchStatus.Confirmed),
            cancellationToken);
    }
}
