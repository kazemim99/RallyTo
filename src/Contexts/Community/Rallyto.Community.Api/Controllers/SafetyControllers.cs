using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Rallyto.Community.Application.Safety;
using Rallyto.Community.Domain.Players;
using Rallyto.Community.Domain.Safety;
using Rallyto.Core.Application.Results;
using Rallyto.Infrastructure.Web.RateLimiting;
using Rallyto.Infrastructure.Web.Security;

namespace Rallyto.Community.Api.Controllers;

public sealed record ReportRequest(ReportTargetType TargetType, string TargetId, ReportReason Reason, string? Details, bool Block);

public sealed record ModerationActionRequest(
    Guid TargetUserId,
    ModerationActionType Action,
    string Reason,
    Guid? ReportId,
    string? Until,
    Guid? MessageId,
    Guid? MatchId,
    Gender? Gender,
    string? WarningText);

public sealed record DismissRequest(string Reason);

[ApiController]
[ApiVersion("1.0")]
[Authorize]
[Route("api/v{version:apiVersion}/reports")]
public sealed class ReportsController(ISender sender) : ControllerBase
{
    [HttpPost]
    [EnableRateLimiting(RateLimitPolicies.Reports)]
    public async Task<ActionResult<ReportReceiptView>> File(ReportRequest request, CancellationToken ct) =>
        StatusCode(StatusCodes.Status201Created, await sender.Send(new FileReportCommand(request.TargetType, request.TargetId, request.Reason, request.Details, request.Block), ct));

    [HttpGet("mine")]
    public async Task<ActionResult<IReadOnlyList<MyReportView>>> Mine(CancellationToken ct) => Ok(await sender.Send(new ListMyReportsQuery(), ct));
}

[ApiController]
[ApiVersion("1.0")]
[Authorize(Policy = Policies.AdminOnly)]
[Route("api/v{version:apiVersion}/admin")]
public sealed class AdminSafetyController(ISender sender) : ControllerBase
{
    [HttpGet("reports")]
    public async Task<ActionResult<IReadOnlyList<ReportGroupView>>> Queue(CancellationToken ct) => Ok(await sender.Send(new AdminReportQueueQuery(), ct));

    [HttpGet("reports/targets/{userId:guid}")]
    public async Task<ActionResult<TargetDetailView>> Target(Guid userId, CancellationToken ct) => Ok(await sender.Send(new AdminTargetDetailQuery(userId), ct));

    [HttpPost("reports/{id:guid}/dismiss")]
    public async Task<IActionResult> Dismiss(Guid id, DismissRequest request, CancellationToken ct)
    {
        await sender.Send(new DismissReportCommand(id, request.Reason), ct);
        return NoContent();
    }

    [HttpPost("moderation/actions")]
    public async Task<ActionResult<ModerationActionView>> Act(ModerationActionRequest r, CancellationToken ct) =>
        Ok(await sender.Send(new TakeModerationActionCommand(r.TargetUserId, r.Action, r.Reason, r.ReportId, r.Until, r.MessageId, r.MatchId, r.Gender, r.WarningText), ct));

    /// <summary>Dates are Jalali (<c>yyyy/MM/dd</c>, Tehran days, both ends inclusive).</summary>
    [HttpGet("audit")]
    public async Task<ActionResult<PagedResult<AuditEntryView>>> Audit([FromQuery] Guid? adminId, [FromQuery] Guid? targetUserId, [FromQuery] string? action,
        [FromQuery] string? from, [FromQuery] string? to, [FromQuery] int page = 1, [FromQuery] int pageSize = 50, CancellationToken ct = default) =>
        Ok(await sender.Send(new AdminAuditQuery(adminId, targetUserId, action, from, to, page, pageSize), ct));

    /// <summary>Usage dashboard; Jalali <c>from</c>/<c>to</c>, the last 30 days by default.</summary>
    [HttpGet("stats")]
    public async Task<ActionResult<UsageStatsView>> Stats([FromQuery] string? from, [FromQuery] string? to, CancellationToken ct) =>
        Ok(await sender.Send(new AdminUsageStatsQuery(from, to), ct));

    [HttpGet("matches/disputed")]
    public async Task<ActionResult<IReadOnlyList<DisputedMatchView>>> Disputed(CancellationToken ct) => Ok(await sender.Send(new AdminDisputedMatchesQuery(), ct));
}
