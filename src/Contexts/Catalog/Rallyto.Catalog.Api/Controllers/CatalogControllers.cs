using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Rallyto.Catalog.Application;
using Rallyto.Catalog.Application.Locations;
using Rallyto.Catalog.Application.Sports;
using Rallyto.Catalog.Application.Venues;
using Rallyto.Catalog.Domain.Sports;
using Rallyto.Catalog.Domain.Venues;
using Rallyto.Core.Application.Results;
using Rallyto.Infrastructure.Web.Security;

namespace Rallyto.Catalog.Api.Controllers;

public sealed record SportRequest(
    string Code,
    string NameFa,
    string NameEn,
    int SortOrder,
    int DefaultSessionMinutes,
    IReadOnlyList<SportFormatInput> Formats,
    IReadOnlyList<LevelInput> Levels,
    IReadOnlyList<CourtSurface>? Surfaces);

public sealed record VenueRequest(
    int CityId,
    string Name,
    string? Address,
    string? Phone,
    double? Latitude,
    double? Longitude,
    IReadOnlyList<VenueSportInput> Sports,
    bool AllowSimilar);

public sealed record VenueImportRequest(IReadOnlyList<VenueImportItem> Items, bool AllowSimilar);

public sealed record ImportRequest(IReadOnlyList<CandidateInput> Items);

public sealed record ApprovalRequest(string Name, string? Address, string? Phone, double? Latitude, double? Longitude, IReadOnlyList<VenueSportInput> Sports);

public sealed record MergeRequest(Guid VenueId);

public sealed record RejectRequest(string Reason);

public sealed record BulkApproveRequest(IReadOnlyList<Guid> CandidateIds, IReadOnlyList<VenueSportInput> Sports);

/// <summary>Sports are readable without signing in: onboarding and shared post pages need them (spec sport-catalog).</summary>
[ApiController]
[ApiVersion("1.0")]
[AllowAnonymous]
[Route("api/v{version:apiVersion}/sports")]
public sealed class SportsController(ISender sender) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<SportDto>>> List(CancellationToken ct) => Ok(await sender.Send(new GetSportsQuery(), ct));
}

[ApiController]
[ApiVersion("1.0")]
[Authorize]
[Route("api/v{version:apiVersion}")]
public sealed class LocationsController(ISender sender) : ControllerBase
{
    [HttpGet("provinces")]
    public async Task<ActionResult<IReadOnlyList<ProvinceDto>>> Provinces(CancellationToken ct) => Ok(await sender.Send(new GetProvincesQuery(), ct));

    [HttpGet("provinces/{provinceId:int}/cities")]
    public async Task<ActionResult<IReadOnlyList<CityDto>>> Cities(int provinceId, CancellationToken ct) =>
        Ok(await sender.Send(new GetCitiesQuery(provinceId), ct));
}

[ApiController]
[ApiVersion("1.0")]
[Authorize]
[Route("api/v{version:apiVersion}/venues")]
public sealed class VenuesController(ISender sender) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<VenueDto>>> List([FromQuery] int cityId, [FromQuery] string? sport, [FromQuery] string? q, CancellationToken ct) =>
        Ok(await sender.Send(new ListVenuesQuery(cityId, sport, q), ct));

    [HttpGet("{venueId:guid}")]
    public async Task<ActionResult<VenueDto>> Get(Guid venueId, CancellationToken ct) => Ok(await sender.Send(new GetVenueQuery(venueId, IncludeHidden: false), ct));
}

[ApiController]
[ApiVersion("1.0")]
[Authorize(Policy = Policies.AdminOnly)]
[Route("api/v{version:apiVersion}/admin/sports")]
public sealed class AdminSportsController(ISender sender) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<SportDto>>> List(CancellationToken ct) => Ok(await sender.Send(new GetSportsQuery(IncludeInactive: true), ct));

    [HttpPost]
    public async Task<ActionResult<SportDto>> Create(SportRequest request, CancellationToken ct)
    {
        var sport = await sender.Send(new CreateSportCommand(request.Code, request.NameFa, request.NameEn, request.DefaultSessionMinutes, request.Formats, request.Levels, request.Surfaces), ct);
        return StatusCode(StatusCodes.Status201Created, sport);
    }

    [HttpPut("{sportId:guid}")]
    public async Task<ActionResult<SportDto>> Update(Guid sportId, SportRequest request, CancellationToken ct) =>
        Ok(await sender.Send(new UpdateSportCommand(sportId, request.NameFa, request.NameEn, request.SortOrder, request.DefaultSessionMinutes, request.Formats, request.Levels, request.Surfaces), ct));

    [HttpPost("{sportId:guid}/activate")]
    public Task<IActionResult> Activate(Guid sportId, CancellationToken ct) => NoContent(new SetSportActiveCommand(sportId, true), ct);

    [HttpPost("{sportId:guid}/deactivate")]
    public Task<IActionResult> Deactivate(Guid sportId, CancellationToken ct) => NoContent(new SetSportActiveCommand(sportId, false), ct);

    private async Task<IActionResult> NoContent(IRequest command, CancellationToken ct)
    {
        await sender.Send(command, ct);
        return NoContent();
    }
}

