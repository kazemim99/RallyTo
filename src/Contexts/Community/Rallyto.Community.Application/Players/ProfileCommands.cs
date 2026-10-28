using Rallyto.Community.Application.Abstractions;
using Rallyto.Community.Domain.Players;
using Rallyto.Contracts.Admin;
using Rallyto.Contracts.Community;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Core.Application.Localization;

namespace Rallyto.Community.Application.Players;

public sealed record CreateProfileCommand(string DisplayName, Gender Gender, string BirthDate, int CityId, string? Bio, IReadOnlyList<SportProfileInput> Sports)
    : ICommand<MyProfileView>;

public sealed record UpdateProfileCommand(string DisplayName, Gender? Gender, int CityId, string? Bio) : ICommand<MyProfileView>;

public sealed record SetSportProfileCommand(SportProfileInput Sport) : ICommand<MyProfileView>;

public sealed record RemoveSportProfileCommand(Guid SportId) : ICommand<MyProfileView>;

public sealed record SetHomeVenuesCommand(IReadOnlyList<Guid> VenueIds) : ICommand<MyProfileView>;

public sealed record SetVisibilityCommand(ProfileVisibility Visibility) : ICommand<MyProfileView>;

public sealed record UploadPhotoCommand(Stream Content, long Length, string? ContentType) : ICommand<MyProfileView>;

public sealed record RemovePhotoCommand : ICommand<MyProfileView>;

public sealed record CorrectGenderCommand(Guid UserId, Gender Gender, string Reason) : ICommand;

public sealed record AdminRemovePhotoCommand(Guid UserId, string Reason) : ICommand;

internal sealed class CreateProfileHandler(
    PlayerContext player,
    IPlayerProfileRepository profiles,
    ProfileAssembler assembler,
    ICommunityUnitOfWork unitOfWork,
    TimeProvider clock) : ICommandHandler<CreateProfileCommand, MyProfileView>
{
    public async Task<MyProfileView> Handle(CreateProfileCommand request, CancellationToken cancellationToken)
    {
        if (await profiles.ExistsAsync(player.UserId, cancellationToken))
            throw new ConflictException("PROFILE_EXISTS", "پروفایل شما قبلاً ساخته شده است.");
        if (!PersianFormat.TryParseJalali(request.BirthDate, out var birthDate))
            throw new ValidationFailedException("INVALID_BIRTH_DATE", "تاریخ تولد معتبر نیست.");

        await assembler.EnsureCityAsync(request.CityId, cancellationToken);
        var sports = new List<SportProfile>();
        foreach (var input in request.Sports ?? [])
            sports.Add(await assembler.ToSportProfileAsync(input, cancellationToken));

        var profile = PlayerProfile.Create(player.UserId, request.DisplayName, request.Gender, birthDate, assembler.TehranToday(),
            request.CityId, request.Bio, sports, clock.GetUtcNow().UtcDateTime);
        profiles.Add(profile);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return await assembler.OwnerViewAsync(profile, cancellationToken);
    }
}

/// <summary>Tells Identity the account now has a profile (design D3).</summary>
internal sealed class ProfileCreatedHandler(IIntegrationEventPublisher events) : IDomainEventHandler<Domain.Players.ProfileCreated>
{
    public Task HandleAsync(Domain.Players.ProfileCreated domainEvent, CancellationToken cancellationToken)
    {
        events.Enqueue(new Contracts.Community.ProfileCreated(domainEvent.UserId));
        return Task.CompletedTask;
    }
}

internal sealed class UpdateProfileHandler(PlayerContext player, ProfileAssembler assembler, ICommunityUnitOfWork unitOfWork)
    : ICommandHandler<UpdateProfileCommand, MyProfileView>
{
    public async Task<MyProfileView> Handle(UpdateProfileCommand request, CancellationToken cancellationToken)
    {
        var profile = await player.RequireProfileAsync(cancellationToken);
        if (request.Gender is { } gender && gender != profile.Gender)
            throw new ValidationFailedException("GENDER_LOCKED", "جنسیت پس از ثبت‌نام قابل تغییر نیست. برای اصلاح با پشتیبانی تماس بگیرید.");
        await assembler.EnsureCityAsync(request.CityId, cancellationToken);
        profile.UpdateDetails(request.DisplayName, request.CityId, request.Bio);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return await assembler.OwnerViewAsync(profile, cancellationToken);
    }
}

internal sealed class SetSportProfileHandler(PlayerContext player, ProfileAssembler assembler, ICommunityUnitOfWork unitOfWork)
    : ICommandHandler<SetSportProfileCommand, MyProfileView>
{
    public async Task<MyProfileView> Handle(SetSportProfileCommand request, CancellationToken cancellationToken)
    {
        var profile = await player.RequireProfileAsync(cancellationToken);
        profile.SetSportProfile(await assembler.ToSportProfileAsync(request.Sport, cancellationToken));
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return await assembler.OwnerViewAsync(profile, cancellationToken);
    }
}

