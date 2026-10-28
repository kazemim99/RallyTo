namespace Rallyto.Tests.Commons.Api;

public sealed record ReportReceipt(Guid Id, string Status);

public sealed record MyReportView(Guid Id, string TargetType, string Reason, string Status, DateTime CreatedAt);

public sealed record EvidenceView(string? Text, string? DisplayName, string? Bio, string? PhotoUrl, DateTime? SentAt);

public sealed record AdminReportView(Guid Id, Guid ReporterId, string ReporterName, string TargetType, string TargetId, string Reason, string? Details, EvidenceView Evidence, string Status, DateTime CreatedAt);

public sealed record ReportGroupView(Guid TargetUserId, string TargetName, bool HighPriority, int OpenReports, int DistinctReporters, DateTime OldestReportAt, IReadOnlyList<AdminReportView> Reports);

public sealed record ModerationActionView(Guid Id, Guid AdminId, Guid TargetUserId, string Action, string Reason, Guid? ReportId, DateTime At);

public sealed record DisputeSummary(int Count, IReadOnlyList<Guid> MatchIds);

public sealed record PrivateNoteView(Guid RatingId, Guid RaterId, string RaterName, int Stars, string Note);

public sealed record TargetDetailView(
    Guid UserId,
    string DisplayName,
    string Gender,
    bool HasPhoto,
    string Reliability,
    IReadOnlyList<AdminReportView> Reports,
    IReadOnlyList<ModerationActionView> Actions,
    DisputeSummary Disputes,
    IReadOnlyList<PrivateNoteView> PrivateNotes);

public sealed record AuditEntryView(Guid Id, Guid AdminId, string Action, string TargetType, string TargetId, Guid? TargetUserId, string? Reason, DateTime At);

public sealed record DisputedPlayerView(Guid UserId, string DisplayName, string? Answer, string? Outcome);

public sealed record DisputedMatchView(Guid MatchId, string Status, string Date, IReadOnlyList<DisputedPlayerView> Players);

public static class SafetyApi
{
    public const string Reports = "/api/v1/reports";
    public const string AdminReports = "/api/v1/admin/reports";
    public const string Actions = "/api/v1/admin/moderation/actions";
    public const string Audit = "/api/v1/admin/audit";
    public const string Disputed = "/api/v1/admin/matches/disputed";

    public static Task<ApiResponse<ReportReceipt>> ReportAsync(HttpClient client, string targetType, string targetId, string reason = "Harassment", string? details = null, bool block = false) =>
        client.PostApiAsync<ReportReceipt>(Reports, new { targetType, targetId, reason, details, block });

    public static async Task<IReadOnlyList<ReportGroupView>> QueueAsync(HttpClient admin) =>
        (await admin.GetApiAsync<List<ReportGroupView>>(AdminReports)).Data!;

    public static async Task<TargetDetailView> TargetAsync(HttpClient admin, Guid userId) =>
        (await admin.GetApiAsync<TargetDetailView>($"{AdminReports}/targets/{userId}")).Data!;

    public static Task<ApiResponse<ModerationActionView>> ActAsync(HttpClient admin, Guid targetUserId, string action, string reason, Guid? reportId = null,
        string? until = null, Guid? messageId = null, Guid? matchId = null, string? warningText = null) =>
        admin.PostApiAsync<ModerationActionView>(Actions, new { targetUserId, action, reason, reportId, until, messageId, matchId, warningText });
}