[ApiController]
[ApiVersion("1.0")]
[Authorize(Policy = Policies.AdminOnly)]
[Route("api/v{version:apiVersion}/admin/venues")]
public sealed class AdminVenuesController(ISender sender) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResult<VenueDto>>> List(
        [FromQuery] int? cityId, [FromQuery] string? q, [FromQuery] VenueStatus? status, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        Ok(await sender.Send(new AdminListVenuesQuery(cityId, q, status, page, pageSize), ct));

    [HttpGet("similar")]
    public async Task<ActionResult<IReadOnlyList<VenueDto>>> Similar([FromQuery] int cityId, [FromQuery] string name, CancellationToken ct) =>
        Ok(await sender.Send(new FindSimilarVenuesQuery(cityId, name), ct));

    [HttpGet("{venueId:guid}")]
    public async Task<ActionResult<VenueDto>> Get(Guid venueId, CancellationToken ct) => Ok(await sender.Send(new GetVenueQuery(venueId, IncludeHidden: true), ct));

    [HttpPost]
    public async Task<ActionResult<VenueDto>> Create(VenueRequest r, CancellationToken ct) =>
        Ok(await sender.Send(new CreateVenueCommand(r.CityId, r.Name, r.Address, r.Phone, r.Latitude, r.Longitude, r.Sports ?? [], r.AllowSimilar), ct));

    [HttpPut("{venueId:guid}")]
    public async Task<ActionResult<VenueDto>> Update(Guid venueId, VenueRequest r, CancellationToken ct) =>
        Ok(await sender.Send(new UpdateVenueCommand(venueId, r.Name, r.Address, r.Phone, r.Latitude, r.Longitude, r.Sports ?? []), ct));

    [HttpPost("import")]
    [RequestSizeLimit(5_000_000)]
    public async Task<ActionResult<VenueImportResultDto>> Import(VenueImportRequest request, CancellationToken ct) =>
        Ok(await sender.Send(new ImportVenuesCommand(request.Items ?? [], request.AllowSimilar), ct));

    [HttpPut("{venueId:guid}/profile")]
    public async Task<ActionResult<VenueDto>> UpdateProfile(Guid venueId, VenueProfileInput profile, CancellationToken ct) =>
        Ok(await sender.Send(new UpdateVenueProfileCommand(venueId, profile), ct));

    [HttpPost("{venueId:guid}/images")]
    [RequestSizeLimit(11 * 1024 * 1024)]
    public async Task<ActionResult<VenueDto>> AddImage(Guid venueId, IFormFile file, CancellationToken ct)
    {
        await using var stream = file.OpenReadStream();
        return Ok(await sender.Send(new AddVenueImageCommand(venueId, stream, file.Length), ct));
    }

    [HttpDelete("{venueId:guid}/images")]
    public async Task<ActionResult<VenueDto>> RemoveImage(Guid venueId, [FromQuery] string path, CancellationToken ct) =>
        Ok(await sender.Send(new RemoveVenueImageCommand(venueId, path), ct));

    [HttpPost("{venueId:guid}/hide")]
    public async Task<IActionResult> Hide(Guid venueId, CancellationToken ct)
    {
        await sender.Send(new SetVenueHiddenCommand(venueId, true), ct);
        return NoContent();
    }

    [HttpPost("{venueId:guid}/unhide")]
    public async Task<IActionResult> Unhide(Guid venueId, CancellationToken ct)
    {
        await sender.Send(new SetVenueHiddenCommand(venueId, false), ct);
        return NoContent();
    }
}

[ApiController]
[ApiVersion("1.0")]
[Authorize(Policy = Policies.AdminOnly)]
[Route("api/v{version:apiVersion}/admin/venue-candidates")]
public sealed class AdminVenueCandidatesController(ISender sender) : ControllerBase
{
    [HttpPost("import")]
    [RequestSizeLimit(5_000_000)]
    public async Task<ActionResult<ImportResultDto>> Import(ImportRequest request, CancellationToken ct) =>
        Ok(await sender.Send(new ImportCandidatesCommand(request.Items ?? []), ct));

    [HttpGet]
    public async Task<ActionResult<PagedResult<VenueCandidateDto>>> List(
        [FromQuery] int? provinceId, [FromQuery] int? cityId, [FromQuery] CandidateStatus? status, [FromQuery] string? keyword,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        Ok(await sender.Send(new ListCandidatesQuery(provinceId, cityId, status, keyword, page, pageSize), ct));

    [HttpPost("{candidateId:guid}/approve")]
    public async Task<ActionResult<VenueDto>> Approve(Guid candidateId, ApprovalRequest r, CancellationToken ct) =>
        Ok(await sender.Send(new ApproveCandidateCommand(candidateId, r.Name, r.Address, r.Phone, r.Latitude, r.Longitude, r.Sports ?? []), ct));

    [HttpPost("{candidateId:guid}/merge")]
    public async Task<IActionResult> Merge(Guid candidateId, MergeRequest request, CancellationToken ct)
    {
        await sender.Send(new MergeCandidateCommand(candidateId, request.VenueId), ct);
        return NoContent();
    }

    [HttpPost("{candidateId:guid}/reject")]
    public async Task<IActionResult> Reject(Guid candidateId, RejectRequest request, CancellationToken ct)
    {
        await sender.Send(new RejectCandidateCommand(candidateId, request.Reason), ct);
        return NoContent();
    }

    [HttpPost("bulk-approve")]
    public async Task<IActionResult> BulkApprove(BulkApproveRequest request, CancellationToken ct)
    {
        await sender.Send(new BulkApproveCandidatesCommand(request.CandidateIds ?? [], request.Sports ?? []), ct);
        return NoContent();
    }
}
