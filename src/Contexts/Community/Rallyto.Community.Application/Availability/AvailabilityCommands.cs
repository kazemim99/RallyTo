using Rallyto.Community.Application.Abstractions;
using Rallyto.Community.Application.Players;
using Rallyto.Community.Domain.Availabilities;
using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Core.Application.Localization;
using Rallyto.Core.Domain.Exceptions;
using Rallyto.Core.Domain.SharedKernel;
using AvailabilityAggregate = Rallyto.Community.Domain.Availabilities.Availability;

namespace Rallyto.Community.Application.Availability;

public sealed record AvailabilityInput(
    Guid SportId,
    IReadOnlyList<Guid> VenueIds,
    AvailabilityKind Kind,
    IReadOnlyList<IranianWeekdays>? Weekdays,
    string? Date,
    string StartTime,
    string EndTime,
    IReadOnlyList<PlayFormat> Formats,
    string? Note,
    string? ValidUntil);

public sealed record AvailabilityView(
    Guid Id,
    Guid SportId,
    string SportCode,
    IReadOnlyList<NamedRef> Venues,
    AvailabilityKind Kind,
    IReadOnlyList<IranianWeekdays> Weekdays,
    string? Date,
    string StartTime,
    string EndTime,
    IReadOnlyList<PlayFormat> Formats,
    string? Note,
    AvailabilityStatus Status,
    string? ValidUntil,
    bool NeedsReconfirmation,
    string? PausesOn);

public sealed record CreateAvailabilityCommand(AvailabilityInput Input) : ICommand<AvailabilityView>;

public sealed record UpdateAvailabilityCommand(Guid AvailabilityId, AvailabilityInput Input) : ICommand<AvailabilityView>;

public enum AvailabilityAction
{
    Pause,
    Resume,
    Confirm,
}

public sealed record ChangeAvailabilityCommand(Guid AvailabilityId, AvailabilityAction Action) : ICommand<AvailabilityView>;

public sealed record DeleteAvailabilityCommand(Guid AvailabilityId) : ICommand;

public sealed record ListMyAvailabilityQuery : IQuery<IReadOnlyList<AvailabilityView>>;

public sealed record ListPlayerAvailabilityQuery(Guid UserId) : IQuery<IReadOnlyList<AvailabilityView>>;

/// <summary>Validates windows against the player's sport profiles and the catalog, and builds views.</summary>
public sealed class AvailabilityAssembler(ICatalogReader catalog, TimeProvider clock)
{
    public DateTime Now => clock.GetUtcNow().UtcDateTime;

    public (DateOnly Today, int Minute) TehranNow()
    {
        var local = PersianFormat.ToTehran(Now);
        return (DateOnly.FromDateTime(local), local.Hour * 60 + local.Minute);
    }

    public async Task<(AvailabilitySchedule Schedule, int CityId, List<Guid> VenueIds, List<PlayFormat> Formats)> ValidateAsync(
        Domain.Players.PlayerProfile player, AvailabilityInput input, CancellationToken cancellationToken)
    {
        if (player.SportProfileFor(input.SportId) is null)
            throw new ValidationFailedException("NO_SPORT_PROFILE", "ابتدا این ورزش را به پروفایل خود اضافه کنید.");
        var sport = (await catalog.SportsAsync(cancellationToken)).FirstOrDefault(s => s.Id == input.SportId && s.IsActive)
            ?? throw new ValidationFailedException("UNKNOWN_SPORT", "ورزش انتخاب‌شده وجود ندارد.");
        var formats = (input.Formats ?? []).Distinct().ToList();
        if (formats.Any(f => !sport.Allows(f)))
            throw new BusinessRuleViolationException("FORMAT_NOT_ALLOWED", $"این قالب بازی برای {sport.NameFa} مجاز نیست.");

        var venueIds = (input.VenueIds ?? []).Distinct().ToList();
        if (venueIds.Count is 0 or > AvailabilityAggregate.MaxVenues)
            throw new BusinessRuleViolationException("INVALID_VENUE_COUNT", $"برای هر بازه ۱ تا {AvailabilityAggregate.MaxVenues} باشگاه انتخاب کنید.");
        var venues = await catalog.VenuesAsync(venueIds, cancellationToken);
        if (venueIds.Any(id => !venues.TryGetValue(id, out var v) || !v.IsActive))
            throw new ValidationFailedException("UNKNOWN_VENUE", "یکی از باشگاه‌های انتخاب‌شده در دسترس نیست.");
        if (venueIds.Any(id => !venues[id].Offers(input.SportId)))
            throw new BusinessRuleViolationException("VENUE_DOES_NOT_OFFER_SPORT", $"باشگاه انتخاب‌شده {sport.NameFa} ندارد.");
        var cities = venueIds.Select(id => venues[id].CityId).Distinct().ToList();
        if (cities.Count > 1)
            throw new BusinessRuleViolationException("VENUES_IN_DIFFERENT_CITIES", "باشگاه‌های یک بازه باید در یک شهر باشند.");

        var window = TimeWindow.Parse(input.StartTime, input.EndTime);
        var (today, minute) = TehranNow();
        AvailabilitySchedule schedule;
        if (input.Kind == AvailabilityKind.OneOff)
        {
            if (!PersianFormat.TryParseJalali(input.Date, out var date))
                throw new ValidationFailedException("INVALID_DATE", "تاریخ معتبر نیست.");
            schedule = AvailabilitySchedule.OneOff(date, window, today, minute);
        }
        else
        {
            DateOnly? validUntil = null;
            if (!string.IsNullOrWhiteSpace(input.ValidUntil))
            {
                if (!PersianFormat.TryParseJalali(input.ValidUntil, out var until))
                    throw new ValidationFailedException("INVALID_DATE", "تاریخ پایان معتبر نیست.");
                validUntil = until;
            }

            var days = (input.Weekdays ?? []).Aggregate(IranianWeekdays.None, (all, d) => all | d);
            schedule = AvailabilitySchedule.Recurring(days, window, validUntil, today);
        }

        return (schedule, cities[0], venueIds, formats);
    }

