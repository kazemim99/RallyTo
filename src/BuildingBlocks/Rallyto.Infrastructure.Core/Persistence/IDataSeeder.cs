namespace Rallyto.Infrastructure.Core.Persistence;

/// <summary>
/// Inserts reference data a context needs to work (for example Catalog's provinces and sports). Runs after the
/// migrations at startup and must be idempotent: it only adds what is missing.
/// </summary>
public interface IDataSeeder
{
    Task SeedAsync(CancellationToken cancellationToken = default);
}
