using System.Net;
using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Rallyto.Community.Application.Matches;
using Rallyto.Community.Application.Ratings;
using Rallyto.Community.Domain.Matches;
using Rallyto.Community.Domain.Ratings;
using Rallyto.Core.Application.Exceptions;

namespace Rallyto.Community.Api.Controllers;

public sealed record JoinRequest(string? Message);

public sealed record InviteRequest(IReadOnlyList<Guid> PlayerIds);

public sealed record CancelRequest(string? Reason);

public sealed record AttendanceRequest(AttendanceAnswer Answer, IReadOnlyList<Guid>? NoShowPlayerIds);

public sealed record RatingRequest(Guid RateeId, int Stars, IReadOnlyList<RatingTags>? Tags, LevelAccuracy? LevelAccuracy, string? PrivateNote);

[ApiController]
[ApiVersion("1.0")]
[Authorize]
[Route("api/v{version:apiVersion}/matches")]
public sealed class MatchesController(ISender sender) : ControllerBase
{
    [HttpPost("posts")]
    public async Task<ActionResult<MatchView>> CreatePost(MatchInput input, CancellationToken ct) =>
        StatusCode(StatusCodes.Status201Created, await sender.Send(new CreatePostCommand(input), ct));

    [HttpPost("invitations")]
    public async Task<ActionResult<MatchView>> CreateInvitation(InvitationInput input, CancellationToken ct) =>
        StatusCode(StatusCodes.Status201Created, await sender.Send(new CreateInvitationCommand(input), ct));

    [HttpGet("mine")]
    public async Task<ActionResult<IReadOnlyList<MatchView>>> Mine([FromQuery] string scope = "upcoming", CancellationToken ct = default) =>
        Ok(await sender.Send(new ListMyMatchesQuery(!string.Equals(scope, "past", StringComparison.OrdinalIgnoreCase)), ct));

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<MatchView>> Get(Guid id, CancellationToken ct) => Ok(await sender.Send(new GetMatchQuery(id), ct));

    [HttpGet("by-token/{token}")]
    public async Task<ActionResult<MatchView>> ByToken(string token, CancellationToken ct) => Ok(await sender.Send(new GetMatchByTokenQuery(token), ct));

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<MatchView>> Edit(Guid id, MatchInput input, CancellationToken ct) => Ok(await sender.Send(new EditMatchCommand(id, input), ct));

    [HttpPost("{id:guid}/cancel")]
    public async Task<ActionResult<MatchView>> Cancel(Guid id, CancelRequest request, CancellationToken ct) =>
        Ok(await sender.Send(new CancelMatchCommand(id, request.Reason), ct));

    [HttpPost("{id:guid}/join")]
    public async Task<ActionResult<MatchView>> Join(Guid id, JoinRequest request, CancellationToken ct) =>
        Ok(await sender.Send(new JoinMatchCommand(id, request.Message), ct));

    [HttpPost("{id:guid}/withdraw")]
    public Task<ActionResult<MatchView>> Withdraw(Guid id, CancellationToken ct) => Act(id, MatchAction.Withdraw, ct);

    [HttpPost("{id:guid}/requests/{playerId:guid}/accept")]
    public async Task<ActionResult<MatchView>> AcceptRequest(Guid id, Guid playerId, CancellationToken ct) =>
        Ok(await sender.Send(new AnswerJoinRequestCommand(id, playerId, true), ct));

    [HttpPost("{id:guid}/requests/{playerId:guid}/decline")]
    public async Task<ActionResult<MatchView>> DeclineRequest(Guid id, Guid playerId, CancellationToken ct) =>
        Ok(await sender.Send(new AnswerJoinRequestCommand(id, playerId, false), ct));

    [HttpPost("{id:guid}/invite")]
    public async Task<ActionResult<MatchView>> Invite(Guid id, InviteRequest request, CancellationToken ct) =>
        Ok(await sender.Send(new InvitePlayersCommand(id, request.PlayerIds ?? []), ct));

    [HttpPost("{id:guid}/invitation/accept")]
    public Task<ActionResult<MatchView>> AcceptInvitation(Guid id, CancellationToken ct) => Act(id, MatchAction.AcceptInvitation, ct);

    [HttpPost("{id:guid}/invitation/decline")]
    public Task<ActionResult<MatchView>> DeclineInvitation(Guid id, CancellationToken ct) => Act(id, MatchAction.DeclineInvitation, ct);

