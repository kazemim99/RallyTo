using Microsoft.EntityFrameworkCore.Design;
using Rallyto.Infrastructure.Core.Persistence;

namespace Rallyto.Community.Infrastructure.Persistence;

internal sealed class CommunityDesignTimeFactory : IDesignTimeDbContextFactory<CommunityDbContext>
{
    public CommunityDbContext CreateDbContext(string[] args) => new(DesignTimeOptions.For<CommunityDbContext>(CommunityModule.Schema));
}
