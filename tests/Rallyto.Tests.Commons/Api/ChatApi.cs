namespace Rallyto.Tests.Commons.Api;

public sealed record ConversationSummary(
    Guid Id,
    string Kind,
    Guid? MatchId,
    string Title,
    Guid? OtherUserId,
    string? LastMessage,
    DateTime? LastMessageAt,
    int UnreadCount,
    bool IsRequest,
    bool CanSend,
    bool Muted);

public sealed record MessageView(Guid Id, Guid ConversationId, Guid SenderId, string SenderName, string? Body, bool Deleted, DateTime SentAt, bool ReadByOthers, string ClientMessageId);

public sealed record MessagePage(IReadOnlyList<MessageView> Items, string? NextCursor);

public sealed record UnreadCounts(int Conversations, int Requests);

public static class ChatApi
{
    public const string Conversations = "/api/v1/conversations";

    public static async Task<ConversationSummary> OpenDirectAsync(HttpClient client, Guid playerId) =>
        (await client.PostApiAsync<ConversationSummary>($"{Conversations}/direct", new { playerId })).Data
        ?? throw new InvalidOperationException("open direct conversation failed");

    public static Task<ApiResponse<MessageView>> SendAsync(HttpClient client, Guid conversationId, string body, string? clientMessageId = null) =>
        client.PostApiAsync<MessageView>($"{Conversations}/{conversationId}/messages", new { clientMessageId = clientMessageId ?? Guid.NewGuid().ToString("N"), body });

    public static async Task<IReadOnlyList<ConversationSummary>> ListAsync(HttpClient client, string box = "inbox") =>
        (await client.GetApiAsync<List<ConversationSummary>>($"{Conversations}?box={box}")).Data!;

    public static async Task<MessagePage> HistoryAsync(HttpClient client, Guid conversationId, string? cursor = null) =>
        (await client.GetApiAsync<MessagePage>($"{Conversations}/{conversationId}/messages{(cursor is null ? "" : $"?before={Uri.EscapeDataString(cursor)}")}")).Data!;
}
