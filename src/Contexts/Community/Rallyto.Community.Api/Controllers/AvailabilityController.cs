using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Rallyto.Community.Application.Availability;

namespace Rallyto.Community.Api.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Authorize]
[Route("api/v{version:apiVersion}")]
public sealed class AvailabilityController(ISender sender) : ControllerBase
{
    [HttpGet("availability")]
    public async Task<ActionResult<IReadOnlyList<AvailabilityView>>> Mine(CancellationToken ct) => Ok(await sender.Send(new ListMyAvailabilityQuery(), ct));

    [HttpPost("availability")]
    public async Task<ActionResult<AvailabilityView>> Create(AvailabilityInput input, CancellationToken ct) =>
        StatusCode(StatusCodes.Status201Created, await sender.Send(new CreateAvailabilityCommand(input), ct));

    [HttpPut("availability/{id:guid}")]
    public async Task<ActionResult<AvailabilityView>> Update(Guid id, AvailabilityInput input, CancellationToken ct) =>
        Ok(await sender.Send(new UpdateAvailabilityCommand(id, input), ct));

    [HttpPost("availability/{id:guid}/pause")]
    public async Task<ActionResult<AvailabilityView>> Pause(Guid id, CancellationToken ct) =>
        Ok(await sender.Send(new ChangeAvailabilityCommand(id, AvailabilityAction.Pause), ct));

    [HttpPost("availability/{id:guid}/resume")]
    public async Task<ActionResult<AvailabilityView>> Resume(Guid id, CancellationToken ct) =>
        Ok(await sender.Send(new ChangeAvailabilityCommand(id, AvailabilityAction.Resume), ct));

    /// <summary>"Still available": resets the 30-day reconfirmation clock.</summary>
    [HttpPost("availability/{id:guid}/confirm")]
    public async Task<ActionResult<AvailabilityView>> Confirm(Guid id, CancellationToken ct) =>
        Ok(await sender.Send(new ChangeAvailabilityCommand(id, AvailabilityAction.Confirm), ct));

    [HttpDelete("availability/{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        await sender.Send(new DeleteAvailabilityCommand(id), ct);
        return NoContent();
    }

    [HttpGet("players/{userId:guid}/availability")]
    public async Task<ActionResult<IReadOnlyList<AvailabilityView>>> ForPlayer(Guid userId, CancellationToken ct) =>
        Ok(await sender.Send(new ListPlayerAvailabilityQuery(userId), ct));
}
