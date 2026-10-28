using Microsoft.EntityFrameworkCore.Design;
using Rallyto.Infrastructure.Core.Persistence;

namespace Rallyto.Catalog.Infrastructure.Persistence;

internal sealed class CatalogDesignTimeFactory : IDesignTimeDbContextFactory<CatalogDbContext>
{
    public CatalogDbContext CreateDbContext(string[] args) => new(DesignTimeOptions.For<CatalogDbContext>(CatalogModule.Schema));
}
