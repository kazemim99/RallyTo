using Npgsql;

namespace Rallyto.Tests.Commons;

/// <summary>
/// Empties every bounded-context table with one TRUNCATE before each test, keeping migration history and CAP's
/// own tables (AsanRezerve's DatabaseReset; Respawn is not used).
/// </summary>
public static class DatabaseReset
{
    private static readonly string[] Schemas = ["identity", "catalog", "community", "messaging", "notifications"];

    public static async Task ResetAsync(string connectionString, IReadOnlyCollection<string>? keepTables = null)
    {
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync();

        var tables = new List<string>();
        await using (var list = new NpgsqlCommand(
            "SELECT table_schema, table_name FROM information_schema.tables " +
            "WHERE table_type = 'BASE TABLE' AND table_schema = ANY(@schemas) AND table_name <> '__ef_migrations_history'",
            connection))
        {
            list.Parameters.AddWithValue("schemas", Schemas);
            await using var reader = await list.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                var qualified = $"\"{reader.GetString(0)}\".\"{reader.GetString(1)}\"";
                if (keepTables is null || !keepTables.Contains($"{reader.GetString(0)}.{reader.GetString(1)}"))
                    tables.Add(qualified);
            }
        }

        if (tables.Count == 0)
            return;
        await using var truncate = new NpgsqlCommand($"TRUNCATE {string.Join(", ", tables)} RESTART IDENTITY CASCADE", connection);
        await truncate.ExecuteNonQueryAsync();
    }
}