    public async Task<IReadOnlyList<AvailabilityView>> ToViewsAsync(IReadOnlyList<AvailabilityAggregate> windows, CancellationToken cancellationToken)
    {
        var sports = (await catalog.SportsAsync(cancellationToken)).ToDictionary(s => s.Id, s => s.Code);
        var venues = await catalog.VenuesAsync(windows.SelectMany(w => w.VenueIds).Distinct().ToList(), cancellationToken);
        return windows.Select(w => new AvailabilityView(
                w.Id,
                w.SportId,
                sports.GetValueOrDefault(w.SportId, string.Empty),
                w.VenueIds.Where(venues.ContainsKey).Select(id => new NamedRef(id, venues[id].Name)).ToList(),
                w.Kind,
                IranianWeek.Split(w.Weekdays).ToList(),
                w.Date is { } d ? PersianFormat.JalaliAscii(d) : null,
                TimeWindow.Format(w.StartMinute),
                TimeWindow.Format(w.EndMinute),
                w.Formats,
                w.Note,
                w.Status,
                w.ValidUntil is { } u ? PersianFormat.JalaliAscii(u) : null,
                w.Kind == AvailabilityKind.Recurring && w.Status == AvailabilityStatus.Active && Now - w.LastConfirmedAt >= Domain.Availabilities.Availability.ReminderAfter,
                w.Kind == AvailabilityKind.Recurring && w.Status == AvailabilityStatus.Active
                    ? PersianFormat.JalaliAscii(PersianFormat.TehranToday(w.LastConfirmedAt + Domain.Availabilities.Availability.ReconfirmAfter))
                    : null))
            .ToList();
    }

    public async Task<AvailabilityView> ToViewAsync(AvailabilityAggregate window, CancellationToken cancellationToken) =>
        (await ToViewsAsync([window], cancellationToken))[0];
}

internal sealed class CreateAvailabilityHandler(
    PlayerContext player,
    IAvailabilityRepository windows,
    AvailabilityAssembler assembler,
    ICommunityUnitOfWork unitOfWork) : ICommandHandler<CreateAvailabilityCommand, AvailabilityView>
{
    public async Task<AvailabilityView> Handle(CreateAvailabilityCommand request, CancellationToken cancellationToken)
    {
        var profile = await player.RequireProfileAsync(cancellationToken);
        var (schedule, cityId, venueIds, formats) = await assembler.ValidateAsync(profile, request.Input, cancellationToken);

        var existing = await windows.ListByPlayerAsync(profile.Id, cancellationToken);
        if (existing.Count(w => w.Status == AvailabilityStatus.Active) >= AvailabilityAggregate.MaxActivePerPlayer)
            throw new ConflictException("TOO_MANY_WINDOWS", $"حداکثر {AvailabilityAggregate.MaxActivePerPlayer} بازهٔ فعال می‌توانید داشته باشید.");
        if (existing.FirstOrDefault(w => w.DuplicatesWith(request.Input.SportId, venueIds, schedule)) is { } duplicate)
            throw new ConflictException("OVERLAPPING_WINDOW", $"این بازه با یکی از بازه‌های فعلی شما هم‌پوشانی دارد ({duplicate.Id}). همان را ویرایش کنید.");

        var window = AvailabilityAggregate.Create(profile.Id, request.Input.SportId, cityId, schedule, venueIds, formats, request.Input.Note, assembler.Now);
        windows.Add(window);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return await assembler.ToViewAsync(window, cancellationToken);
    }
}

