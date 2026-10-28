using Rallyto.Catalog.Application.Abstractions;
using Rallyto.Catalog.Application.Sports;
using Rallyto.Catalog.Domain.Venues;
using Rallyto.Contracts.Catalog;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Core.Application.Results;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Catalog.Application.Venues;

public sealed record ListVenuesQuery(int CityId, string? Sport, string? Query) : IQuery<IReadOnlyList<VenueDto>>
{
    public bool IsCacheable => true;
    public IReadOnlyCollection<string>? CacheTags => [CatalogMapping.CacheTag];
}

public sealed record GetVenueQuery(Guid VenueId, bool IncludeHidden) : IQuery<VenueDto>;

public sealed record AdminListVenuesQuery(int? CityId, string? Query, VenueStatus? Status, int Page = 1, int PageSize = 20) : IQuery<PagedResult<VenueDto>>;

public sealed record FindSimilarVenuesQuery(int CityId, string Name) : IQuery<IReadOnlyList<VenueDto>>;

public sealed record CreateVenueCommand(
    int CityId,
    string Name,
    string? Address,
    string? Phone,
    double? Latitude,
    double? Longitude,
    IReadOnlyList<VenueSportInput> Sports,
    bool AllowSimilar) : ICommand<VenueDto>;

public sealed record UpdateVenueCommand(
    Guid VenueId,
    string Name,
    string? Address,
    string? Phone,
    double? Latitude,
    double? Longitude,
    IReadOnlyList<VenueSportInput> Sports) : ICommand<VenueDto>;

public sealed record SetVenueHiddenCommand(Guid VenueId, bool Hidden) : ICommand;

/// <summary>Turns sport codes into ids and venues into DTOs with city names.</summary>
public sealed class VenueAssembler(ISportRepository sports, ILocationRepository locations)
{
    public async Task<IReadOnlyDictionary<Guid, string>> SportCodesAsync(CancellationToken cancellationToken) =>
        (await sports.ListAsync(includeInactive: true, cancellationToken)).ToDictionary(s => s.Id, s => s.Code);

    public async Task<Guid?> SportIdAsync(string? code, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(code))
            return null;
        var sport = (await sports.ListAsync(includeInactive: true, cancellationToken)).FirstOrDefault(s => s.Code == code.Trim().ToLowerInvariant());
        return sport?.Id ?? throw new ValidationFailedException("UNKNOWN_SPORT", "ورزش انتخاب‌شده وجود ندارد.");
    }

    public async Task<List<VenueSport>> ToVenueSportsAsync(IEnumerable<VenueSportInput> inputs, CancellationToken cancellationToken)
    {
        var all = (await sports.ListAsync(includeInactive: true, cancellationToken)).ToDictionary(s => s.Code);
        return inputs.Select(i => all.TryGetValue(i.SportCode?.Trim().ToLowerInvariant() ?? string.Empty, out var sport)
                ? new VenueSport(sport.Id, i.CourtCount, i.Setting, i.Surface, i.HasLighting)
                : throw new ValidationFailedException("UNKNOWN_SPORT", $"ورزش «{i.SportCode}» وجود ندارد."))
            .ToList();
    }

    public async Task<IReadOnlyList<VenueDto>> ToDtosAsync(IReadOnlyList<Venue> venues, CancellationToken cancellationToken)
    {
        var codes = await SportCodesAsync(cancellationToken);
        var cities = await locations.CityNamesAsync(venues.Select(v => v.CityId).Distinct(), cancellationToken);
        return venues.Select(v => CatalogMapping.ToDto(v, cities.GetValueOrDefault(v.CityId, string.Empty), codes)).ToList();
    }

    public async Task<VenueDto> ToDtoAsync(Venue venue, CancellationToken cancellationToken) => (await ToDtosAsync([venue], cancellationToken))[0];

    public async Task EnsureCityExistsAsync(int cityId, CancellationToken cancellationToken)
    {
        if (await locations.GetCityAsync(cityId, cancellationToken) is null)
            throw new ValidationFailedException("UNKNOWN_CITY", "شهر انتخاب‌شده وجود ندارد.");
    }
}

internal sealed class ListVenuesHandler(IVenueRepository venues, VenueAssembler assembler) : IQueryHandler<ListVenuesQuery, IReadOnlyList<VenueDto>>
{
    public async Task<IReadOnlyList<VenueDto>> Handle(ListVenuesQuery request, CancellationToken cancellationToken)
    {
        var sportId = await assembler.SportIdAsync(request.Sport, cancellationToken);
        var query = PersianText.Normalize(request.Query);
        var list = await venues.ListAsync(new VenueFilter(request.CityId, sportId, query.Length == 0 ? null : query, VenueStatus.Active), cancellationToken);
        return await assembler.ToDtosAsync(list, cancellationToken);
    }
}

