using Microsoft.EntityFrameworkCore;

namespace Rallyto.Infrastructure.Core.Persistence;

/// <summary>
/// Options for <c>dotnet ef</c> at design time: the same naming and history table as at runtime, without starting
/// the host. Each context's <c>IDesignTimeDbContextFactory</c> uses this.
/// </summary>
public static class DesignTimeOptions
{
    public static DbContextOptions<TContext> For<TContext>(string schema) where TContext : DbContext =>
        new DbContextOptionsBuilder<TContext>()
            .UseNpgsql("Host=localhost;Database=rallyto_design", npgsql => npgsql.MigrationsHistoryTable("__ef_migrations_history", schema))
            .UseSnakeCaseNamingConvention()
            .Options;
}