internal sealed class RemoveSportProfileHandler(PlayerContext player, ProfileAssembler assembler, IAvailabilityRepository windows, Matches.IMatchRepository matches, TimeProvider clock, ICommunityUnitOfWork unitOfWork)
    : ICommandHandler<RemoveSportProfileCommand, MyProfileView>
{
    public async Task<MyProfileView> Handle(RemoveSportProfileCommand request, CancellationToken cancellationToken)
    {
        var profile = await player.RequireProfileAsync(cancellationToken);
        if (await matches.HasFutureMatchInSportAsync(profile.Id, request.SportId, clock.GetUtcNow().UtcDateTime, cancellationToken))
            throw new ConflictException("SPORT_HAS_FUTURE_MATCHES", "در این ورزش بازی پیش رو دارید؛ پس از آن یا با لغو بازی می‌توانید آن را حذف کنید.");
        profile.RemoveSportProfile(request.SportId);
        // Removing a sport deactivates the player's availability in it (spec player-profile).
        foreach (var window in await windows.ListByPlayerAndSportAsync(profile.Id, request.SportId, cancellationToken))
            window.Pause();
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return await assembler.OwnerViewAsync(profile, cancellationToken);
    }
}

internal sealed class SetHomeVenuesHandler(PlayerContext player, ProfileAssembler assembler, ICommunityUnitOfWork unitOfWork)
    : ICommandHandler<SetHomeVenuesCommand, MyProfileView>
{
    public async Task<MyProfileView> Handle(SetHomeVenuesCommand request, CancellationToken cancellationToken)
    {
        var profile = await player.RequireProfileAsync(cancellationToken);
        var ids = (request.VenueIds ?? []).Distinct().ToList();
        profile.SetHomeVenues(ids);
        await assembler.EnsureActiveVenuesAsync(ids, cancellationToken);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return await assembler.OwnerViewAsync(profile, cancellationToken);
    }
}

internal sealed class SetVisibilityHandler(PlayerContext player, ProfileAssembler assembler, ICommunityUnitOfWork unitOfWork)
    : ICommandHandler<SetVisibilityCommand, MyProfileView>
{
    public async Task<MyProfileView> Handle(SetVisibilityCommand request, CancellationToken cancellationToken)
    {
        var profile = await player.RequireProfileAsync(cancellationToken);
        profile.SetVisibility(request.Visibility);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return await assembler.OwnerViewAsync(profile, cancellationToken);
    }
}

internal sealed class UploadPhotoHandler(PlayerContext player, IAvatarProcessor avatars, IFileStorage storage, ProfileAssembler assembler, ICommunityUnitOfWork unitOfWork)
    : ICommandHandler<UploadPhotoCommand, MyProfileView>
{
    public async Task<MyProfileView> Handle(UploadPhotoCommand request, CancellationToken cancellationToken)
    {
        var profile = await player.RequireProfileAsync(cancellationToken);
        var path = await avatars.ProcessAndStoreAsync(request.Content, request.Length, request.ContentType, cancellationToken);
        var previous = profile.PhotoKey;
        profile.SetPhoto(path);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        if (previous is not null)
            await storage.DeleteAsync(previous, cancellationToken);
        return await assembler.OwnerViewAsync(profile, cancellationToken);
    }
}

internal sealed class RemovePhotoHandler(PlayerContext player, IFileStorage storage, ProfileAssembler assembler, ICommunityUnitOfWork unitOfWork)
    : ICommandHandler<RemovePhotoCommand, MyProfileView>
{
    public async Task<MyProfileView> Handle(RemovePhotoCommand request, CancellationToken cancellationToken)
    {
        var profile = await player.RequireProfileAsync(cancellationToken);
        var previous = profile.PhotoKey;
        profile.RemovePhoto();
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        if (previous is not null)
            await storage.DeleteAsync(previous, cancellationToken);
        return await assembler.OwnerViewAsync(profile, cancellationToken);
    }
}

/// <summary>Admin correction of a player's gender: audited and announced to the player (spec player-profile).</summary>
internal sealed class CorrectGenderHandler(
    IPlayerProfileRepository profiles,
    ICurrentUserService currentUser,
    IIntegrationEventPublisher events,
    ICommunityUnitOfWork unitOfWork) : ICommandHandler<CorrectGenderCommand>
{
    public async Task Handle(CorrectGenderCommand request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Reason))
            throw new ValidationFailedException("REASON_REQUIRED", "دلیل را بنویسید.");
        var profile = await profiles.GetAsync(request.UserId, cancellationToken) ?? throw VisibilityService.PlayerNotFound();
        profile.CorrectGender(request.Gender);
        events.Enqueue(new GenderCorrected(profile.Id, request.Reason));
        events.Enqueue(new AdminActionRecorded(currentUser.RequireUserId(), "player.correct-gender", "Player", profile.Id.ToString(), profile.Id, request.Reason));
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
    }
}

internal sealed class AdminRemovePhotoHandler(
    IPlayerProfileRepository profiles,
    IFileStorage storage,
    ICurrentUserService currentUser,
    IIntegrationEventPublisher events,
    ICommunityUnitOfWork unitOfWork) : ICommandHandler<AdminRemovePhotoCommand>
{
    public async Task Handle(AdminRemovePhotoCommand request, CancellationToken cancellationToken)
    {
        var profile = await profiles.GetAsync(request.UserId, cancellationToken) ?? throw VisibilityService.PlayerNotFound();
        var previous = profile.PhotoKey;
        profile.RemovePhoto();
        events.Enqueue(new AdminActionRecorded(currentUser.RequireUserId(), "player.remove-photo", "Player", profile.Id.ToString(), profile.Id, request.Reason));
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        if (previous is not null)
            await storage.DeleteAsync(previous, cancellationToken);
    }
}
