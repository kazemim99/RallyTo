using Rallyto.Community.Application.Abstractions;
using Rallyto.Community.Application.Players;
using Rallyto.Community.Domain.Availabilities;
using Rallyto.Community.Domain.Players;
using Rallyto.Community.Domain.Search;
using Rallyto.Contracts.Community;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Core.Application.Localization;

namespace Rallyto.Community.Application.Search;

/// <summary>Which result kinds a search returns (spec partner-search).</summary>
public enum SearchResultType
{
    Both = 0,
    Players = 1,
    Posts = 2,
}

public sealed record SearchPartnersQuery(SearchCriteriaInput Criteria, string? Cursor, SearchResultType Results = SearchResultType.Both) : IQuery<SearchResultsView>;

/// <summary>The criteria come back in the shape they are sent in, with the city and club names for display.</summary>
public sealed record SavedSearchView(
    Guid Id,
    string Name,
    bool AlertsEnabled,
    int AlertsSent,
    int PendingMatches,
    DateTime? LastAlertAt,
    string? ExpiresOn,
    SearchCriteriaInput Criteria,
    CityRef City,
    IReadOnlyList<NamedRef> Venues);

public sealed record CreateSavedSearchCommand(string Name, bool AlertsEnabled, SearchCriteriaInput Criteria) : ICommand<SavedSearchView>;

public sealed record UpdateSavedSearchCommand(Guid SavedSearchId, string Name, bool AlertsEnabled, SearchCriteriaInput Criteria) : ICommand<SavedSearchView>;

public sealed record DeleteSavedSearchCommand(Guid SavedSearchId) : ICommand;

public sealed record ListSavedSearchesQuery : IQuery<IReadOnlyList<SavedSearchView>>;

public interface ISavedSearchRepository
{
    Task<SavedSearch?> GetAsync(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyList<SavedSearch>> ListByOwnerAsync(Guid ownerId, CancellationToken cancellationToken);
    Task<IReadOnlyList<SavedSearch>> ListAlertingAsync(Guid sportId, int cityId, CancellationToken cancellationToken);
    void Add(SavedSearch search);
    void Remove(SavedSearch search);
}

internal sealed class SearchPartnersHandler(PlayerContext player, SearchCriteriaResolver resolver, PartnerSearchService search, Matches.PostSearchService posts)
    : IQueryHandler<SearchPartnersQuery, SearchResultsView>
{
    public async Task<SearchResultsView> Handle(SearchPartnersQuery request, CancellationToken cancellationToken)
    {
        var profile = await player.RequireProfileAsync(cancellationToken);
        var criteria = await resolver.ResolveAsync(profile, request.Criteria, cancellationToken);
        var players = request.Results == SearchResultType.Posts
            ? new SearchResultsView([], [], null)
            : await search.SearchAsync(profile, criteria, request.Cursor, cancellationToken);
        // Posts are few and sorted by start time; they come with the first page only.
        var postResults = string.IsNullOrEmpty(request.Cursor) && request.Results != SearchResultType.Players
            ? await posts.SearchAsync(profile, criteria, cancellationToken)
            : [];
        return players with { Posts = postResults };
    }
}

public sealed class SavedSearchAssembler(ICatalogReader catalog)
{
    public async Task<SavedSearchView> ViewAsync(SavedSearch s, CancellationToken cancellationToken) => (await ViewsAsync([s], cancellationToken))[0];

    public async Task<IReadOnlyList<SavedSearchView>> ViewsAsync(IReadOnlyList<SavedSearch> list, CancellationToken cancellationToken)
    {
        var venues = await catalog.VenuesAsync(list.SelectMany(s => s.Criteria.VenueIds).Distinct().ToList(), cancellationToken);
        var cities = new Dictionary<int, string>();
        foreach (var cityId in list.Select(s => s.Criteria.CityId).Distinct())
            cities[cityId] = (await catalog.CityAsync(cityId, cancellationToken))?.Name ?? string.Empty;
        return list.Select(s => new SavedSearchView(s.Id, s.Name, s.AlertsEnabled, s.AlertsSent, s.PendingMatches, s.LastAlertAt,
                s.ExpiresOn is { } d ? PersianFormat.JalaliAscii(d) : null, ToInput(s.Criteria), new CityRef(s.Criteria.CityId, cities[s.Criteria.CityId]),
                s.Criteria.VenueIds.Select(id => new NamedRef(id, venues.GetValueOrDefault(id)?.Name ?? string.Empty)).ToList()))
            .ToList();
    }

    public static SearchCriteriaInput ToInput(SearchCriteria c) =>
        new(c.SportId, c.CityId, c.VenueIds, c.Date is { } date ? PersianFormat.JalaliAscii(date) : null,
            c.Date is null ? Enum.GetValues<IranianWeekdays>().Where(d => IsSingleDay(d) && c.Weekdays.HasFlag(d)).ToList() : [],
            Clock(c.FromMinute), Clock(c.ToMinute), c.MinLevel, c.MaxLevel, c.Gender, c.Format);

    private static bool IsSingleDay(IranianWeekdays day) => day != IranianWeekdays.None && ((int)day & ((int)day - 1)) == 0;