internal sealed class GetVenueHandler(IVenueRepository venues, VenueAssembler assembler) : IQueryHandler<GetVenueQuery, VenueDto>
{
    public async Task<VenueDto> Handle(GetVenueQuery request, CancellationToken cancellationToken)
    {
        var venue = await venues.GetByIdAsync(request.VenueId, cancellationToken);
        if (venue is null || (!request.IncludeHidden && venue.Status != VenueStatus.Active))
            throw new NotFoundException("باشگاه پیدا نشد.");
        return await assembler.ToDtoAsync(venue, cancellationToken);
    }
}

internal sealed class AdminListVenuesHandler(IVenueRepository venues, VenueAssembler assembler) : IQueryHandler<AdminListVenuesQuery, PagedResult<VenueDto>>
{
    public async Task<PagedResult<VenueDto>> Handle(AdminListVenuesQuery request, CancellationToken cancellationToken)
    {
        var query = PersianText.Normalize(request.Query);
        var page = await venues.PageAsync(new VenueFilter(request.CityId, null, query.Length == 0 ? null : query, request.Status),
            Math.Max(1, request.Page), Math.Clamp(request.PageSize, 1, 100), cancellationToken);
        return new PagedResult<VenueDto>(await assembler.ToDtosAsync(page.Items, cancellationToken), page.Page, page.PageSize, page.TotalCount);
    }
}

internal sealed class FindSimilarVenuesHandler(IVenueRepository venues, VenueAssembler assembler) : IQueryHandler<FindSimilarVenuesQuery, IReadOnlyList<VenueDto>>
{
    public async Task<IReadOnlyList<VenueDto>> Handle(FindSimilarVenuesQuery request, CancellationToken cancellationToken)
    {
        var inCity = await venues.ListAsync(new VenueFilter(request.CityId, null, null, VenueStatus.Active), cancellationToken);
        return await assembler.ToDtosAsync(inCity.Where(v => VenueNameSimilarity.AreSimilar(v.Name, request.Name)).ToList(), cancellationToken);
    }
}

internal sealed class CreateVenueHandler(IVenueRepository venues, VenueAssembler assembler, CatalogAdminSession session) : ICommandHandler<CreateVenueCommand, VenueDto>
{
    public async Task<VenueDto> Handle(CreateVenueCommand request, CancellationToken cancellationToken)
    {
        await assembler.EnsureCityExistsAsync(request.CityId, cancellationToken);
        if (!request.AllowSimilar)
        {
            var inCity = await venues.ListAsync(new VenueFilter(request.CityId, null, null, VenueStatus.Active), cancellationToken);
            if (inCity.Any(v => VenueNameSimilarity.AreSimilar(v.Name, request.Name)))
                throw new ConflictException("SIMILAR_VENUE_EXISTS", "باشگاهی با نام مشابه در این شهر وجود دارد. اگر باشگاه دیگری است، دوباره تأیید کنید.");
        }

        var venue = Venue.Create(request.CityId,
            new VenueDetails(request.Name, request.Address, request.Phone, request.Latitude, request.Longitude),
            await assembler.ToVenueSportsAsync(request.Sports, cancellationToken), googlePlaceId: null);
        venues.Add(venue);
        await session.CommitAsync("venue.create", "Venue", venue.Id.ToString(), null, cancellationToken);
        return await assembler.ToDtoAsync(venue, cancellationToken);
    }
}

internal sealed class UpdateVenueHandler(IVenueRepository venues, VenueAssembler assembler, CatalogAdminSession session) : ICommandHandler<UpdateVenueCommand, VenueDto>
{
    public async Task<VenueDto> Handle(UpdateVenueCommand request, CancellationToken cancellationToken)
    {
        var venue = await venues.GetByIdAsync(request.VenueId, cancellationToken) ?? throw new NotFoundException();
        venue.Update(new VenueDetails(request.Name, request.Address, request.Phone, request.Latitude, request.Longitude),
            await assembler.ToVenueSportsAsync(request.Sports, cancellationToken));
        await session.CommitAsync("venue.update", "Venue", venue.Id.ToString(), null, cancellationToken);
        return await assembler.ToDtoAsync(venue, cancellationToken);
    }
}

internal sealed class SetVenueHiddenHandler(IVenueRepository venues, CatalogAdminSession session) : ICommandHandler<SetVenueHiddenCommand>
{
    public async Task Handle(SetVenueHiddenCommand request, CancellationToken cancellationToken)
    {
        var venue = await venues.GetByIdAsync(request.VenueId, cancellationToken) ?? throw new NotFoundException();
        if (request.Hidden)
            venue.Hide();
        else
            venue.Unhide();
        await session.CommitAsync(request.Hidden ? "venue.hide" : "venue.unhide", "Venue", venue.Id.ToString(), null, cancellationToken);
    }
}

/// <summary>Tells the other contexts that a club was hidden (design D3).</summary>
internal sealed class VenueHiddenHandler(IIntegrationEventPublisher events) : IDomainEventHandler<Domain.Venues.VenueHidden>
{
    public Task HandleAsync(Domain.Venues.VenueHidden domainEvent, CancellationToken cancellationToken)
    {
        events.Enqueue(new Contracts.Catalog.VenueHidden(domainEvent.VenueId));
        return Task.CompletedTask;
    }
}
