using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Rallyto.Community.Application.Search;
using Rallyto.Community.Domain.Availabilities;
using Rallyto.Community.Domain.Players;
using Rallyto.Core.Domain.SharedKernel;
using Rallyto.Infrastructure.Web.RateLimiting;

namespace Rallyto.Community.Api.Controllers;

public sealed record SavedSearchRequest(string Name, bool AlertsEnabled, SearchCriteriaInput Criteria);

[ApiController]
[ApiVersion("1.0")]
[Authorize]
[Route("api/v{version:apiVersion}")]
public sealed class SearchController(ISender sender) : ControllerBase
{
    /// <summary>
    /// Partner search (spec partner-search). <c>weekdays</c> is a comma-separated list such as <c>Saturday,Monday</c>;
    /// <c>date</c> is Jalali, for example <c>1405/08/02</c>; <c>results</c> is <c>Both</c> (default), <c>Players</c> or <c>Posts</c>.
    /// </summary>
    [HttpGet("search/partners")]
    [EnableRateLimiting(RateLimitPolicies.Search)]
    public async Task<ActionResult<SearchResultsView>> Partners(
        [FromQuery] Guid sportId, [FromQuery] int? cityId, [FromQuery] Guid[]? venueIds, [FromQuery] string? date, [FromQuery] string? weekdays,
        [FromQuery] string? from, [FromQuery] string? to, [FromQuery] LevelTier? minLevel, [FromQuery] LevelTier? maxLevel,
        [FromQuery] Gender? gender, [FromQuery] PlayFormat? format, [FromQuery] string? cursor, [FromQuery] SearchResultType results, CancellationToken ct)
    {
        var days = (weekdays ?? string.Empty)
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(d => Enum.TryParse<IranianWeekdays>(d, ignoreCase: true, out var day) ? day : IranianWeekdays.None)
            .Where(d => d != IranianWeekdays.None)
            .ToList();
        var criteria = new SearchCriteriaInput(sportId, cityId, venueIds, date, days, from, to, minLevel, maxLevel, gender, format);
        return Ok(await sender.Send(new SearchPartnersQuery(criteria, cursor, results), ct));
    }

    [HttpGet("saved-searches")]
    public async Task<ActionResult<IReadOnlyList<SavedSearchView>>> SavedSearches(CancellationToken ct) => Ok(await sender.Send(new ListSavedSearchesQuery(), ct));

    [HttpPost("saved-searches")]
    public async Task<ActionResult<SavedSearchView>> Save(SavedSearchRequest r, CancellationToken ct) =>
        StatusCode(StatusCodes.Status201Created, await sender.Send(new CreateSavedSearchCommand(r.Name, r.AlertsEnabled, r.Criteria), ct));

    [HttpPut("saved-searches/{id:guid}")]
    public async Task<ActionResult<SavedSearchView>> Update(Guid id, SavedSearchRequest r, CancellationToken ct) =>
        Ok(await sender.Send(new UpdateSavedSearchCommand(id, r.Name, r.AlertsEnabled, r.Criteria), ct));

    [HttpDelete("saved-searches/{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        await sender.Send(new DeleteSavedSearchCommand(id), ct);
        return NoContent();
    }
}
