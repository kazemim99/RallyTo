using Rallyto.Community.Application.Abstractions;
using Rallyto.Community.Application.Players;
using Rallyto.Community.Application.Search;
using Rallyto.Community.Domain.Matches;
using Rallyto.Community.Domain.Players;
using Rallyto.Community.Domain.Search;
using Rallyto.Contracts.Community;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Core.Application.Localization;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Community.Application.Matches;

public sealed record GetMatchQuery(Guid MatchId) : IQuery<MatchView>;

public sealed record GetMatchByTokenQuery(string Token) : IQuery<MatchView>;

public sealed record GetShareSummaryQuery(string Token) : IQuery<ShareSummaryView>;

public sealed record ListMyMatchesQuery(bool Upcoming) : IQuery<IReadOnlyList<MatchView>>;

internal sealed class GetMatchHandler(MatchWorkflow workflow, MatchAssembler assembler) : IQueryHandler<GetMatchQuery, MatchView>
{
    public async Task<MatchView> Handle(GetMatchQuery request, CancellationToken cancellationToken)
    {
        var me = await workflow.MeAsync(cancellationToken);
        var (match, involved) = await workflow.LoadVisibleAsync(me, request.MatchId, cancellationToken);
        return await assembler.ViewAsync(match, me.Id, involved, cancellationToken);
    }
}

internal sealed class GetMatchByTokenHandler(MatchWorkflow workflow, IMatchRepository matches, MatchAssembler assembler) : IQueryHandler<GetMatchByTokenQuery, MatchView>
{
    public async Task<MatchView> Handle(GetMatchByTokenQuery request, CancellationToken cancellationToken)
    {
        var me = await workflow.MeAsync(cancellationToken);
        var match = await matches.GetByShareTokenAsync(request.Token, cancellationToken);
        try
        {
            if (match is null || match.Visibility != MatchVisibility.Public)
                throw WorkflowNotAvailable();
            var (_, involved) = await workflow.LoadVisibleAsync(me, match.Id, cancellationToken);
            return await assembler.ViewAsync(match, me.Id, involved, cancellationToken);
        }
        catch (NotFoundException)
        {
            throw WorkflowNotAvailable();
        }
    }

    private static NotFoundException WorkflowNotAvailable() => new("این بازی در دسترس نیست.", "MATCH_NOT_AVAILABLE");
}

/// <summary>Anonymous summary behind a share link: no photo, age or contact detail (spec play-posts › Share link).</summary>
internal sealed class GetShareSummaryHandler(IMatchRepository matches, IPlayerProfileRepository profiles, ICatalogReader catalog) : IQueryHandler<GetShareSummaryQuery, ShareSummaryView>
{
    public async Task<ShareSummaryView> Handle(GetShareSummaryQuery request, CancellationToken cancellationToken)
    {
        var match = await matches.GetByShareTokenAsync(request.Token ?? string.Empty, cancellationToken);
        if (match is null || match.Visibility != MatchVisibility.Public || match.Status is MatchStatus.Cancelled)
            throw new NotFoundException("این پیوند دیگر معتبر نیست.", "SHARE_LINK_INVALID");
        var host = await profiles.GetAsync(match.HostId, cancellationToken);
        if (host is null || host.Status != ProfileStatus.Active)
            throw new NotFoundException("این پیوند دیگر معتبر نیست.", "SHARE_LINK_INVALID");

        var sport = (await catalog.SportsAsync(cancellationToken)).FirstOrDefault(s => s.Id == match.SportId);
        var venue = (await catalog.VenuesAsync([match.VenueId], cancellationToken)).GetValueOrDefault(match.VenueId);
        var city = await catalog.CityAsync(match.CityId, cancellationToken);
        var local = PersianFormat.ToTehran(match.StartsAt);
        var hostLevel = host.SportProfileFor(match.SportId)?.Level is { } level ? sport?.Levels.FirstOrDefault(l => l.Tier == level)?.Name : null;
        return new ShareSummaryView(sport?.NameFa ?? string.Empty, match.Format, venue?.Name ?? string.Empty, city?.Name ?? string.Empty,
            PersianFormat.JalaliAscii(DateOnly.FromDateTime(local)), local.ToString("HH:mm", System.Globalization.CultureInfo.InvariantCulture),
            match.MinLevel, match.MaxLevel, match.OpenSpots, match.CourtBooked, host.DisplayName, hostLevel);
    }
}

