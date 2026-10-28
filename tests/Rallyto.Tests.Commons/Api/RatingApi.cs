namespace Rallyto.Tests.Commons.Api;

public sealed record AttendanceView(bool Open, DateTime ClosesAt, string? MyAnswer, string? MyOutcome, DateTime? ResolvedAt, IReadOnlyList<Guid> CanRate);

public sealed record MatchAttendance(Guid Id, string Status, IReadOnlyList<ParticipantOutcome>? Participants, AttendanceView? Attendance);

public sealed record ParticipantOutcome(Guid UserId, string State, string? Outcome);

public sealed record SportReputationView(Guid SportId, bool IsNew, double? StarAverage, int RatingCount, IReadOnlyList<string> TopTags, string? LevelStatement);

public sealed record ReputationView(string Reliability, IReadOnlyList<SportReputationView> Sports);

public sealed record ProfileReputation(Guid UserId, ReputationView Reputation);

public sealed record RatingReceipt(Guid Id);

public sealed record AdminRatingView(
    Guid Id,
    Guid MatchId,
    Guid SportId,
    Guid RaterId,
    string RaterName,
    Guid RateeId,
    int Stars,
    IReadOnlyList<string> Tags,
    string LevelAccuracy,
    string? PrivateNote,
    bool Revealed,
    string? RemovalReason);

public static class RatingApi
{
    public static Task<ApiResponse<MatchAttendance>> AnswerAsync(HttpClient client, Guid matchId, string answer, params Guid[] noShows) =>
        client.PostApiAsync<MatchAttendance>($"{MatchApi.Matches}/{matchId}/attendance", new { answer, noShowPlayerIds = noShows });

    public static async Task<MatchAttendance> MatchAsync(HttpClient client, Guid matchId) =>
        (await client.GetApiAsync<MatchAttendance>($"{MatchApi.Matches}/{matchId}")).Data!;

    public static object Rating(Guid rateeId, int stars = 4, string[]? tags = null, string? level = "AboutRight", string? note = null) =>
        new { rateeId, stars, tags = tags ?? ["OnTime"], levelAccuracy = level, privateNote = note };

    public static Task<ApiResponse<RatingReceipt>> RateAsync(HttpClient client, Guid matchId, object rating) =>
        client.PostApiAsync<RatingReceipt>($"{MatchApi.Matches}/{matchId}/ratings", rating);

    public static async Task<ReputationView> ReputationOfAsync(HttpClient viewer, Guid playerId) =>
        (await viewer.GetApiAsync<ProfileReputation>($"/api/v1/players/{playerId}")).Data!.Reputation;

    public static async Task<IReadOnlyList<AdminRatingView>> AdminRatingsAsync(HttpClient admin, Guid playerId) =>
        (await admin.GetApiAsync<List<AdminRatingView>>($"/api/v1/admin/players/{playerId}/ratings")).Data!;
}
