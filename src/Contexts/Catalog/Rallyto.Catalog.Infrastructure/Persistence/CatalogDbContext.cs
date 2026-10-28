using Microsoft.EntityFrameworkCore;
using Rallyto.Catalog.Domain.Locations;
using Rallyto.Catalog.Domain.Sports;
using Rallyto.Catalog.Domain.Venues;
using Rallyto.Infrastructure.Core.Persistence;

namespace Rallyto.Catalog.Infrastructure.Persistence;

public sealed class CatalogDbContext(DbContextOptions<CatalogDbContext> options) : RallytoDbContext(options)
{
    public override string Schema => CatalogModule.Schema;

    public DbSet<Sport> Sports => Set<Sport>();
    public DbSet<Province> Provinces => Set<Province>();
    public DbSet<City> Cities => Set<City>();
    public DbSet<Venue> Venues => Set<Venue>();
    public DbSet<VenueCandidate> VenueCandidates => Set<VenueCandidate>();
}
