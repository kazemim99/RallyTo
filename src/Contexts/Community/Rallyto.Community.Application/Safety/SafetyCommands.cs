using MediatR;
using Rallyto.Community.Application.Abstractions;
using Rallyto.Community.Application.Matches;
using Rallyto.Community.Application.Players;
using Rallyto.Community.Application.Ratings;
using Rallyto.Community.Domain.Matches;
using Rallyto.Community.Domain.Players;
using Rallyto.Community.Domain.Safety;
using Rallyto.Contracts.Admin;
using Rallyto.Contracts.Community;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Core.Application.Localization;
using Rallyto.Core.Application.Results;

namespace Rallyto.Community.Application.Safety;

public sealed record FileReportCommand(ReportTargetType TargetType, string TargetId, ReportReason Reason, string? Details, bool Block) : ICommand<ReportReceiptView>;

public sealed record ListMyReportsQuery : IQuery<IReadOnlyList<MyReportView>>;

public sealed record AdminReportQueueQuery : IQuery<IReadOnlyList<ReportGroupView>>;

public sealed record AdminTargetDetailQuery(Guid UserId) : IQuery<TargetDetailView>;

public sealed record TakeModerationActionCommand(
    Guid TargetUserId,
    ModerationActionType Action,
    string Reason,
    Guid? ReportId,
    string? Until,
    Guid? MessageId,
    Guid? MatchId,
    Gender? Gender,
    string? WarningText) : ICommand<ModerationActionView>;

public sealed record DismissReportCommand(Guid ReportId, string Reason) : ICommand;

public sealed record AdminAuditQuery(Guid? AdminId, Guid? TargetUserId, string? Action, string? From, string? To, int Page = 1, int PageSize = 50)
    : IQuery<PagedResult<AuditEntryView>>;

public sealed record AdminDisputedMatchesQuery : IQuery<IReadOnlyList<DisputedMatchView>>;

/// <summary>Files a report with an evidence snapshot read from the owning context, and blocks in the same step if asked.</summary>
internal sealed class FileReportHandler(
    PlayerContext player,
    IPlayerProfileRepository profiles,
    IMatchRepository matches,
    IBlockRepository blocks,
    IMessageEvidenceReader messages,
    IFileStorage storage,
    ISafetyRepository safety,
    ICommunityUnitOfWork unitOfWork,
    TimeProvider clock) : ICommandHandler<FileReportCommand, ReportReceiptView>
{
    public async Task<ReportReceiptView> Handle(FileReportCommand request, CancellationToken cancellationToken)
    {
        var me = await player.RequireProfileAsync(cancellationToken);
        var targetId = request.TargetId?.Trim() ?? string.Empty;
        if (await safety.HasOpenReportAsync(me.Id, request.TargetType, targetId, cancellationToken))
            throw new ConflictException("ALREADY_REPORTED", "قبلاً این مورد را گزارش داده‌اید.");
        var (targetUserId, evidence) = await SnapshotAsync(me.Id, request.TargetType, targetId, cancellationToken);
        var now = clock.GetUtcNow().UtcDateTime;
        var report = Report.File(me.Id, request.TargetType, targetId, targetUserId, request.Reason, request.Details, evidence, now);
        safety.Add(report);
        if (request.Block && await blocks.GetAsync(me.Id, targetUserId, cancellationToken) is null)
            blocks.Add(Block.Create(me.Id, targetUserId, now));
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return new ReportReceiptView(report.Id, SafetyMapping.StatusForReporter(report.Status));
    }

    private async Task<(Guid TargetUserId, ReportEvidence Evidence)> SnapshotAsync(Guid reporterId, ReportTargetType type, string targetId, CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(targetId, out var id))
            throw new ValidationFailedException("INVALID_TARGET", "مورد گزارش‌شده معتبر نیست.");
        switch (type)
        {
            case ReportTargetType.Player:
            {
                var profile = await profiles.GetAsync(id, cancellationToken) ?? throw VisibilityService.PlayerNotFound();
                // A copy, so the evidence survives the player changing or removing the photo.
                var photo = profile.PhotoKey is { } key ? await storage.CopyAsync(key, "evidence", cancellationToken) : null;
                return (profile.Id, new ReportEvidence(null, profile.DisplayName, profile.Bio, photo, null));
            }
            case ReportTargetType.Photo:
            {
                var profile = await profiles.GetAsync(id, cancellationToken) ?? throw VisibilityService.PlayerNotFound();
                var copy = profile.PhotoKey is { } key ? await storage.CopyAsync(key, "evidence", cancellationToken) : null;
                return copy is null
                    ? throw new NotFoundException("عکسی برای گزارش وجود ندارد.", "PHOTO_NOT_FOUND")
                    : (profile.Id, new ReportEvidence(null, profile.DisplayName, null, copy, null));
            }
            case ReportTargetType.Post:
            {
                var match = await matches.GetAsync(id, cancellationToken);
                if (match is not { Visibility: MatchVisibility.Public })
                    throw MatchWorkflow.MatchNotFound();
                var host = (await profiles.DisplayNamesAsync([match.HostId], cancellationToken)).GetValueOrDefault(match.HostId);
                return (match.HostId, new ReportEvidence(match.Description ?? match.CostNote, host, null, null, null));
            }
            case ReportTargetType.Message:
            {
                var message = await messages.ForReporterAsync(reporterId, id, cancellationToken)
                              ?? throw new NotFoundException("پیام پیدا نشد.", "MESSAGE_NOT_FOUND");
                var sender = (await profiles.DisplayNamesAsync([message.SenderId], cancellationToken)).GetValueOrDefault(message.SenderId);
                return (message.SenderId, new ReportEvidence(message.Body, sender, null, null, message.SentAt));
            }
            default:
                throw new ValidationFailedException("INVALID_TARGET", "مورد گزارش‌شده معتبر نیست.");
        }
    }
}

