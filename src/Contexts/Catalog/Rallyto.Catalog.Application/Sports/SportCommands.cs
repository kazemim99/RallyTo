using Rallyto.Catalog.Application.Abstractions;
using Rallyto.Catalog.Domain.Sports;
using Rallyto.Contracts.Admin;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Catalog.Application.Sports;

public sealed record SportFormatInput(PlayFormat Format, int PlayersPerSide);

public sealed record LevelInput(LevelTier Tier, string Description);

public sealed record GetSportsQuery(bool IncludeInactive = false) : IQuery<IReadOnlyList<SportDto>>
{
    public bool IsCacheable => !IncludeInactive;
    public IReadOnlyCollection<string>? CacheTags => [CatalogMapping.CacheTag];
}

public sealed record CreateSportCommand(
    string Code,
    string NameFa,
    string NameEn,
    int DefaultSessionMinutes,
    IReadOnlyList<SportFormatInput> Formats,
    IReadOnlyList<LevelInput> Levels,
    IReadOnlyList<CourtSurface>? Surfaces) : ICommand<SportDto>;

public sealed record UpdateSportCommand(
    Guid SportId,
    string NameFa,
    string NameEn,
    int SortOrder,
    int DefaultSessionMinutes,
    IReadOnlyList<SportFormatInput> Formats,
    IReadOnlyList<LevelInput> Levels,
    IReadOnlyList<CourtSurface>? Surfaces) : ICommand<SportDto>;

public sealed record SetSportActiveCommand(Guid SportId, bool Active) : ICommand;

internal sealed class GetSportsHandler(ISportRepository sports) : IQueryHandler<GetSportsQuery, IReadOnlyList<SportDto>>
{
    public async Task<IReadOnlyList<SportDto>> Handle(GetSportsQuery request, CancellationToken cancellationToken) =>
        (await sports.ListAsync(request.IncludeInactive, cancellationToken)).Select(CatalogMapping.ToDto).ToList();
}

internal sealed class CreateSportHandler(ISportRepository sports, CatalogAdminSession session) : ICommandHandler<CreateSportCommand, SportDto>
{
    public async Task<SportDto> Handle(CreateSportCommand request, CancellationToken cancellationToken)
    {
        var code = request.Code?.Trim().ToLowerInvariant() ?? string.Empty;
        if (await sports.CodeExistsAsync(code, cancellationToken))
            throw new ConflictException("SPORT_CODE_TAKEN", "ورزشی با این کد وجود دارد.");

        var sport = Sport.Create(code, request.NameFa, request.NameEn, await sports.MaxSortOrderAsync(cancellationToken) + 1,
            request.DefaultSessionMinutes,
            request.Formats.Select(f => new SportFormat(f.Format, f.PlayersPerSide)),
            request.Levels.Select(l => new LevelDescription(l.Tier, l.Description)),
            request.Surfaces ?? []);
        sports.Add(sport);
        await session.CommitAsync("sport.create", "Sport", sport.Id.ToString(), null, cancellationToken);
        return CatalogMapping.ToDto(sport);
    }
}

internal sealed class UpdateSportHandler(ISportRepository sports, IFutureMatchReader futureMatches, CatalogAdminSession session) : ICommandHandler<UpdateSportCommand, SportDto>
{
    public async Task<SportDto> Handle(UpdateSportCommand request, CancellationToken cancellationToken)
    {
        var sport = await sports.GetByIdAsync(request.SportId, cancellationToken) ?? throw new NotFoundException();
        // A format may not be removed while future games use it (spec sport-catalog).
        foreach (var removed in sport.Formats.Select(f => f.Format).Except(request.Formats.Select(f => f.Format)))
        {
            if (await futureMatches.FormatInUseAsync(sport.Id, removed, cancellationToken))
                throw new ConflictException("FORMAT_IN_USE", "بازی‌های پیش رو از این قالب استفاده می‌کنند؛ حذف آن ممکن نیست.");
        }

        sport.Update(request.NameFa, request.NameEn, request.SortOrder, request.DefaultSessionMinutes,
            request.Levels.Select(l => new LevelDescription(l.Tier, l.Description)), request.Surfaces ?? []);
        sport.SetFormats(request.Formats.Select(f => new SportFormat(f.Format, f.PlayersPerSide)));
        await session.CommitAsync("sport.update", "Sport", sport.Id.ToString(), null, cancellationToken);
        return CatalogMapping.ToDto(sport);
    }
}

internal sealed class SetSportActiveHandler(ISportRepository sports, CatalogAdminSession session) : ICommandHandler<SetSportActiveCommand>
{
    public async Task Handle(SetSportActiveCommand request, CancellationToken cancellationToken)
    {
        var sport = await sports.GetByIdAsync(request.SportId, cancellationToken) ?? throw new NotFoundException();
        if (request.Active)
            sport.Activate();
        else
            sport.Deactivate();
        await session.CommitAsync(request.Active ? "sport.activate" : "sport.deactivate", "Sport", sport.Id.ToString(), null, cancellationToken);
    }
}

/// <summary>Every catalog admin command ends here: audit event, save, cache eviction.</summary>
public sealed class CatalogAdminSession(
    ICatalogUnitOfWork unitOfWork,
    IIntegrationEventPublisher events,
    ICacheInvalidator cache,
    ICurrentUserService currentUser,
    TimeProvider clock)
{
    public Guid AdminId => currentUser.RequireUserId();

    public DateTime Now => clock.GetUtcNow().UtcDateTime;

    public async Task CommitAsync(string action, string targetType, string targetId, string? reason, CancellationToken cancellationToken)
    {
        events.Enqueue(new AdminActionRecorded(AdminId, action, targetType, targetId, null, reason));
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        await cache.InvalidateTagsAsync([CatalogMapping.CacheTag], cancellationToken);
    }
}
