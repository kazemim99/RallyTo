namespace Rallyto.Tests.Commons.Api;

public sealed record NotificationView(Guid Id, string Code, string Category, string Title, string Body, string? DeepLink, DateTime CreatedAt, bool IsRead);

public sealed record UnreadNotifications(int Count);

public sealed record PreferencesView(bool PushMatches, bool PushChat, bool PushRatings, bool PushSavedSearches, bool QuietHoursEnabled, string QuietStart, string QuietEnd);

public static class NotificationApi
{
    public const string Notifications = "/api/v1/notifications";
    public const string DeviceTokens = "/api/v1/device-tokens";

    public static async Task<IReadOnlyList<NotificationView>> InboxAsync(HttpClient client) =>
        (await client.GetApiAsync<PagedResult<NotificationView>>(Notifications)).Data!.Items;

    public static async Task<int> UnreadAsync(HttpClient client) =>
        (await client.GetApiAsync<UnreadNotifications>($"{Notifications}/unread-count")).Data!.Count;

    public static Task<ApiResponse<Empty>> RegisterAsync(HttpClient client, string token, string platform = "android") =>
        client.PostApiAsync<Empty>(DeviceTokens, new { token, platform });

    public static Task<ApiResponse<PreferencesView>> SetPreferencesAsync(HttpClient client, bool matches = true, bool chat = true, bool ratings = true,
        bool savedSearches = true, bool quiet = true, string quietStart = "23:00", string quietEnd = "08:00") =>
        client.PutApiAsync<PreferencesView>($"{Notifications}/preferences",
            new { pushMatches = matches, pushChat = chat, pushRatings = ratings, pushSavedSearches = savedSearches, quietHoursEnabled = quiet, quietStart, quietEnd });
}
