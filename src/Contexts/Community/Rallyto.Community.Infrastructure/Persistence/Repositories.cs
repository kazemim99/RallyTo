using Microsoft.EntityFrameworkCore;
using Rallyto.Community.Application.Abstractions;
using Rallyto.Community.Domain.Players;

namespace Rallyto.Community.Infrastructure.Persistence;

internal sealed class PlayerProfileRepository(CommunityDbContext db) : IPlayerProfileRepository
{
    public Task<PlayerProfile?> GetAsync(Guid userId, CancellationToken cancellationToken) =>
        db.PlayerProfiles.FirstOrDefaultAsync(p => p.Id == userId, cancellationToken);

    public Task<bool> ExistsAsync(Guid userId, CancellationToken cancellationToken) =>
        db.PlayerProfiles.AnyAsync(p => p.Id == userId, cancellationToken);

    public async Task<IReadOnlyDictionary<Guid, string>> DisplayNamesAsync(IReadOnlyCollection<Guid> userIds, CancellationToken cancellationToken) =>
        await db.PlayerProfiles.AsNoTracking().Where(p => userIds.Contains(p.Id)).ToDictionaryAsync(p => p.Id, p => p.DisplayName, cancellationToken);

    public void Add(PlayerProfile profile) => db.PlayerProfiles.Add(profile);
}

internal sealed class BlockRepository(CommunityDbContext db) : IBlockRepository
{
    public Task<bool> IsBlockedEitherWayAsync(Guid a, Guid b, CancellationToken cancellationToken) =>
        db.Blocks.AnyAsync(x => (x.BlockerId == a && x.BlockedId == b) || (x.BlockerId == b && x.BlockedId == a), cancellationToken);

    public Task<Block?> GetAsync(Guid blockerId, Guid blockedId, CancellationToken cancellationToken) =>
        db.Blocks.FirstOrDefaultAsync(x => x.BlockerId == blockerId && x.BlockedId == blockedId, cancellationToken);

    public async Task<IReadOnlyList<Block>> ListByBlockerAsync(Guid blockerId, CancellationToken cancellationToken) =>
        await db.Blocks.AsNoTracking().Where(x => x.BlockerId == blockerId).OrderByDescending(x => x.BlockedAt).ToListAsync(cancellationToken);

    public void Add(Block block) => db.Blocks.Add(block);

    public void Remove(Block block) => db.Blocks.Remove(block);
}