internal sealed class ListMyMatchesHandler(MatchWorkflow workflow, IMatchRepository matches, MatchAssembler assembler) : IQueryHandler<ListMyMatchesQuery, IReadOnlyList<MatchView>>
{
    public async Task<IReadOnlyList<MatchView>> Handle(ListMyMatchesQuery request, CancellationToken cancellationToken)
    {
        var me = await workflow.MeAsync(cancellationToken);
        var list = await matches.ListForPlayerAsync(me.Id, request.Upcoming, workflow.Now, cancellationToken);
        return await assembler.ViewsAsync(list.Select(m => (m, true)).ToList(), me.Id, cancellationToken);
    }
}

/// <summary>Open posts for partner search, through the same visibility rules as players (spec partner-search › Post results).</summary>
public sealed class PostSearchService(IMatchRepository matches, IPlayerProfileRepository profiles, VisibilityService visibility, MatchAssembler assembler, TimeProvider clock)
{
    public async Task<IReadOnlyList<MatchView>> SearchAsync(PlayerProfile searcher, SearchCriteria criteria, CancellationToken cancellationToken)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var today = PersianFormat.TehranToday(now);
        var (fromDay, toDay) = criteria.Date is { } d ? (d, d) : (today, today.AddDays(SearchCriteriaResolver.MaxDaysAhead));
        var fromUtc = ToUtc(fromDay, 0);
        var toUtc = ToUtc(toDay.AddDays(1), 0);

        var results = new List<(Match, bool)>();
        foreach (var match in await matches.ListOpenPostsAsync(criteria.SportId, criteria.CityId, fromUtc > now ? fromUtc : now, toUtc, cancellationToken))
        {
            if (!await MatchesAsync(searcher, criteria, match, cancellationToken))
                continue;
            results.Add((match, match.ParticipantOf(searcher.Id) is not null || match.HostId == searcher.Id));
        }

        return await assembler.ViewsAsync(results.OrderBy(r => r.Item1.StartsAt).ToList(), searcher.Id, cancellationToken);
    }

    /// <summary>Whether a post is a result of these criteria for this searcher; also used for saved-search alerts.</summary>
    public async Task<bool> MatchesAsync(PlayerProfile searcher, SearchCriteria criteria, Match match, CancellationToken cancellationToken)
    {
        if (match.HostId == searcher.Id || !match.AcceptsPlayers(clock.GetUtcNow().UtcDateTime) || match.SportId != criteria.SportId || match.CityId != criteria.CityId)
            return false;
        if (criteria.VenueIds.Count > 0 && !criteria.VenueIds.Contains(match.VenueId))
            return false;
        if (criteria.Format is { } format && match.Format != format)
            return false;
        if (match.MaxLevel < criteria.MinLevel || match.MinLevel > criteria.MaxLevel)
            return false;
        if (!MatchAssembler.AcceptsGender(match, searcher.Gender))
            return false;

        var local = PersianFormat.ToTehran(match.StartsAt);
        var day = DateOnly.FromDateTime(local);
        if (criteria.Date is { } date ? day != date : criteria.Weekdays != Domain.Availabilities.IranianWeekdays.None && !criteria.Weekdays.HasFlag(Domain.Availabilities.IranianWeek.Of(day)))
            return false;
        var start = local.Hour * 60 + local.Minute;
        if (start >= criteria.ToMinute || start + match.DurationMinutes <= criteria.FromMinute)
            return false;

        var host = await profiles.GetAsync(match.HostId, cancellationToken);
        return host is not null && await visibility.CanSeeAsync(searcher, host, cancellationToken);
    }

    private static DateTime ToUtc(DateOnly day, int minute) =>
        TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(day.ToDateTime(TimeOnly.MinValue).AddMinutes(minute), DateTimeKind.Unspecified), PersianFormat.Tehran);
}

