using System.Text.Json;
using DotNetCore.CAP;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Rallyto.Community.Application.Safety;
using Rallyto.Community.Domain.Matches;
using Rallyto.Community.Domain.Safety;
using Rallyto.Contracts.Admin;

namespace Rallyto.Community.Infrastructure.Persistence;

internal sealed class ReportConfiguration : IEntityTypeConfiguration<Report>
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public void Configure(EntityTypeBuilder<Report> builder)
    {
        builder.ToTable("reports");
        builder.HasKey(r => r.Id);
        builder.Property(r => r.Id).ValueGeneratedNever();
        builder.Property(r => r.TargetType).HasConversion<string>().HasMaxLength(16);
        builder.Property(r => r.TargetId).HasMaxLength(64);
        builder.Property(r => r.Reason).HasConversion<string>().HasMaxLength(32);
        builder.Property(r => r.Status).HasConversion<string>().HasMaxLength(16);
        builder.Property(r => r.Details).HasMaxLength(Report.MaxDetailsLength);
        builder.Property(r => r.ResolutionNote).HasMaxLength(500);
        // The snapshot is read whole and never queried into.
        builder.Property(r => r.Evidence)
            .HasConversion(e => JsonSerializer.Serialize(e, Json), j => JsonSerializer.Deserialize<ReportEvidence>(j, Json)!)
            .HasColumnType("jsonb");
        // One open report per reporter and target (spec trust-safety › Duplicate open report).
        builder.HasIndex(r => new { r.ReporterId, r.TargetType, r.TargetId }).IsUnique().HasFilter("status = 'Open'");
        builder.HasIndex(r => new { r.Status, r.TargetUserId });
        builder.HasIndex(r => r.TargetUserId);
        builder.Ignore(r => r.IsOpen);
    }
}

internal sealed class ModerationActionConfiguration : IEntityTypeConfiguration<ModerationAction>
{
    public void Configure(EntityTypeBuilder<ModerationAction> builder)
    {
        builder.ToTable("moderation_actions");
        builder.HasKey(a => a.Id);
        builder.Property(a => a.Id).ValueGeneratedNever();
        builder.Property(a => a.Action).HasConversion<string>().HasMaxLength(32);
        builder.Property(a => a.Reason).HasMaxLength(500);
        builder.Property(a => a.Subject).HasMaxLength(64);
        builder.HasIndex(a => a.TargetUserId);
    }
}

internal sealed class AdminAuditEntryConfiguration : IEntityTypeConfiguration<AdminAuditEntry>
{
    public void Configure(EntityTypeBuilder<AdminAuditEntry> builder)
    {
        builder.ToTable("admin_audit_entries");
        builder.HasKey(e => e.Id);
        builder.Property(e => e.Id).ValueGeneratedNever();
        builder.Property(e => e.Action).HasMaxLength(64);
        builder.Property(e => e.TargetType).HasMaxLength(32);
        builder.Property(e => e.TargetId).HasMaxLength(64);
        builder.Property(e => e.Reason).HasMaxLength(500);
        builder.HasIndex(e => new { e.AdminId, e.At });
        builder.HasIndex(e => new { e.TargetUserId, e.At });
        builder.HasIndex(e => e.At);
    }
}

internal sealed class SafetyRepository(CommunityDbContext db) : ISafetyRepository
{
    public async Task<Report?> GetReportAsync(Guid id, CancellationToken cancellationToken) => await db.Reports.FindAsync([id], cancellationToken);

    public Task<bool> HasOpenReportAsync(Guid reporterId, ReportTargetType targetType, string targetId, CancellationToken cancellationToken) =>
        db.Reports.AnyAsync(r => r.ReporterId == reporterId && r.TargetType == targetType && r.TargetId == targetId && r.Status == ReportStatus.Open, cancellationToken);

