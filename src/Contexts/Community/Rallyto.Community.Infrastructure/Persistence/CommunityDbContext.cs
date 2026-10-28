using Microsoft.EntityFrameworkCore;
using Rallyto.Community.Domain.Players;
using Rallyto.Infrastructure.Core.Persistence;

namespace Rallyto.Community.Infrastructure.Persistence;

public sealed class CommunityDbContext(DbContextOptions<CommunityDbContext> options) : RallytoDbContext(options)
{
    public override string Schema => CommunityModule.Schema;

    public DbSet<PlayerProfile> PlayerProfiles => Set<PlayerProfile>();
    public DbSet<Block> Blocks => Set<Block>();
    public DbSet<Domain.Availabilities.Availability> Availability => Set<Domain.Availabilities.Availability>();
    public DbSet<Domain.Search.SavedSearch> SavedSearches => Set<Domain.Search.SavedSearch>();
    public DbSet<Domain.Matches.Match> Matches => Set<Domain.Matches.Match>();
    public DbSet<Domain.Matches.LateCancellation> LateCancellations => Set<Domain.Matches.LateCancellation>();
    public DbSet<Domain.Ratings.Rating> Ratings => Set<Domain.Ratings.Rating>();
    public DbSet<Domain.Safety.Report> Reports => Set<Domain.Safety.Report>();
    public DbSet<Domain.Safety.ModerationAction> ModerationActions => Set<Domain.Safety.ModerationAction>();
    public DbSet<Domain.Safety.AdminAuditEntry> AdminAuditEntries => Set<Domain.Safety.AdminAuditEntry>();

    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        SyncSavedSearchKeys();
        return base.SaveChanges(acceptAllChangesOnSuccess);
    }

    public override Task<int> SaveChangesAsync(bool acceptAllChangesOnSuccess, CancellationToken cancellationToken = default)
    {
        SyncSavedSearchKeys();
        return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
    }

    /// <summary>Copies a saved search's sport and city out of its JSON criteria into indexed columns.</summary>
    private void SyncSavedSearchKeys()
    {
        foreach (var entry in ChangeTracker.Entries<Domain.Search.SavedSearch>().Where(e => e.State is EntityState.Added or EntityState.Modified))
        {
            entry.Property("sport_id").CurrentValue = entry.Entity.Criteria.SportId;
            entry.Property("city_id").CurrentValue = entry.Entity.Criteria.CityId;
        }
    }
}
