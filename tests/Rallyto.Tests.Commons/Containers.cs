using Npgsql;
using Testcontainers.PostgreSql;
using Testcontainers.Redis;

namespace Rallyto.Tests.Commons;

/// <summary>
/// One PostgreSQL and one Redis container per test process, started on first use. Each host factory gets its
/// own database inside the shared PostgreSQL server (AsanRezerve's PostgresTestContainerFixture pattern).
/// </summary>
public static class TestContainers
{
    private static readonly Lazy<Task<PostgreSqlContainer>> Postgres = new(async () =>
    {
        var container = new PostgreSqlBuilder("postgres:16-alpine").Build();
        await container.StartAsync();
        return container;
    });

    private static readonly Lazy<Task<RedisContainer>> Redis = new(async () =>
    {
        var container = new RedisBuilder("redis:7-alpine").Build();
        await container.StartAsync();
        return container;
    });

    public static async Task<string> CreateDatabaseAsync(string name)
    {
        var server = await Postgres.Value;
        await using var connection = new NpgsqlConnection(server.GetConnectionString());
        await connection.OpenAsync();
        await using (var command = new NpgsqlCommand($"CREATE DATABASE \"{name}\"", connection))
            await command.ExecuteNonQueryAsync();
        return new NpgsqlConnectionStringBuilder(server.GetConnectionString()) { Database = name }.ConnectionString;
    }

    public static async Task<string> RedisConnectionStringAsync() => (await Redis.Value).GetConnectionString();
}
