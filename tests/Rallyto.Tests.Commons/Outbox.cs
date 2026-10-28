using System.Text.Encodings.Web;
using System.Text.Json;
using Npgsql;

namespace Rallyto.Tests.Commons;

/// <summary>Reads integration events from CAP's outbox, for contexts whose consumer does not exist yet.</summary>
public static class Outbox
{
    private static readonly JsonSerializerOptions Readable = new() { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

    /// <returns>Each event's payload as JSON, with Persian text unescaped so tests can search it.</returns>
    public static async Task<IReadOnlyList<string>> PublishedAsync(this RallytoHostFactory factory, string topic)
    {
        await using var connection = new NpgsqlConnection(factory.ConnectionString);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand("""SELECT "Content" FROM cap.published WHERE "Name" = @topic""", connection);
        command.Parameters.AddWithValue("topic", topic);
        var payloads = new List<string>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            using var document = JsonDocument.Parse(reader.GetString(0));
            payloads.Add(JsonSerializer.Serialize(document.RootElement.GetProperty("Value"), Readable));
        }

        return payloads;
    }
}
