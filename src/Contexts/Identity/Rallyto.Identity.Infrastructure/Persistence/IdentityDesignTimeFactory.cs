using Microsoft.EntityFrameworkCore.Design;
using Rallyto.Infrastructure.Core.Persistence;

namespace Rallyto.Identity.Infrastructure.Persistence;

internal sealed class IdentityDesignTimeFactory : IDesignTimeDbContextFactory<IdentityDbContext>
{
    public IdentityDbContext CreateDbContext(string[] args) => new(DesignTimeOptions.For<IdentityDbContext>(IdentityModule.Schema));
}
