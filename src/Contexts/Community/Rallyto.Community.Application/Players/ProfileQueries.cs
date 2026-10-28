using Rallyto.Community.Application.Abstractions;
using Rallyto.Community.Domain.Players;
using Rallyto.Core.Application.Cqrs;

namespace Rallyto.Community.Application.Players;

public sealed record GetMyProfileQuery : IQuery<MyProfileView>;

public sealed record GetPlayerProfileQuery(Guid UserId) : IQuery<PlayerProfileView>;

public sealed record AdminGetPlayerQuery(Guid UserId) : IQuery<MyProfileView>;

public sealed record ListBlocksQuery : IQuery<IReadOnlyList<BlockedPlayerView>>;

public sealed record BlockPlayerCommand(Guid UserId) : ICommand;

public sealed record UnblockPlayerCommand(Guid UserId) : ICommand;

internal sealed class GetMyProfileHandler(PlayerContext player, ProfileAssembler assembler) : IQueryHandler<GetMyProfileQuery, MyProfileView>
{
    public async Task<MyProfileView> Handle(GetMyProfileQuery request, CancellationToken cancellationToken) =>
        await assembler.OwnerViewAsync(await player.RequireProfileAsync(cancellationToken), cancellationToken);
}

/// <summary>Another player's profile, through the visibility rule; hidden and blocked look exactly like missing.</summary>
internal sealed class GetPlayerProfileHandler(
    PlayerContext player,
    IPlayerProfileRepository profiles,
    VisibilityService visibility,
    ProfileAssembler assembler) : IQueryHandler<GetPlayerProfileQuery, PlayerProfileView>
{
    public async Task<PlayerProfileView> Handle(GetPlayerProfileQuery request, CancellationToken cancellationToken)
    {
        var viewer = await player.RequireProfileAsync(cancellationToken);
        var subject = await profiles.GetAsync(request.UserId, cancellationToken);
        if (subject is null || !await visibility.CanSeeAsync(viewer, subject, cancellationToken))
            throw VisibilityService.PlayerNotFound();
        return await assembler.PublicViewAsync(subject, cancellationToken);
    }
}

internal sealed class AdminGetPlayerHandler(IPlayerProfileRepository profiles, ProfileAssembler assembler) : IQueryHandler<AdminGetPlayerQuery, MyProfileView>
{
    public async Task<MyProfileView> Handle(AdminGetPlayerQuery request, CancellationToken cancellationToken) =>
        await assembler.OwnerViewAsync(await profiles.GetAsync(request.UserId, cancellationToken) ?? throw VisibilityService.PlayerNotFound(), cancellationToken);
}

internal sealed class ListBlocksHandler(PlayerContext player, IBlockRepository blocks, IPlayerProfileRepository profiles)
    : IQueryHandler<ListBlocksQuery, IReadOnlyList<BlockedPlayerView>>
{
    public async Task<IReadOnlyList<BlockedPlayerView>> Handle(ListBlocksQuery request, CancellationToken cancellationToken)
    {
        await player.RequireProfileAsync(cancellationToken);
        var list = await blocks.ListByBlockerAsync(player.UserId, cancellationToken);
        var names = await profiles.DisplayNamesAsync(list.Select(b => b.BlockedId).ToList(), cancellationToken);
        return list.Select(b => new BlockedPlayerView(b.BlockedId, names.GetValueOrDefault(b.BlockedId, PlayerProfile.DeletedDisplayName), b.BlockedAt)).ToList();
    }
}

internal sealed class BlockPlayerHandler(PlayerContext player, IBlockRepository blocks, IPlayerProfileRepository profiles, ICommunityUnitOfWork unitOfWork, TimeProvider clock)
    : ICommandHandler<BlockPlayerCommand>
{
    public async Task Handle(BlockPlayerCommand request, CancellationToken cancellationToken)
    {
        await player.RequireProfileAsync(cancellationToken);
        var block = Block.Create(player.UserId, request.UserId, clock.GetUtcNow().UtcDateTime);
        if (!await profiles.ExistsAsync(request.UserId, cancellationToken))
            throw VisibilityService.PlayerNotFound();
        if (await blocks.GetAsync(player.UserId, request.UserId, cancellationToken) is not null)
            return;
        blocks.Add(block);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
    }
}

internal sealed class UnblockPlayerHandler(PlayerContext player, IBlockRepository blocks, ICommunityUnitOfWork unitOfWork) : ICommandHandler<UnblockPlayerCommand>
{
    public async Task Handle(UnblockPlayerCommand request, CancellationToken cancellationToken)
    {
        await player.RequireProfileAsync(cancellationToken);
        if (await blocks.GetAsync(player.UserId, request.UserId, cancellationToken) is { } block)
        {
            blocks.Remove(block);
            await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        }
    }
}