    public async Task<IReadOnlyList<Report>> ListOpenReportsAsync(CancellationToken cancellationToken) =>
        await db.Reports.AsNoTracking().Where(r => r.Status == ReportStatus.Open).ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<Report>> ListReportsByReporterAsync(Guid reporterId, CancellationToken cancellationToken) =>
        await db.Reports.AsNoTracking().Where(r => r.ReporterId == reporterId).OrderByDescending(r => r.ReportedAt).ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<Report>> ListReportsOnAsync(Guid targetUserId, CancellationToken cancellationToken) =>
        await db.Reports.AsNoTracking().Where(r => r.TargetUserId == targetUserId).OrderByDescending(r => r.ReportedAt).ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<ModerationAction>> ListActionsOnAsync(Guid targetUserId, CancellationToken cancellationToken) =>
        await db.ModerationActions.AsNoTracking().Where(a => a.TargetUserId == targetUserId).OrderByDescending(a => a.At).ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<Guid>> DisputedMatchesOfAsync(Guid playerId, DateTime since, CancellationToken cancellationToken) =>
        await db.Matches.AsNoTracking()
            .Where(m => m.Status == MatchStatus.Disputed && m.ResolvedAt >= since
                        && m.Participants.Any(p => p.PlayerId == playerId && (p.State == ParticipantState.Host || p.State == ParticipantState.Accepted)))
            .OrderByDescending(m => m.ResolvedAt)
            .Select(m => m.Id)
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<Match>> ListDisputedMatchesAsync(int take, CancellationToken cancellationToken) =>
        await db.Matches.AsNoTracking()
            .Where(m => m.Status == MatchStatus.Disputed
                        || (m.Status == MatchStatus.Completed && m.Participants.Any(p => p.Outcome == AttendanceOutcome.Contested)))
            .OrderByDescending(m => m.ResolvedAt)
            .Take(take)
            .ToListAsync(cancellationToken);

    public async Task<(IReadOnlyList<AdminAuditEntry> Items, int Total)> AuditAsync(AuditFilter filter, CancellationToken cancellationToken)
    {
        var query = db.AdminAuditEntries.AsNoTracking().AsQueryable();
        if (filter.AdminId is { } adminId)
            query = query.Where(e => e.AdminId == adminId);
        if (filter.TargetUserId is { } targetUserId)
            query = query.Where(e => e.TargetUserId == targetUserId);
        if (filter.Action is { } action)
            query = query.Where(e => e.Action == action);
        if (filter.FromUtc is { } from)
            query = query.Where(e => e.At >= from);
        if (filter.ToUtc is { } to)
            query = query.Where(e => e.At < to);
        var total = await query.CountAsync(cancellationToken);
        var items = await query.OrderByDescending(e => e.At).Skip((filter.Page - 1) * filter.PageSize).Take(filter.PageSize).ToListAsync(cancellationToken);
        return (items, total);
    }

    public Task<bool> AuditEntryExistsAsync(Guid id, CancellationToken cancellationToken) => db.AdminAuditEntries.AnyAsync(e => e.Id == id, cancellationToken);

    public void Add(Report report) => db.Reports.Add(report);

    public void Add(ModerationAction action) => db.ModerationActions.Add(action);

    public void Add(AdminAuditEntry entry) => db.AdminAuditEntries.Add(entry);
}

/// <summary>Builds the admin audit log from every context's admin events; idempotent on the event id (spec trust-safety › Admin audit log).</summary>
public sealed class AdminAuditSubscriber(ISafetyRepository safety, Application.Abstractions.ICommunityUnitOfWork unitOfWork, TimeProvider clock) : ICapSubscribe
{
    [CapSubscribe(AdminTopics.ActionRecorded, Group = CommunityModule.CapGroup)]
    public async Task OnActionRecorded(AdminActionRecorded message)
    {
        if (await safety.AuditEntryExistsAsync(message.EventId, CancellationToken.None))
            return;
        safety.Add(AdminAuditEntry.Of(message.EventId, message.AdminId, message.Action, message.TargetType, message.TargetId, message.TargetUserId, message.Reason,
            clock.GetUtcNow().UtcDateTime));
        await unitOfWork.SaveAndPublishEventsAsync();
    }
}