    [HttpPost("{id:guid}/attendance")]
    public async Task<ActionResult<MatchView>> Attendance(Guid id, AttendanceRequest request, CancellationToken ct) =>
        Ok(await sender.Send(new AnswerAttendanceCommand(id, request.Answer, request.NoShowPlayerIds), ct));

    [HttpPost("{id:guid}/ratings")]
    public async Task<ActionResult<RatingReceiptView>> Rate(Guid id, RatingRequest request, CancellationToken ct) =>
        StatusCode(StatusCodes.Status201Created,
            await sender.Send(new SubmitRatingCommand(id, request.RateeId, request.Stars, request.Tags, request.LevelAccuracy, request.PrivateNote), ct));

    [HttpPost("{id:guid}/confirm")]
    public Task<ActionResult<MatchView>> Confirm(Guid id, CancellationToken ct) => Act(id, MatchAction.ConfirmEarly, ct);

    [HttpPost("{id:guid}/leave")]
    public Task<ActionResult<MatchView>> Leave(Guid id, CancellationToken ct) => Act(id, MatchAction.Leave, ct);

    [HttpPost("{id:guid}/participants/{playerId:guid}/remove")]
    public async Task<ActionResult<MatchView>> Remove(Guid id, Guid playerId, CancellationToken ct) =>
        Ok(await sender.Send(new RemoveParticipantCommand(id, playerId), ct));

    [HttpPost("{id:guid}/share-token")]
    public Task<ActionResult<MatchView>> RegenerateShareToken(Guid id, CancellationToken ct) => Act(id, MatchAction.RegenerateShareToken, ct);

    private async Task<ActionResult<MatchView>> Act(Guid id, MatchAction action, CancellationToken ct) =>
        Ok(await sender.Send(new MatchActionCommand(id, action), ct));
}

/// <summary>Share links (spec play-posts › Share link): an anonymous JSON summary and a minimal web page for people without the app.</summary>
[ApiController]
[AllowAnonymous]
public sealed class ShareController(ISender sender) : ControllerBase
{
    [ApiVersion("1.0")]
    [HttpGet("api/v{version:apiVersion}/share/{token}")]
    public async Task<ActionResult<ShareSummaryView>> Summary(string token, CancellationToken ct) => Ok(await sender.Send(new GetShareSummaryQuery(token), ct));

    [ApiVersionNeutral]
    [HttpGet("m/{token}")]
    public async Task<ContentResult> Page(string token, CancellationToken ct)
    {
        ShareSummaryView? summary = null;
        try
        {
            summary = await sender.Send(new GetShareSummaryQuery(token), ct);
        }
        catch (NotFoundException)
        {
            // rendered as "no longer valid" below
        }

        static string E(string? text) => WebUtility.HtmlEncode(text ?? string.Empty);
        var body = summary is null
            ? "<p>این پیوند دیگر معتبر نیست.</p>"
            : $"""
              <h1>{E(summary.Sport)} در {E(summary.Venue)}</h1>
              <p>{E(summary.City)} — {E(summary.Date)} ساعت {E(summary.StartTime)}</p>
              <p>میزبان: {E(summary.HostName)} {(summary.HostLevel is null ? "" : $"({E(summary.HostLevel)})")}</p>
              <p>جای خالی: {summary.OpenSpots}{(summary.CourtBooked ? " — زمین رزرو شده است" : "")}</p>
              """;
        var html = $"""
            <!doctype html>
            <html lang="fa" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
            <title>رالیتو</title>
            <style>body{"{"}font-family:Vazirmatn,Tahoma,sans-serif;max-width:560px;margin:2rem auto;padding:0 1rem;line-height:1.8{"}"}a.btn{"{"}display:inline-block;margin:.25rem 0;padding:.6rem 1rem;border-radius:.5rem;background:#1b7a46;color:#fff;text-decoration:none{"}"}</style>
            </head><body>
            {body}
            <p>برای پیوستن به این بازی، اپلیکیشن رالیتو را نصب کنید:</p>
            <p><a class="btn" href="https://cafebazaar.ir/app/ir.rallyto.app">کافه‌بازار</a> <a class="btn" href="https://myket.ir/app/ir.rallyto.app">مایکت</a></p>
            </body></html>
            """;
        return Content(html, "text/html; charset=utf-8");
    }
}