internal sealed class ListMyReportsHandler(PlayerContext player, ISafetyRepository safety) : IQueryHandler<ListMyReportsQuery, IReadOnlyList<MyReportView>>
{
    public async Task<IReadOnlyList<MyReportView>> Handle(ListMyReportsQuery request, CancellationToken cancellationToken) =>
        (await safety.ListReportsByReporterAsync(player.UserId, cancellationToken))
        .Select(r => new MyReportView(r.Id, r.TargetType, r.Reason, SafetyMapping.StatusForReporter(r.Status), r.ReportedAt))
        .ToList();
}

/// <summary>Open reports grouped by target, high priority first, then oldest first (spec trust-safety › Admin report queue).</summary>
internal sealed class AdminReportQueueHandler(ISafetyRepository safety, IPlayerProfileRepository profiles, TimeProvider clock)
    : IQueryHandler<AdminReportQueueQuery, IReadOnlyList<ReportGroupView>>
{
    public async Task<IReadOnlyList<ReportGroupView>> Handle(AdminReportQueueQuery request, CancellationToken cancellationToken)
    {
        var open = await safety.ListOpenReportsAsync(cancellationToken);
        var names = await profiles.DisplayNamesAsync(open.SelectMany(r => new[] { r.ReporterId, r.TargetUserId }).Distinct().ToList(), cancellationToken);
        var now = clock.GetUtcNow().UtcDateTime;
        return open.GroupBy(r => r.TargetUserId)
            .Select(g =>
            {
                var reports = g.OrderBy(r => r.ReportedAt).ToList();
                return new ReportGroupView(g.Key, names.GetValueOrDefault(g.Key, PlayerProfile.DeletedDisplayName), ReportPriority.IsHigh(reports, now), reports.Count,
                    reports.Select(r => r.ReporterId).Distinct().Count(), reports[0].ReportedAt, reports.Select(r => SafetyMapping.ToView(r, names)).ToList());
            })
            .OrderByDescending(g => g.HighPriority)
            .ThenBy(g => g.OldestReportAt)
            .ToList();
    }
}

/// <summary>Everything an admin needs about a reported player: evidence, history, reliability, disputes and private rating notes.</summary>
internal sealed class AdminTargetDetailHandler(
    ISafetyRepository safety,
    IPlayerProfileRepository profiles,
    IRatingRepository ratings,
    IReputationReader reputation,
    TimeProvider clock) : IQueryHandler<AdminTargetDetailQuery, TargetDetailView>
{
    public static readonly TimeSpan DisputeWindow = TimeSpan.FromDays(90);

    public async Task<TargetDetailView> Handle(AdminTargetDetailQuery request, CancellationToken cancellationToken)
    {
        var profile = await profiles.GetAsync(request.UserId, cancellationToken) ?? throw VisibilityService.PlayerNotFound();
        var reports = await safety.ListReportsOnAsync(profile.Id, cancellationToken);
        var received = await ratings.ListReceivedAsync(profile.Id, cancellationToken);
        var notes = received.Where(r => r.PrivateNote is not null).ToList();
        var names = await profiles.DisplayNamesAsync(reports.Select(r => r.ReporterId).Concat(notes.Select(n => n.RaterId)).Distinct().ToList(), cancellationToken);
        var commitments = await reputation.CommitmentsAsync([profile.Id], cancellationToken);
        var disputes = await safety.DisputedMatchesOfAsync(profile.Id, clock.GetUtcNow().UtcDateTime - DisputeWindow, cancellationToken);
        return new TargetDetailView(
            profile.Id,
            profile.DisplayName,
            profile.Gender,
            profile.PhotoKey is not null,
            Domain.Ratings.ReliabilityPolicy.Tier(commitments.GetValueOrDefault(profile.Id) ?? []),
            reports.Select(r => SafetyMapping.ToView(r, names)).ToList(),
            (await safety.ListActionsOnAsync(profile.Id, cancellationToken)).Select(SafetyMapping.ToView).ToList(),
            new DisputeSummary(disputes.Count, disputes),
            notes.Select(n => new PrivateNoteView(n.Id, n.MatchId, n.RaterId, names.GetValueOrDefault(n.RaterId, PlayerProfile.DeletedDisplayName), n.Stars, n.PrivateNote!, n.SubmittedAt)).ToList());
    }
}