internal sealed class UpdateAvailabilityHandler(
    PlayerContext player,
    IAvailabilityRepository windows,
    AvailabilityAssembler assembler,
    ICommunityUnitOfWork unitOfWork) : ICommandHandler<UpdateAvailabilityCommand, AvailabilityView>
{
    public async Task<AvailabilityView> Handle(UpdateAvailabilityCommand request, CancellationToken cancellationToken)
    {
        var profile = await player.RequireProfileAsync(cancellationToken);
        var window = await windows.GetAsync(request.AvailabilityId, cancellationToken);
        if (window is null || window.PlayerId != profile.Id)
            throw new NotFoundException("بازه پیدا نشد.");
        var (schedule, cityId, venueIds, formats) = await assembler.ValidateAsync(profile, request.Input with { SportId = window.SportId }, cancellationToken);

        var others = (await windows.ListByPlayerAsync(profile.Id, cancellationToken)).Where(w => w.Id != window.Id);
        if (others.FirstOrDefault(w => w.DuplicatesWith(window.SportId, venueIds, schedule)) is { } duplicate)
            throw new ConflictException("OVERLAPPING_WINDOW", $"این بازه با یکی از بازه‌های فعلی شما هم‌پوشانی دارد ({duplicate.Id}).");

        window.Update(cityId, schedule, venueIds, formats, request.Input.Note, assembler.Now);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return await assembler.ToViewAsync(window, cancellationToken);
    }
}

internal sealed class ChangeAvailabilityHandler(
    PlayerContext player,
    IAvailabilityRepository windows,
    AvailabilityAssembler assembler,
    ICommunityUnitOfWork unitOfWork) : ICommandHandler<ChangeAvailabilityCommand, AvailabilityView>
{
    public async Task<AvailabilityView> Handle(ChangeAvailabilityCommand request, CancellationToken cancellationToken)
    {
        var profile = await player.RequireProfileAsync(cancellationToken);
        var window = await windows.GetAsync(request.AvailabilityId, cancellationToken);
        if (window is null || window.PlayerId != profile.Id)
            throw new NotFoundException("بازه پیدا نشد.");

        switch (request.Action)
        {
            case AvailabilityAction.Pause:
                window.Pause();
                break;
            case AvailabilityAction.Resume:
                var active = (await windows.ListByPlayerAsync(profile.Id, cancellationToken)).Count(w => w.Status == AvailabilityStatus.Active && w.Id != window.Id);
                if (window.Status != AvailabilityStatus.Active && active >= AvailabilityAggregate.MaxActivePerPlayer)
                    throw new ConflictException("TOO_MANY_WINDOWS", $"حداکثر {AvailabilityAggregate.MaxActivePerPlayer} بازهٔ فعال می‌توانید داشته باشید.");
                window.Resume(assembler.Now);
                break;
            default:
                window.Confirm(assembler.Now);
                break;
        }

        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return await assembler.ToViewAsync(window, cancellationToken);
    }
}

internal sealed class DeleteAvailabilityHandler(PlayerContext player, IAvailabilityRepository windows, ICommunityUnitOfWork unitOfWork)
    : ICommandHandler<DeleteAvailabilityCommand>
{
    public async Task Handle(DeleteAvailabilityCommand request, CancellationToken cancellationToken)
    {
        var profile = await player.RequireProfileAsync(cancellationToken);
        var window = await windows.GetAsync(request.AvailabilityId, cancellationToken);
        if (window is null || window.PlayerId != profile.Id)
            throw new NotFoundException("بازه پیدا نشد.");
        windows.Remove(window);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
    }
}

internal sealed class ListMyAvailabilityHandler(PlayerContext player, IAvailabilityRepository windows, AvailabilityAssembler assembler)
    : IQueryHandler<ListMyAvailabilityQuery, IReadOnlyList<AvailabilityView>>
{
    public async Task<IReadOnlyList<AvailabilityView>> Handle(ListMyAvailabilityQuery request, CancellationToken cancellationToken)
    {
        var profile = await player.RequireProfileAsync(cancellationToken);
        return await assembler.ToViewsAsync(await windows.ListByPlayerAsync(profile.Id, cancellationToken), cancellationToken);
    }
}

/// <summary>Another player's active windows, only for viewers who may see that player (spec availability).</summary>
internal sealed class ListPlayerAvailabilityHandler(
    PlayerContext player,
    IPlayerProfileRepository profiles,
    VisibilityService visibility,
    IAvailabilityRepository windows,
    AvailabilityAssembler assembler) : IQueryHandler<ListPlayerAvailabilityQuery, IReadOnlyList<AvailabilityView>>
{
    public async Task<IReadOnlyList<AvailabilityView>> Handle(ListPlayerAvailabilityQuery request, CancellationToken cancellationToken)
    {
        var viewer = await player.RequireProfileAsync(cancellationToken);
        var subject = await profiles.GetAsync(request.UserId, cancellationToken);
        if (subject is null || !await visibility.CanSeeAsync(viewer, subject, cancellationToken))
            throw VisibilityService.PlayerNotFound();
        var active = (await windows.ListByPlayerAsync(subject.Id, cancellationToken)).Where(w => w.Status == AvailabilityStatus.Active).ToList();
        return await assembler.ToViewsAsync(active, cancellationToken);
    }
}
