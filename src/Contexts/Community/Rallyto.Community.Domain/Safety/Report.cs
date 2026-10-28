using Rallyto.Core.Domain.Base;
using Rallyto.Core.Domain.Exceptions;

namespace Rallyto.Community.Domain.Safety;

public enum ReportTargetType
{
    Player = 1,
    Message = 2,
    Post = 3,
    Photo = 4,
}

public enum ReportReason
{
    Harassment = 1,
    InappropriateContent = 2,
    FakeProfile = 3,
    Spam = 4,
    UnsafeBehaviour = 5,
    Underage = 6,
    Other = 7,
}

public enum ReportStatus
{
    Open = 1,
    Resolved = 2,
    Dismissed = 3,
}

/// <summary>The target as it was when reported; moderation works after an edit or a deletion (design D8, D11).</summary>
public sealed record ReportEvidence(string? Text, string? DisplayName, string? Bio, string? PhotoUrl, DateTime? SentAt);

/// <summary>A player's report on another player, a message, a play post or a profile photo (spec trust-safety).</summary>
public sealed class Report : AggregateRoot<Guid>
{
    public const int MaxDetailsLength = 1000;
    public static readonly TimeSpan ReporterWindow = TimeSpan.FromDays(7);
    public const int ReportersForPriority = 3;

    private Report() { }

    public Guid ReporterId { get; private set; }
    public ReportTargetType TargetType { get; private set; }
    public string TargetId { get; private set; } = string.Empty;

    /// <summary>The player responsible for the target: the profile owner, the sender or the host.</summary>
    public Guid TargetUserId { get; private set; }

    public ReportReason Reason { get; private set; }
    public string? Details { get; private set; }
    public ReportEvidence Evidence { get; private set; } = new(null, null, null, null, null);
    public ReportStatus Status { get; private set; }
    public DateTime ReportedAt { get; private set; }
    public DateTime? ResolvedAt { get; private set; }
    public Guid? ResolvedBy { get; private set; }
    public string? ResolutionNote { get; private set; }

    public bool IsOpen => Status == ReportStatus.Open;

    public static Report File(Guid reporterId, ReportTargetType targetType, string targetId, Guid targetUserId, ReportReason reason, string? details,
        ReportEvidence evidence, DateTime now)
    {
        if (reporterId == targetUserId)
            throw new BusinessRuleViolationException("CANNOT_REPORT_SELF", "نمی‌توانید از خودتان گزارش بدهید.");
        if (!Enum.IsDefined(targetType) || !Enum.IsDefined(reason))
            throw new BusinessRuleViolationException("INVALID_REPORT", "نوع یا دلیل گزارش معتبر نیست.");
        var text = string.IsNullOrWhiteSpace(details) ? null : details.Trim();
        if (text is { Length: > MaxDetailsLength })
            throw new BusinessRuleViolationException("DETAILS_TOO_LONG", $"توضیحات حداکثر {MaxDetailsLength} نویسه است.");
        return new Report
        {
            Id = Guid.NewGuid(),
            ReporterId = reporterId,
            TargetType = targetType,
            TargetId = targetId,
            TargetUserId = targetUserId,
            Reason = reason,
            Details = text,
            Evidence = evidence,
            Status = ReportStatus.Open,
            ReportedAt = now,
        };
    }

    public void Resolve(Guid adminId, string? note, DateTime now) => Close(ReportStatus.Resolved, adminId, note, now);

    public void Dismiss(Guid adminId, string reason, DateTime now)
    {
        if (string.IsNullOrWhiteSpace(reason))
            throw new BusinessRuleViolationException("REASON_REQUIRED", "دلیل را بنویسید.");
        Close(ReportStatus.Dismissed, adminId, reason, now);
    }

    private void Close(ReportStatus status, Guid adminId, string? note, DateTime now)
    {
        if (!IsOpen)
            throw new InvalidAggregateStateException("REPORT_CLOSED", "این گزارش قبلاً بررسی شده است.");
        Status = status;
        ResolvedAt = now;
        ResolvedBy = adminId;
        ResolutionNote = string.IsNullOrWhiteSpace(note) ? null : note.Trim();
    }
}

/// <summary>spec trust-safety › Admin report queue: which targets are worked first. Nothing here acts on an account.</summary>
public static class ReportPriority
{
    public static bool IsHighReason(ReportReason reason) => reason is ReportReason.Harassment or ReportReason.Underage;

    /// <param name="openReports">The open reports on one target.</param>
    public static bool IsHigh(IReadOnlyCollection<Report> openReports, DateTime now) =>
        openReports.Any(r => IsHighReason(r.Reason))
        || openReports.Where(r => r.ReportedAt >= now - Report.ReporterWindow).Select(r => r.ReporterId).Distinct().Count() >= Report.ReportersForPriority;
}

public enum ModerationActionType
{
    Warn = 1,
    RemovePhoto = 2,
    HidePost = 3,
    DeleteMessage = 4,
    Suspend = 5,
    LiftSuspension = 6,
    Ban = 7,
    CorrectGender = 8,
}

/// <summary>An admin's action on a player, with the related report (spec trust-safety › Admin actions).</summary>
public sealed class ModerationAction : Entity<Guid>
{
    private ModerationAction() { }

    public Guid AdminId { get; private set; }
    public Guid TargetUserId { get; private set; }
    public ModerationActionType Action { get; private set; }
    public string Reason { get; private set; } = string.Empty;
    public Guid? ReportId { get; private set; }

    /// <summary>What the action was applied to, e.g. the message or match id, or the suspension end.</summary>
    public string? Subject { get; private set; }

    public DateTime At { get; private set; }

    public static ModerationAction Record(Guid adminId, Guid targetUserId, ModerationActionType action, string reason, Guid? reportId, string? subject, DateTime now)
    {
        if (string.IsNullOrWhiteSpace(reason))
            throw new BusinessRuleViolationException("REASON_REQUIRED", "دلیل را بنویسید.");
        return new ModerationAction
        {
            Id = Guid.NewGuid(),
            AdminId = adminId,
            TargetUserId = targetUserId,
            Action = action,
            Reason = reason.Trim(),
            ReportId = reportId,
            Subject = subject,
            At = now,
        };
    }
}

/// <summary>One line of the admin audit log, built from every context's <c>admin.action-recorded</c> events (spec trust-safety).</summary>
public sealed class AdminAuditEntry : Entity<Guid>
{
    private AdminAuditEntry() { }

    public Guid AdminId { get; private set; }
    public string Action { get; private set; } = string.Empty;
    public string TargetType { get; private set; } = string.Empty;
    public string TargetId { get; private set; } = string.Empty;
    public Guid? TargetUserId { get; private set; }
    public string? Reason { get; private set; }
    public DateTime At { get; private set; }

    /// <param name="eventId">The source event id, so a redelivered event is stored once.</param>
    public static AdminAuditEntry Of(Guid eventId, Guid adminId, string action, string targetType, string targetId, Guid? targetUserId, string? reason, DateTime at) =>
        new() { Id = eventId, AdminId = adminId, Action = action, TargetType = targetType, TargetId = targetId, TargetUserId = targetUserId, Reason = reason, At = at };
}