/// <summary>Turns match domain events into integration events for Notifications and Messaging (design D3).</summary>
internal sealed class MatchEventsPublisher(IIntegrationEventPublisher events, IMatchRepository matches) :
    IDomainEventHandler<Domain.Matches.JoinRequested>,
    IDomainEventHandler<Domain.Matches.JoinAnswered>,
    IDomainEventHandler<Domain.Matches.InvitationSent>,
    IDomainEventHandler<Domain.Matches.InvitationAnswered>,
    IDomainEventHandler<Domain.Matches.MatchConfirmed>,
    IDomainEventHandler<Domain.Matches.MatchCancelled>,
    IDomainEventHandler<Domain.Matches.MatchExpired>,
    IDomainEventHandler<Domain.Matches.ParticipantLeft>,
    IDomainEventHandler<Domain.Matches.ParticipantRemoved>,
    IDomainEventHandler<Domain.Matches.AttendanceOpened>,
    IDomainEventHandler<Domain.Matches.MatchResolved>
{
    public Task HandleAsync(Domain.Matches.JoinRequested e, CancellationToken ct) => Publish(new JoinRequestReceived(e.MatchId, e.HostId, e.PlayerId));

    public Task HandleAsync(Domain.Matches.JoinAnswered e, CancellationToken ct) => Publish(new JoinRequestAnswered(e.MatchId, e.PlayerId, e.Accepted));

    public Task HandleAsync(Domain.Matches.InvitationSent e, CancellationToken ct) => Publish(new InvitationReceived(e.MatchId, e.HostId, e.PlayerId));

    public Task HandleAsync(Domain.Matches.InvitationAnswered e, CancellationToken ct) => Publish(new Contracts.Community.InvitationAnswered(e.MatchId, e.HostId, e.PlayerId, e.Accepted));

    public async Task HandleAsync(Domain.Matches.MatchConfirmed e, CancellationToken ct)
    {
        var match = await matches.GetAsync(e.MatchId, ct);
        events.Enqueue(new Contracts.Community.MatchConfirmed(e.MatchId, e.HostId, e.PlayerIds, match?.Capacity ?? 2));
    }

    public async Task HandleAsync(Domain.Matches.MatchCancelled e, CancellationToken ct)
    {
        var match = await matches.GetAsync(e.MatchId, ct);
        events.Enqueue(new Contracts.Community.MatchCancelled(e.MatchId, e.HostId, e.PlayerIds, e.Reason, match?.StartsAt ?? DateTime.UtcNow));
    }

    public Task HandleAsync(Domain.Matches.MatchExpired e, CancellationToken ct) => Publish(new Contracts.Community.MatchExpired(e.MatchId, e.HostId));

    public async Task HandleAsync(Domain.Matches.ParticipantLeft e, CancellationToken ct) =>
        events.Enqueue(new Contracts.Community.ParticipantLeft(e.MatchId, e.HostId, e.PlayerId, await RemainingAsync(e.MatchId, ct)));

    public async Task HandleAsync(Domain.Matches.ParticipantRemoved e, CancellationToken ct) =>
        events.Enqueue(new Contracts.Community.ParticipantRemoved(e.MatchId, e.PlayerId, await RemainingAsync(e.MatchId, ct)));

    public Task HandleAsync(Domain.Matches.AttendanceOpened e, CancellationToken ct) => Publish(new Contracts.Community.AttendanceOpened(e.MatchId, e.PlayerIds));

    public Task HandleAsync(Domain.Matches.MatchResolved e, CancellationToken ct) =>
        Publish(new Contracts.Community.MatchResolved(e.MatchId, e.SportId, e.Status.ToString(), e.PlayedIds, e.NoShowIds));

    private async Task<IReadOnlyList<Guid>> RemainingAsync(Guid matchId, CancellationToken ct) =>
        (await matches.GetAsync(matchId, ct))?.PlayerIds() ?? [];

    private Task Publish(IntegrationEvent integrationEvent)
    {
        events.Enqueue(integrationEvent);
        return Task.CompletedTask;
    }
}

/// <summary>Checks alerting saved searches against a new play post (spec partner-search › Saved searches and alerts).</summary>
internal sealed class SavedSearchPostAlertHandler(
    IMatchRepository matches,
    IPlayerProfileRepository profiles,
    ISavedSearchRepository searches,
    PostSearchService posts,
    IIntegrationEventPublisher events,
    TimeProvider clock) : IDomainEventHandler<MatchPublished>
{
    public async Task HandleAsync(MatchPublished domainEvent, CancellationToken cancellationToken)
    {
        var match = await matches.GetAsync(domainEvent.MatchId, cancellationToken);
        if (match is null)
            return;
        var now = clock.GetUtcNow().UtcDateTime;
        var today = PersianFormat.TehranToday(now);
        foreach (var search in await searches.ListAlertingAsync(match.SportId, match.CityId, cancellationToken))
        {
            if (await profiles.GetAsync(search.OwnerId, cancellationToken) is not { } owner || !await posts.MatchesAsync(owner, search.Criteria, match, cancellationToken))
                continue;
            var count = search.RecordMatch(now, today);
            if (count > 0)
                events.Enqueue(new SavedSearchMatched(search.OwnerId, search.Id, search.Name, count));
        }
    }
}
