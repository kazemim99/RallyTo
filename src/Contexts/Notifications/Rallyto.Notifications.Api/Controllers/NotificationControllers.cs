using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Rallyto.Core.Application.Results;
using Rallyto.Notifications.Application.Delivery;
using Rallyto.Notifications.Application.Inbox;

namespace Rallyto.Notifications.Api.Controllers;

public sealed record DeviceTokenRequest(string Token, string? Platform);

public sealed record DeviceTokenRemoval(string Token);

[ApiController]
[ApiVersion("1.0")]
[Authorize]
[Route("api/v{version:apiVersion}/notifications")]
public sealed class NotificationsController(ISender sender) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResult<NotificationView>>> Inbox([FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        Ok(await sender.Send(new ListInboxQuery(page, pageSize), ct));

    [HttpGet("unread-count")]
    public async Task<ActionResult<UnreadCountView>> Unread(CancellationToken ct) => Ok(await sender.Send(new GetUnreadCountQuery(), ct));

    [HttpPost("{id:guid}/read")]
    public async Task<IActionResult> Read(Guid id, CancellationToken ct)
    {
        await sender.Send(new MarkNotificationReadCommand(id), ct);
        return NoContent();
    }

    [HttpPost("read-all")]
    public async Task<IActionResult> ReadAll(CancellationToken ct)
    {
        await sender.Send(new MarkAllReadCommand(), ct);
        return NoContent();
    }

    [HttpGet("preferences")]
    public async Task<ActionResult<PreferencesView>> Preferences(CancellationToken ct) => Ok(await sender.Send(new GetPreferencesQuery(), ct));

    [HttpPut("preferences")]
    public async Task<ActionResult<PreferencesView>> UpdatePreferences(UpdatePreferencesCommand command, CancellationToken ct) => Ok(await sender.Send(command, ct));
}

[ApiController]
[ApiVersion("1.0")]
[Authorize]
[Route("api/v{version:apiVersion}/device-tokens")]
public sealed class DeviceTokensController(ISender sender) : ControllerBase
{
    /// <summary>After sign-in and whenever FCM rotates the token.</summary>
    [HttpPost]
    public async Task<IActionResult> Register(DeviceTokenRequest request, CancellationToken ct)
    {
        await sender.Send(new RegisterDeviceTokenCommand(request.Token, request.Platform), ct);
        return NoContent();
    }

    /// <summary>Before sign-out.</summary>
    [HttpDelete]
    public async Task<IActionResult> Unregister(DeviceTokenRemoval request, CancellationToken ct)
    {
        await sender.Send(new UnregisterDeviceTokenCommand(request.Token), ct);
        return NoContent();
    }
}
