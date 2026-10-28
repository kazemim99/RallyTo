using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Rallyto.Infrastructure.Web.RateLimiting;
using Rallyto.Messaging.Application.Conversations;

namespace Rallyto.Messaging.Api.Controllers;

public sealed record OpenDirectRequest(Guid PlayerId);

public sealed record SendMessageRequest(string ClientMessageId, string? Body);

public sealed record MarkReadRequest(Guid UpToMessageId);

public sealed record MuteRequest(bool Muted);

[ApiController]
[ApiVersion("1.0")]
[Authorize]
[Route("api/v{version:apiVersion}/conversations")]
public sealed class ConversationsController(ISender sender) : ControllerBase
{
    /// <summary>The inbox, or the message requests with <c>box=requests</c>.</summary>
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ConversationSummary>>> List([FromQuery] string box = "inbox", CancellationToken ct = default) =>
        Ok(await sender.Send(new ListConversationsQuery(
            string.Equals(box, "requests", StringComparison.OrdinalIgnoreCase) ? ConversationBox.Requests : ConversationBox.Inbox), ct));

    [HttpGet("unread")]
    public async Task<ActionResult<UnreadCountsView>> Unread(CancellationToken ct) => Ok(await sender.Send(new GetUnreadCountsQuery(), ct));

    [HttpPost("direct")]
    public async Task<ActionResult<ConversationSummary>> OpenDirect(OpenDirectRequest request, CancellationToken ct) =>
        Ok(await sender.Send(new OpenDirectConversationCommand(request.PlayerId), ct));

    [HttpGet("match/{matchId:guid}")]
    public async Task<ActionResult<ConversationSummary>> ForMatch(Guid matchId, CancellationToken ct) => Ok(await sender.Send(new GetMatchConversationQuery(matchId), ct));

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<ConversationSummary>> Get(Guid id, CancellationToken ct) => Ok(await sender.Send(new GetConversationQuery(id), ct));

    [HttpGet("{id:guid}/messages")]
    public async Task<ActionResult<MessagePage>> History(Guid id, [FromQuery] string? before, CancellationToken ct) =>
        Ok(await sender.Send(new GetHistoryQuery(id, before), ct));

    [HttpPost("{id:guid}/messages")]
    [EnableRateLimiting(RateLimitPolicies.ChatSend)]
    public async Task<ActionResult<MessageView>> Send(Guid id, SendMessageRequest request, CancellationToken ct) =>
        Ok(await sender.Send(new SendMessageCommand(id, request.ClientMessageId, request.Body), ct));

    [HttpDelete("{id:guid}/messages/{messageId:guid}")]
    public async Task<IActionResult> Delete(Guid id, Guid messageId, CancellationToken ct)
    {
        await sender.Send(new DeleteMessageCommand(id, messageId), ct);
        return NoContent();
    }

    [HttpPost("{id:guid}/accept")]
    public async Task<ActionResult<ConversationSummary>> Accept(Guid id, CancellationToken ct) => Ok(await sender.Send(new AcceptRequestCommand(id), ct));

    [HttpPost("{id:guid}/ignore")]
    public async Task<ActionResult<ConversationSummary>> Ignore(Guid id, CancellationToken ct) => Ok(await sender.Send(new IgnoreRequestCommand(id), ct));

    [HttpPost("{id:guid}/read")]
    public async Task<IActionResult> Read(Guid id, MarkReadRequest request, CancellationToken ct)
    {
        await sender.Send(new MarkReadCommand(id, request.UpToMessageId), ct);
        return NoContent();
    }

    [HttpPost("{id:guid}/mute")]
    public async Task<ActionResult<ConversationSummary>> Mute(Guid id, MuteRequest request, CancellationToken ct) =>
        Ok(await sender.Send(new MuteConversationCommand(id, request.Muted), ct));
}
