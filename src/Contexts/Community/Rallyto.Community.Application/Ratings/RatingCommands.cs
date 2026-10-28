using Rallyto.Community.Application.Abstractions;
using Rallyto.Community.Application.Matches;
using Rallyto.Community.Application.Players;
using Rallyto.Community.Domain.Matches;
using Rallyto.Community.Domain.Players;
using Rallyto.Community.Domain.Ratings;
using Rallyto.Contracts.Admin;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;

namespace Rallyto.Community.Application.Ratings;

public sealed record AnswerAttendanceCommand(Guid MatchId, AttendanceAnswer Answer, IReadOnlyList<Guid>? NoShowPlayerIds) : ICommand<MatchView>;

public sealed record SubmitRatingCommand(Guid MatchId, Guid RateeId, int Stars, IReadOnlyList<RatingTags>? Tags, LevelAccuracy? LevelAccuracy, string? PrivateNote)
    : ICommand<RatingReceiptView>;

public sealed record GetMyReputationQuery : IQuery<ReputationView>;

public sealed record AdminListRatingsQuery(Guid PlayerId) : IQuery<IReadOnlyList<AdminRatingView>>;

public sealed record AdminRemoveRatingCommand(Guid RatingId, string Reason) : ICommand;

internal sealed class AnswerAttendanceHandler(MatchWorkflow workflow) : ICommandHandler<AnswerAttendanceCommand, MatchView>
{
    public async Task<MatchView> Handle(AnswerAttendanceCommand request, CancellationToken cancellationToken)
    {
        var me = await workflow.MeAsync(cancellationToken);
        var (match, _) = await workflow.LoadVisibleAsync(me, request.MatchId, cancellationToken);
        match.AnswerAttendance(me.Id, request.Answer, request.NoShowPlayerIds ?? [], workflow.Now);
        return await workflow.SaveAndViewAsync(match, me.Id, cancellationToken);
    }
}

/// <summary>Stores a hidden rating, and reveals both when the counterpart has already rated (double-blind, design D7).</summary>
internal sealed class SubmitRatingHandler(MatchWorkflow workflow, IMatchRepository matches, IRatingRepository ratings, ICommunityUnitOfWork unitOfWork)
    : ICommandHandler<SubmitRatingCommand, RatingReceiptView>
{
    public async Task<RatingReceiptView> Handle(SubmitRatingCommand request, CancellationToken cancellationToken)
    {
        var me = await workflow.MeAsync(cancellationToken);
        var match = await matches.GetAsync(request.MatchId, cancellationToken);
        if (match?.ParticipantOf(me.Id) is null)
            throw MatchWorkflow.MatchNotFound();
        var now = workflow.Now;
        match.EnsureCanRate(me.Id, request.RateeId, now);
        if (await ratings.FindAsync(match.Id, me.Id, request.RateeId, cancellationToken) is not null)
            throw new ConflictException("ALREADY_RATED", "قبلاً به این بازیکن برای این بازی امتیاز داده‌اید.");

        var rating = Rating.Create(match.Id, match.SportId, me.Id, request.RateeId, request.Stars, request.Tags ?? [], request.LevelAccuracy,
            request.PrivateNote, now, match.RatingClosesAt!.Value);
        ratings.Add(rating);
        if (await ratings.FindAsync(match.Id, request.RateeId, me.Id, cancellationToken) is { } counterpart)
        {
            counterpart.Reveal(now);
            rating.Reveal(now);
        }

        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return new RatingReceiptView(rating.Id);
    }
}

internal sealed class GetMyReputationHandler(PlayerContext player, ReputationService reputation) : IQueryHandler<GetMyReputationQuery, ReputationView>
{
    public async Task<ReputationView> Handle(GetMyReputationQuery request, CancellationToken cancellationToken)
    {
        var me = await player.RequireProfileAsync(cancellationToken);
        return await reputation.ViewAsync(me.Id, me.Sports.Select(s => s.SportId), cancellationToken);
    }
}

internal sealed class AdminListRatingsHandler(IRatingRepository ratings, IPlayerProfileRepository profiles) : IQueryHandler<AdminListRatingsQuery, IReadOnlyList<AdminRatingView>>
{
    public async Task<IReadOnlyList<AdminRatingView>> Handle(AdminListRatingsQuery request, CancellationToken cancellationToken)
    {
        var list = await ratings.ListReceivedAsync(request.PlayerId, cancellationToken);
        var names = await profiles.DisplayNamesAsync(list.Select(r => r.RaterId).Distinct().ToList(), cancellationToken);
        return list.Select(r => new AdminRatingView(r.Id, r.MatchId, r.SportId, r.RaterId, names.GetValueOrDefault(r.RaterId, PlayerProfile.DeletedDisplayName),
                r.RateeId, r.Stars, Enum.GetValues<RatingTags>().Where(t => t != RatingTags.None && r.Tags.HasFlag(t)).ToList(), r.Level, r.PrivateNote,
                r.SubmittedAt, r.IsRevealed, r.RemovedAt, r.RemovalReason))
            .ToList();
    }
}

/// <summary>Removes an abusive rating; aggregates are computed on read, so it stops counting at once. Audited.</summary>
internal sealed class AdminRemoveRatingHandler(IRatingRepository ratings, ICurrentUserService currentUser, IIntegrationEventPublisher events, ICommunityUnitOfWork unitOfWork, TimeProvider clock)
    : ICommandHandler<AdminRemoveRatingCommand>
{
    public async Task Handle(AdminRemoveRatingCommand request, CancellationToken cancellationToken)
    {
        var rating = await ratings.GetAsync(request.RatingId, cancellationToken) ?? throw new NotFoundException("امتیاز پیدا نشد.", "RATING_NOT_FOUND");
        var adminId = currentUser.RequireUserId();
        rating.Remove(adminId, request.Reason, clock.GetUtcNow().UtcDateTime);
        events.Enqueue(new AdminActionRecorded(adminId, "rating.remove", "Rating", rating.Id.ToString(), rating.RateeId, rating.RemovalReason));
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
    }
}
