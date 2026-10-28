using Rallyto.Community.Domain.Matches;
using Rallyto.Community.Domain.Safety;

namespace Rallyto.Community.Application.Safety;

public sealed record ReportReceiptView(Guid Id, string Status);

/// <summary>The reporter sees whether a report is open or resolved, never the action taken.</summary>
public sealed record MyReportView(Guid Id, ReportTargetType TargetType, ReportReason Reason, string Status, DateTime CreatedAt);

public sealed record EvidenceView(string? Text, string? DisplayName, string? Bio, string? PhotoUrl, DateTime? SentAt);

public sealed record AdminReportView(
    Guid Id,
    Guid ReporterId,
    string ReporterName,
    ReportTargetType TargetType,
    string TargetId,
    ReportReason Reason,
    string? Details,
    EvidenceView Evidence,
    ReportStatus Status,
    DateTime CreatedAt);

public sealed record ReportGroupView(Guid TargetUserId, string TargetName, bool HighPriority, int OpenReports, int DistinctReporters, DateTime OldestReportAt, IReadOnlyList<AdminReportView> Reports);

public sealed record ModerationActionView(Guid Id, Guid AdminId, Guid TargetUserId, ModerationActionType Action, string Reason, Guid? ReportId, string? Subject, DateTime At);

public sealed record DisputeSummary(int Count, IReadOnlyList<Guid> MatchIds);

public sealed record PrivateNoteView(Guid RatingId, Guid MatchId, Guid RaterId, string RaterName, int Stars, string Note, DateTime SubmittedAt);

public sealed record TargetDetailView(
    Guid UserId,
    string DisplayName,
    Domain.Players.Gender Gender,
    bool HasPhoto,
    Domain.Search.ReliabilityTier Reliability,
    IReadOnlyList<AdminReportView> Reports,
    IReadOnlyList<ModerationActionView> Actions,
    DisputeSummary Disputes,
    IReadOnlyList<PrivateNoteView> PrivateNotes);

public sealed record AuditEntryView(Guid Id, Guid AdminId, string Action, string TargetType, string TargetId, Guid? TargetUserId, string? Reason, DateTime At);

public sealed record DisputedPlayerView(Guid UserId, string DisplayName, AttendanceAnswer? Answer, AttendanceOutcome? Outcome);

public sealed record DisputedMatchView(Guid MatchId, MatchStatus Status, Guid SportId, string Date, DateTime? ResolvedAt, IReadOnlyList<DisputedPlayerView> Players);

/// <summary>A message as the reporter saw it, read in-process from Messaging (design D3).</summary>
public sealed record MessageEvidence(Guid SenderId, string Body, DateTime SentAt);

public interface IMessageEvidenceReader
{
    /// <summary>The message, when the reporter is a member of its conversation and it is not deleted.</summary>
    Task<MessageEvidence?> ForReporterAsync(Guid reporterId, Guid messageId, CancellationToken cancellationToken);

    Task<Guid?> SenderOfAsync(Guid messageId, CancellationToken cancellationToken);
}

/// <summary>Suspensions and bans take effect through Identity (spec trust-safety), in-process through the host.</summary>
public interface IAccountModeration
{
    Task SuspendAsync(Guid userId, DateTime untilUtc, string reason, CancellationToken cancellationToken);
    Task LiftSuspensionAsync(Guid userId, string reason, CancellationToken cancellationToken);
    Task BanAsync(Guid userId, string reason, CancellationToken cancellationToken);
}

public sealed record AuditFilter(Guid? AdminId, Guid? TargetUserId, string? Action, DateTime? FromUtc, DateTime? ToUtc, int Page, int PageSize);

public interface ISafetyRepository
{
    Task<Report?> GetReportAsync(Guid id, CancellationToken cancellationToken);
    Task<bool> HasOpenReportAsync(Guid reporterId, ReportTargetType targetType, string targetId, CancellationToken cancellationToken);
    Task<IReadOnlyList<Report>> ListOpenReportsAsync(CancellationToken cancellationToken);
    Task<IReadOnlyList<Report>> ListReportsByReporterAsync(Guid reporterId, CancellationToken cancellationToken);
    Task<IReadOnlyList<Report>> ListReportsOnAsync(Guid targetUserId, CancellationToken cancellationToken);
    Task<IReadOnlyList<ModerationAction>> ListActionsOnAsync(Guid targetUserId, CancellationToken cancellationToken);
    Task<IReadOnlyList<Guid>> DisputedMatchesOfAsync(Guid playerId, DateTime since, CancellationToken cancellationToken);
    Task<IReadOnlyList<Match>> ListDisputedMatchesAsync(int take, CancellationToken cancellationToken);
    Task<(IReadOnlyList<AdminAuditEntry> Items, int Total)> AuditAsync(AuditFilter filter, CancellationToken cancellationToken);
    Task<bool> AuditEntryExistsAsync(Guid id, CancellationToken cancellationToken);
    void Add(Report report);
    void Add(ModerationAction action);
    void Add(AdminAuditEntry entry);
}

internal static class SafetyMapping
{
    public static EvidenceView ToView(ReportEvidence e) => new(e.Text, e.DisplayName, e.Bio, e.PhotoUrl, e.SentAt);

    public static AdminReportView ToView(Report r, IReadOnlyDictionary<Guid, string> names) =>
        new(r.Id, r.ReporterId, names.GetValueOrDefault(r.ReporterId, Domain.Players.PlayerProfile.DeletedDisplayName), r.TargetType, r.TargetId, r.Reason,
            r.Details, ToView(r.Evidence), r.Status, r.ReportedAt);

    public static ModerationActionView ToView(ModerationAction a) => new(a.Id, a.AdminId, a.TargetUserId, a.Action, a.Reason, a.ReportId, a.Subject, a.At);

    public static string StatusForReporter(ReportStatus status) => status == ReportStatus.Open ? "Open" : "Resolved";
}