/// <summary>
/// Applies one admin action, each in its owning context (design D11): account actions go to Identity, message
/// deletion to Messaging, profile and post actions stay here. Records the action against the report and audits it.
/// </summary>
internal sealed class TakeModerationActionHandler(
    ISender sender,
    ICurrentUserService currentUser,
    IAccountModeration accounts,
    IMessageEvidenceReader messages,
    IMatchRepository matches,
    ISafetyRepository safety,
    IIntegrationEventPublisher events,
    ICommunityUnitOfWork unitOfWork,
    TimeProvider clock) : ICommandHandler<TakeModerationActionCommand, ModerationActionView>
{
    public async Task<ModerationActionView> Handle(TakeModerationActionCommand request, CancellationToken cancellationToken)
    {
        var adminId = currentUser.RequireUserId();
        if (string.IsNullOrWhiteSpace(request.Reason))
            throw new ValidationFailedException("REASON_REQUIRED", "دلیل را بنویسید.");
        var reason = request.Reason.Trim();
        var report = request.ReportId is { } reportId ? await safety.GetReportAsync(reportId, cancellationToken) : null;
        if (request.ReportId is not null && (report is null || report.TargetUserId != request.TargetUserId))
            throw new NotFoundException("گزارش پیدا نشد.", "REPORT_NOT_FOUND");
        var now = clock.GetUtcNow().UtcDateTime;

        var subject = await ApplyAsync(request, adminId, reason, now, cancellationToken);

        var action = ModerationAction.Record(adminId, request.TargetUserId, request.Action, reason, report?.Id, subject, now);
        safety.Add(action);
        if (report is { IsOpen: true })
            report.Resolve(adminId, reason, now);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return SafetyMapping.ToView(action);
    }

    /// <returns>What the action applied to, kept with the action record.</returns>
    private async Task<string?> ApplyAsync(TakeModerationActionCommand request, Guid adminId, string reason, DateTime now, CancellationToken cancellationToken)
    {
        var target = request.TargetUserId;
        switch (request.Action)
        {
            case ModerationActionType.Warn:
                if (string.IsNullOrWhiteSpace(request.WarningText))
                    throw new ValidationFailedException("WARNING_TEXT_REQUIRED", "متن اخطار را بنویسید.");
                events.Enqueue(new PlayerWarned(target, request.WarningText.Trim(), reason));
                Audit(adminId, "moderation.warn", "Player", target.ToString(), target, reason);
                return null;
            case ModerationActionType.RemovePhoto:
                await sender.Send(new AdminRemovePhotoCommand(target, reason), cancellationToken);
                return null;
            case ModerationActionType.CorrectGender:
                if (request.Gender is not { } gender)
                    throw new ValidationFailedException("GENDER_REQUIRED", "جنسیت درست را انتخاب کنید.");
                await sender.Send(new CorrectGenderCommand(target, gender, reason), cancellationToken);
                return gender.ToString();
            case ModerationActionType.HidePost:
            {
                var match = request.MatchId is { } matchId ? await matches.GetAsync(matchId, cancellationToken) : null;
                if (match is null || match.HostId != target)
                    throw MatchWorkflow.MatchNotFound();
                match.Hide(now);
                Audit(adminId, "moderation.hide-post", "Match", match.Id.ToString(), target, reason);
                return match.Id.ToString();
            }
            case ModerationActionType.DeleteMessage:
            {
                var messageId = request.MessageId ?? throw new ValidationFailedException("MESSAGE_REQUIRED", "پیام را مشخص کنید.");
                if (await messages.SenderOfAsync(messageId, cancellationToken) != target)
                    throw new NotFoundException("پیام پیدا نشد.", "MESSAGE_NOT_FOUND");
                events.Enqueue(new MessageRemovalRequested(messageId, adminId));
                Audit(adminId, "moderation.delete-message", "Message", messageId.ToString(), target, reason);
                return messageId.ToString();
            }
            case ModerationActionType.Suspend:
            {
                if (!PersianFormat.TryParseJalali(request.Until, out var lastDay))
                    throw new ValidationFailedException("INVALID_DATE", "تاریخ پایان تعلیق معتبر نیست.");
                // Suspended through the whole last day, Tehran time.
                var until = TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(lastDay.AddDays(1).ToDateTime(TimeOnly.MinValue), DateTimeKind.Unspecified), PersianFormat.Tehran);
                if (until <= now)
                    throw new ValidationFailedException("INVALID_DATE", "تاریخ پایان تعلیق باید بعد از امروز باشد.");
                await accounts.SuspendAsync(target, until, reason, cancellationToken);
                return PersianFormat.JalaliAscii(lastDay);
            }
            case ModerationActionType.LiftSuspension:
                await accounts.LiftSuspensionAsync(target, reason, cancellationToken);
                return null;
            case ModerationActionType.Ban:
                await accounts.BanAsync(target, reason, cancellationToken);
                return null;
            default:
                throw new ValidationFailedException("INVALID_ACTION", "اقدام انتخاب‌شده معتبر نیست.");
        }
    }

    private void Audit(Guid adminId, string action, string targetType, string targetId, Guid targetUserId, string reason) =>
        events.Enqueue(new AdminActionRecorded(adminId, action, targetType, targetId, targetUserId, reason));
}

