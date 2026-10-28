using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Rallyto.Community.Application.Players;
using Rallyto.Community.Application.Ratings;
using Rallyto.Community.Domain.Players;
using Rallyto.Infrastructure.Web.Security;

namespace Rallyto.Community.Api.Controllers;

public sealed record CreateProfileRequest(string DisplayName, Gender Gender, string BirthDate, int CityId, string? Bio, IReadOnlyList<SportProfileInput> Sports);

public sealed record UpdateProfileRequest(string DisplayName, Gender? Gender, int CityId, string? Bio);

public sealed record HomeVenuesRequest(IReadOnlyList<Guid> VenueIds);

public sealed record VisibilityRequest(ProfileVisibility Visibility);

public sealed record GenderCorrectionRequest(Gender Gender, string Reason);

public sealed record AdminReasonRequest(string Reason);

[ApiController]
[ApiVersion("1.0")]
[Authorize]
[Route("api/v{version:apiVersion}/profile")]
public sealed class ProfileController(ISender sender) : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult<MyProfileView>> Create(CreateProfileRequest r, CancellationToken ct) =>
        StatusCode(StatusCodes.Status201Created, await sender.Send(new CreateProfileCommand(r.DisplayName, r.Gender, r.BirthDate, r.CityId, r.Bio, r.Sports ?? []), ct));

    /// <summary>The player's own reputation: aggregates only, never individual ratings (spec player-ratings).</summary>
    [HttpGet("reputation")]
    public async Task<ActionResult<ReputationView>> Reputation(CancellationToken ct) => Ok(await sender.Send(new GetMyReputationQuery(), ct));

    [HttpGet("me")]
    public async Task<ActionResult<MyProfileView>> Me(CancellationToken ct) => Ok(await sender.Send(new GetMyProfileQuery(), ct));

    [HttpPut]
    public async Task<ActionResult<MyProfileView>> Update(UpdateProfileRequest r, CancellationToken ct) =>
        Ok(await sender.Send(new UpdateProfileCommand(r.DisplayName, r.Gender, r.CityId, r.Bio), ct));

    [HttpPut("sports/{sportId:guid}")]
    public async Task<ActionResult<MyProfileView>> SetSport(Guid sportId, SportProfileInput r, CancellationToken ct) =>
        Ok(await sender.Send(new SetSportProfileCommand(r with { SportId = sportId }), ct));

    [HttpDelete("sports/{sportId:guid}")]
    public async Task<ActionResult<MyProfileView>> RemoveSport(Guid sportId, CancellationToken ct) =>
        Ok(await sender.Send(new RemoveSportProfileCommand(sportId), ct));

    [HttpPut("home-venues")]
    public async Task<ActionResult<MyProfileView>> HomeVenues(HomeVenuesRequest r, CancellationToken ct) =>
        Ok(await sender.Send(new SetHomeVenuesCommand(r.VenueIds ?? []), ct));

    [HttpPut("visibility")]
    public async Task<ActionResult<MyProfileView>> Visibility(VisibilityRequest r, CancellationToken ct) =>
        Ok(await sender.Send(new SetVisibilityCommand(r.Visibility), ct));

    [HttpPut("photo")]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<ActionResult<MyProfileView>> Photo(IFormFile file, CancellationToken ct)
    {
        await using var stream = file.OpenReadStream();
        return Ok(await sender.Send(new UploadPhotoCommand(stream, file.Length, file.ContentType), ct));
    }

    [HttpDelete("photo")]
    public async Task<ActionResult<MyProfileView>> RemovePhoto(CancellationToken ct) => Ok(await sender.Send(new RemovePhotoCommand(), ct));
}

[ApiController]
[ApiVersion("1.0")]
[Authorize]
[Route("api/v{version:apiVersion}")]
public sealed class PlayersController(ISender sender) : ControllerBase
{
    [HttpGet("players/{userId:guid}")]
    public async Task<ActionResult<PlayerProfileView>> Get(Guid userId, CancellationToken ct) => Ok(await sender.Send(new GetPlayerProfileQuery(userId), ct));

    [HttpGet("blocks")]
    public async Task<ActionResult<IReadOnlyList<BlockedPlayerView>>> Blocks(CancellationToken ct) => Ok(await sender.Send(new ListBlocksQuery(), ct));

    [HttpPost("blocks/{userId:guid}")]
    public async Task<IActionResult> Block(Guid userId, CancellationToken ct)
    {
        await sender.Send(new BlockPlayerCommand(userId), ct);
        return NoContent();
    }

    [HttpDelete("blocks/{userId:guid}")]
    public async Task<IActionResult> Unblock(Guid userId, CancellationToken ct)
    {
        await sender.Send(new UnblockPlayerCommand(userId), ct);
        return NoContent();
    }
}

[ApiController]
[ApiVersion("1.0")]
[Authorize(Policy = Policies.AdminOnly)]
[Route("api/v{version:apiVersion}/admin/players")]
public sealed class AdminPlayersController(ISender sender) : ControllerBase
{
    [HttpGet("{userId:guid}")]
    public async Task<ActionResult<MyProfileView>> Get(Guid userId, CancellationToken ct) => Ok(await sender.Send(new AdminGetPlayerQuery(userId), ct));

    [HttpPost("{userId:guid}/gender")]
    public async Task<IActionResult> CorrectGender(Guid userId, GenderCorrectionRequest r, CancellationToken ct)
    {
        await sender.Send(new CorrectGenderCommand(userId, r.Gender, r.Reason), ct);
        return NoContent();
    }

    [HttpDelete("{userId:guid}/photo")]
    public async Task<IActionResult> RemovePhoto(Guid userId, [FromBody] AdminReasonRequest r, CancellationToken ct)
    {
        await sender.Send(new AdminRemovePhotoCommand(userId, r.Reason), ct);
        return NoContent();
    }
}

public sealed record RemoveRatingRequest(string Reason);

[ApiController]
[ApiVersion("1.0")]
[Authorize(Policy = Policies.AdminOnly)]
[Route("api/v{version:apiVersion}/admin")]
public sealed class AdminRatingsController(ISender sender) : ControllerBase
{
    [HttpGet("players/{userId:guid}/ratings")]
    public async Task<ActionResult<IReadOnlyList<AdminRatingView>>> List(Guid userId, CancellationToken ct) => Ok(await sender.Send(new AdminListRatingsQuery(userId), ct));

    [HttpDelete("ratings/{id:guid}")]
    public async Task<IActionResult> Remove(Guid id, RemoveRatingRequest request, CancellationToken ct)
    {
        await sender.Send(new AdminRemoveRatingCommand(id, request.Reason), ct);
        return NoContent();
    }
}