    private static string Clock(int minute) => $"{minute / 60:00}:{minute % 60:00}";
}

internal sealed class CreateSavedSearchHandler(PlayerContext player, SearchCriteriaResolver resolver, ISavedSearchRepository searches, SavedSearchAssembler assembler, ICommunityUnitOfWork unitOfWork)
    : ICommandHandler<CreateSavedSearchCommand, SavedSearchView>
{
    public async Task<SavedSearchView> Handle(CreateSavedSearchCommand request, CancellationToken cancellationToken)
    {
        var profile = await player.RequireProfileAsync(cancellationToken);
        if ((await searches.ListByOwnerAsync(profile.Id, cancellationToken)).Count >= SavedSearch.MaxPerPlayer)
            throw new ConflictException("TOO_MANY_SAVED_SEARCHES", $"حداکثر {SavedSearch.MaxPerPlayer} جستجو را می‌توانید ذخیره کنید.");
        var search = SavedSearch.Create(profile.Id, request.Name, await resolver.ResolveAsync(profile, request.Criteria, cancellationToken), request.AlertsEnabled);
        searches.Add(search);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return await assembler.ViewAsync(search, cancellationToken);
    }
}

internal sealed class UpdateSavedSearchHandler(PlayerContext player, SearchCriteriaResolver resolver, ISavedSearchRepository searches, SavedSearchAssembler assembler, ICommunityUnitOfWork unitOfWork)
    : ICommandHandler<UpdateSavedSearchCommand, SavedSearchView>
{
    public async Task<SavedSearchView> Handle(UpdateSavedSearchCommand request, CancellationToken cancellationToken)
    {
        var profile = await player.RequireProfileAsync(cancellationToken);
        var search = await searches.GetAsync(request.SavedSearchId, cancellationToken);
        if (search is null || search.OwnerId != profile.Id)
            throw new NotFoundException("جستجو پیدا نشد.");
        search.Update(request.Name, await resolver.ResolveAsync(profile, request.Criteria, cancellationToken), request.AlertsEnabled);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return await assembler.ViewAsync(search, cancellationToken);
    }
}

internal sealed class DeleteSavedSearchHandler(PlayerContext player, ISavedSearchRepository searches, ICommunityUnitOfWork unitOfWork) : ICommandHandler<DeleteSavedSearchCommand>
{
    public async Task Handle(DeleteSavedSearchCommand request, CancellationToken cancellationToken)
    {
        var profile = await player.RequireProfileAsync(cancellationToken);
        var search = await searches.GetAsync(request.SavedSearchId, cancellationToken);
        if (search is null || search.OwnerId != profile.Id)
            throw new NotFoundException("جستجو پیدا نشد.");
        searches.Remove(search);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
    }
}

internal sealed class ListSavedSearchesHandler(PlayerContext player, ISavedSearchRepository searches, SavedSearchAssembler assembler) : IQueryHandler<ListSavedSearchesQuery, IReadOnlyList<SavedSearchView>>
{
    public async Task<IReadOnlyList<SavedSearchView>> Handle(ListSavedSearchesQuery request, CancellationToken cancellationToken)
    {
        var profile = await player.RequireProfileAsync(cancellationToken);
        return await assembler.ViewsAsync(await searches.ListByOwnerAsync(profile.Id, cancellationToken), cancellationToken);
    }
}

/// <summary>
/// Checks alerting saved searches against a newly published or resumed window, from each owner's point of view, with
/// the same rules as search (spec partner-search › Saved searches and alerts).
/// </summary>
internal sealed class SavedSearchAlertHandler(
    IAvailabilityRepository windows,
    IPlayerProfileRepository profiles,
    IBlockRepository blocks,
    ISavedSearchRepository searches,
    IIntegrationEventPublisher events,
    TimeProvider clock) : IDomainEventHandler<AvailabilityPublished>
{
    public async Task HandleAsync(AvailabilityPublished domainEvent, CancellationToken cancellationToken)
    {
        var window = await windows.GetAsync(domainEvent.AvailabilityId, cancellationToken);
        var owner = await profiles.GetAsync(domainEvent.PlayerId, cancellationToken);
        if (window is null || owner is null)
            return;

        var now = clock.GetUtcNow().UtcDateTime;
        var today = PersianFormat.TehranToday(now);
        var candidate = new WindowCandidate(window.Id, owner.Id, owner.Gender, owner.Visibility, owner.Status, owner.SportProfileFor(window.SportId)?.Level,
            window.SportId, window.CityId, window.Status, window.Kind, window.Weekdays, window.Date, window.ValidUntil,
            window.StartMinute, window.EndMinute, window.VenueIds, window.Formats);

        foreach (var search in await searches.ListAlertingAsync(window.SportId, window.CityId, cancellationToken))
        {
            if (search.OwnerId == owner.Id || await profiles.GetAsync(search.OwnerId, cancellationToken) is not { } searcher)
                continue;
            var blocked = await blocks.IsBlockedEitherWayAsync(searcher.Id, owner.Id, cancellationToken);
            if (PartnerMatchRules.Match(search.Criteria, VisibilityPolicy.FactsOf(searcher), candidate, blocked, today) == 0)
                continue;
            var count = search.RecordMatch(now, today);
            if (count > 0)
                events.Enqueue(new SavedSearchMatched(search.OwnerId, search.Id, search.Name, count));
        }
    }
}