internal sealed class DismissReportHandler(ISafetyRepository safety, ICurrentUserService currentUser, IIntegrationEventPublisher events, ICommunityUnitOfWork unitOfWork, TimeProvider clock)
    : ICommandHandler<DismissReportCommand>
{
    public async Task Handle(DismissReportCommand request, CancellationToken cancellationToken)
    {
        var report = await safety.GetReportAsync(request.ReportId, cancellationToken) ?? throw new NotFoundException("گزارش پیدا نشد.", "REPORT_NOT_FOUND");
        var adminId = currentUser.RequireUserId();
        report.Dismiss(adminId, request.Reason, clock.GetUtcNow().UtcDateTime);
        events.Enqueue(new AdminActionRecorded(adminId, "report.dismiss", "Report", report.Id.ToString(), report.TargetUserId, report.ResolutionNote));
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
    }
}

internal sealed class AdminAuditHandler(ISafetyRepository safety) : IQueryHandler<AdminAuditQuery, PagedResult<AuditEntryView>>
{
    public async Task<PagedResult<AuditEntryView>> Handle(AdminAuditQuery request, CancellationToken cancellationToken)
    {
        var page = Math.Max(1, request.Page);
        var size = Math.Clamp(request.PageSize, 1, 200);
        var filter = new AuditFilter(request.AdminId, request.TargetUserId, string.IsNullOrWhiteSpace(request.Action) ? null : request.Action.Trim(),
            DayStart(request.From, 0), DayStart(request.To, 1), page, size);
        var (items, total) = await safety.AuditAsync(filter, cancellationToken);
        return new PagedResult<AuditEntryView>(
            items.Select(e => new AuditEntryView(e.Id, e.AdminId, e.Action, e.TargetType, e.TargetId, e.TargetUserId, e.Reason, e.At)).ToList(), page, size, total);
    }

    /// <summary>The UTC start of a Tehran day (plus <paramref name="addDays"/>), so "to" includes its whole day.</summary>
    private static DateTime? DayStart(string? jalali, int addDays)
    {
        if (string.IsNullOrWhiteSpace(jalali))
            return null;
        if (!PersianFormat.TryParseJalali(jalali, out var day))
            throw new ValidationFailedException("INVALID_DATE", "تاریخ معتبر نیست.");
        return TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(day.AddDays(addDays).ToDateTime(TimeOnly.MinValue), DateTimeKind.Unspecified), PersianFormat.Tehran);
    }
}

/// <summary>Disputed matches and matches with contested no-shows, newest first (spec trust-safety › Disputed matches are visible to admins).</summary>
internal sealed class AdminDisputedMatchesHandler(ISafetyRepository safety, IPlayerProfileRepository profiles) : IQueryHandler<AdminDisputedMatchesQuery, IReadOnlyList<DisputedMatchView>>
{
    public async Task<IReadOnlyList<DisputedMatchView>> Handle(AdminDisputedMatchesQuery request, CancellationToken cancellationToken)
    {
        var list = await safety.ListDisputedMatchesAsync(100, cancellationToken);
        var names = await profiles.DisplayNamesAsync(list.SelectMany(m => m.PlayerIds()).Distinct().ToList(), cancellationToken);
        return list.Select(m => new DisputedMatchView(m.Id, m.Status, m.SportId, PersianFormat.JalaliAscii(DateOnly.FromDateTime(PersianFormat.ToTehran(m.StartsAt))), m.ResolvedAt,
                m.Participants.Where(p => p.Plays)
                    .Select(p => new DisputedPlayerView(p.PlayerId, names.GetValueOrDefault(p.PlayerId, PlayerProfile.DeletedDisplayName), p.Attendance, p.Outcome))
                    .ToList()))
            .ToList();
    }
}
