using Rallyto.Community.Application.Abstractions;
using Rallyto.Community.Application.Players;
using Rallyto.Community.Domain.Matches;
using Rallyto.Community.Domain.Players;
using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Community.Application.Matches;

public sealed record CreatePostCommand(MatchInput Input) : ICommand<MatchView>;

public sealed record CreateInvitationCommand(InvitationInput Input) : ICommand<MatchView>;

public sealed record EditMatchCommand(Guid MatchId, MatchInput Input) : ICommand<MatchView>;

public enum MatchAction
{
    Withdraw,
    AcceptInvitation,
    DeclineInvitation,
    ConfirmEarly,
    Leave,
    RegenerateShareToken,
}

public sealed record MatchActionCommand(Guid MatchId, MatchAction Action) : ICommand<MatchView>;

public sealed record JoinMatchCommand(Guid MatchId, string? Message) : ICommand<MatchView>;

public sealed record AnswerJoinRequestCommand(Guid MatchId, Guid PlayerId, bool Accept) : ICommand<MatchView>;

public sealed record InvitePlayersCommand(Guid MatchId, IReadOnlyList<Guid> PlayerIds) : ICommand<MatchView>;

public sealed record RemoveParticipantCommand(Guid MatchId, Guid PlayerId) : ICommand<MatchView>;

public sealed record CancelMatchCommand(Guid MatchId, string? Reason) : ICommand<MatchView>;

/// <summary>Shared steps of match commands: load with access check, conflicts, limits, save.</summary>
public sealed class MatchWorkflow(
    PlayerContext player,
    IMatchRepository matches,
    IPlayerProfileRepository profiles,
    IBlockRepository blocks,
    VisibilityService visibility,
    MatchAssembler assembler,
    ICommunityUnitOfWork unitOfWork)
{
    public const int MaxOpenPosts = 5;
    public const int MaxPendingRequests = 10;

    public DateTime Now => assembler.Now;

    public Task<PlayerProfile> MeAsync(CancellationToken cancellationToken) => player.RequireProfileAsync(cancellationToken);

    public static NotFoundException MatchNotFound() => new("بازی پیدا نشد.", "MATCH_NOT_FOUND");

    /// <summary>Loads a match the player may see; otherwise "not found", so private or hidden matches are not revealed.</summary>
    public async Task<(Match Match, bool Involved)> LoadVisibleAsync(PlayerProfile me, Guid matchId, CancellationToken cancellationToken)
    {
        var match = await matches.GetAsync(matchId, cancellationToken) ?? throw MatchNotFound();
        var (canSee, involved) = await assembler.AccessAsync(me, match, visibility, cancellationToken);
        return canSee ? (match, involved) : throw MatchNotFound();
    }

    public async Task EnsureNoConflictAsync(Guid playerId, Match match, CancellationToken cancellationToken)
    {
        if (await matches.HasAcceptedOverlapAsync(playerId, match.StartsAt, match.EndsAt, match.Id, cancellationToken))
            throw new ConflictException("SCHEDULE_CONFLICT", "در این زمان بازی دیگری دارید.");
    }

    public async Task<PlayerProfile> RequireVisiblePlayerAsync(PlayerProfile me, Guid playerId, CancellationToken cancellationToken)
    {
        var other = await profiles.GetAsync(playerId, cancellationToken);
        return other is not null && await visibility.CanSeeAsync(me, other, cancellationToken) ? other : throw VisibilityService.PlayerNotFound();
    }

    /// <summary>A block between the player and anyone still in the game exempts leaving from a late cancellation (spec match-lifecycle).</summary>
    public async Task<bool> BlockedWithAnyoneAsync(Guid playerId, Match match, CancellationToken cancellationToken)
    {
        foreach (var other in match.PlayerIds().Where(id => id != playerId))
        {
            if (await blocks.IsBlockedEitherWayAsync(playerId, other, cancellationToken))
                return true;
        }

        return false;
    }

    public async Task<int> CountPendingRequestsAsync(Guid playerId, CancellationToken cancellationToken) =>
        await matches.CountPendingRequestsAsync(playerId, Now, cancellationToken);

    public async Task<int> CountOpenPostsAsync(Guid hostId, CancellationToken cancellationToken) =>
        await matches.CountOpenHostedAsync(hostId, Now, cancellationToken);

    public void RecordLate(Guid playerId, Match match) => matches.AddLateCancellation(LateCancellation.Record(playerId, match.Id, Now));

    public async Task<MatchView> SaveAndViewAsync(Match match, Guid viewerId, CancellationToken cancellationToken)
    {
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return await assembler.ViewAsync(match, viewerId, involved: true, cancellationToken);
    }
}

internal sealed class CreatePostHandler(MatchWorkflow workflow, MatchAssembler assembler, IMatchRepository matches) : ICommandHandler<CreatePostCommand, MatchView>
{
    public async Task<MatchView> Handle(CreatePostCommand request, CancellationToken cancellationToken)
    {
        var me = await workflow.MeAsync(cancellationToken);
        var input = request.Input;
        var (slot, _) = await assembler.ValidateSlotAsync(input.SportId, input.VenueId, input.Format, input.Date, input.StartTime, input.DurationMinutes, cancellationToken);
        var own = me.SportProfileFor(slot.SportId)?.Level
            ?? throw new ValidationFailedException("NO_SPORT_PROFILE", "ابتدا این ورزش را به پروفایل خود اضافه کنید.");
        if (await workflow.CountOpenPostsAsync(me.Id, cancellationToken) >= MatchWorkflow.MaxOpenPosts)
            throw new ConflictException("TOO_MANY_OPEN_POSTS", $"حداکثر {MatchWorkflow.MaxOpenPosts} آگهی باز می‌توانید داشته باشید.");

        // A same-gender-only host can only look for partners of her own gender (spec play-posts).
        var gender = me.Visibility == ProfileVisibility.SameGender ? (PartnerGender)(int)me.Gender : input.PartnerGender;
        var terms = MatchTerms.Create(input.MinLevel ?? LevelTiers.Clamp((int)own - 1), input.MaxLevel ?? LevelTiers.Clamp((int)own + 1),
            gender, input.CourtBooked, input.CostNote, input.Description);
        var match = Match.CreatePost(me.Id, slot, terms, input.PlayersBrought, workflow.Now);
        matches.Add(match);
        return await workflow.SaveAndViewAsync(match, me.Id, cancellationToken);
    }
}

internal sealed class CreateInvitationHandler(MatchWorkflow workflow, MatchAssembler assembler, IMatchRepository matches) : ICommandHandler<CreateInvitationCommand, MatchView>
{
    public async Task<MatchView> Handle(CreateInvitationCommand request, CancellationToken cancellationToken)
    {
        var me = await workflow.MeAsync(cancellationToken);
        var input = request.Input;
        var (slot, _) = await assembler.ValidateSlotAsync(input.SportId, input.VenueId, input.Format, input.Date, input.StartTime, input.DurationMinutes, cancellationToken);
        var own = me.SportProfileFor(slot.SportId)?.Level
            ?? throw new ValidationFailedException("NO_SPORT_PROFILE", "ابتدا این ورزش را به پروفایل خود اضافه کنید.");
        var invitees = (input.Invitees ?? []).Distinct().ToList();
        foreach (var id in invitees)
        {
            var invitee = await workflow.RequireVisiblePlayerAsync(me, id, cancellationToken);
            if (invitee.SportProfileFor(slot.SportId) is null)
                throw new ValidationFailedException("INVITEE_DOES_NOT_PLAY", $"{invitee.DisplayName} این ورزش را بازی نمی‌کند.");
        }

        var terms = MatchTerms.Create(LevelTiers.Clamp((int)own - 1), LevelTiers.Clamp((int)own + 1), PartnerGender.Any, false, null, null);
        var match = Match.CreateInvitation(me.Id, slot, terms, input.PlayersBrought, invitees, input.Message, workflow.Now);
        matches.Add(match);
        return await workflow.SaveAndViewAsync(match, me.Id, cancellationToken);
    }
}

internal sealed class EditMatchHandler(MatchWorkflow workflow, MatchAssembler assembler) : ICommandHandler<EditMatchCommand, MatchView>
{
    public async Task<MatchView> Handle(EditMatchCommand request, CancellationToken cancellationToken)
    {
        var me = await workflow.MeAsync(cancellationToken);
        var (match, _) = await workflow.LoadVisibleAsync(me, request.MatchId, cancellationToken);
        var input = request.Input;
        var gender = me.Visibility == ProfileVisibility.SameGender ? (PartnerGender)(int)me.Gender : input.PartnerGender;
        match.EditTerms(me.Id, MatchTerms.Create(input.MinLevel ?? match.MinLevel, input.MaxLevel ?? match.MaxLevel, gender, input.CourtBooked, input.CostNote, input.Description), workflow.Now);
        var (slot, _) = await assembler.ValidateSlotAsync(input.SportId, input.VenueId, input.Format, input.Date, input.StartTime, input.DurationMinutes ?? match.DurationMinutes, cancellationToken);
        match.EditSlot(me.Id, slot, input.PlayersBrought, workflow.Now);
        return await workflow.SaveAndViewAsync(match, me.Id, cancellationToken);
    }
}

internal sealed class JoinMatchHandler(MatchWorkflow workflow) : ICommandHandler<JoinMatchCommand, MatchView>
{
    public async Task<MatchView> Handle(JoinMatchCommand request, CancellationToken cancellationToken)
    {
        var me = await workflow.MeAsync(cancellationToken);
        var (match, _) = await workflow.LoadVisibleAsync(me, request.MatchId, cancellationToken);
        var level = me.SportProfileFor(match.SportId)?.Level
            ?? throw new ValidationFailedException("NO_SPORT_PROFILE", "ابتدا این ورزش را به پروفایل خود اضافه کنید.");
        if (match.Visibility == MatchVisibility.Public && !MatchAssembler.AcceptsGender(match, me.Gender))
            throw MatchWorkflow.MatchNotFound();
        if (await workflow.CountPendingRequestsAsync(me.Id, cancellationToken) >= MatchWorkflow.MaxPendingRequests)
            throw new ConflictException("TOO_MANY_PENDING_REQUESTS", $"حداکثر {MatchWorkflow.MaxPendingRequests} درخواست در انتظار می‌توانید داشته باشید.");
        await workflow.EnsureNoConflictAsync(me.Id, match, cancellationToken);

        match.RequestToJoin(me.Id, request.Message, !LevelTiers.IsWithin(level, match.MinLevel, match.MaxLevel), workflow.Now);
        return await workflow.SaveAndViewAsync(match, me.Id, cancellationToken);
    }
}

internal sealed class AnswerJoinRequestHandler(MatchWorkflow workflow) : ICommandHandler<AnswerJoinRequestCommand, MatchView>
{
    public async Task<MatchView> Handle(AnswerJoinRequestCommand request, CancellationToken cancellationToken)
    {
        var me = await workflow.MeAsync(cancellationToken);
        var (match, _) = await workflow.LoadVisibleAsync(me, request.MatchId, cancellationToken);
        if (request.Accept)
        {
            await workflow.EnsureNoConflictAsync(request.PlayerId, match, cancellationToken);
            match.AcceptRequest(me.Id, request.PlayerId, workflow.Now);
        }
        else
        {
            match.DeclineRequest(me.Id, request.PlayerId, workflow.Now);
        }

        return await workflow.SaveAndViewAsync(match, me.Id, cancellationToken);
    }
}

internal sealed class InvitePlayersHandler(MatchWorkflow workflow) : ICommandHandler<InvitePlayersCommand, MatchView>
{
    public async Task<MatchView> Handle(InvitePlayersCommand request, CancellationToken cancellationToken)
    {
        var me = await workflow.MeAsync(cancellationToken);
        var (match, _) = await workflow.LoadVisibleAsync(me, request.MatchId, cancellationToken);
        foreach (var id in request.PlayerIds ?? [])
        {
            var invitee = await workflow.RequireVisiblePlayerAsync(me, id, cancellationToken);
            if (invitee.SportProfileFor(match.SportId) is null)
                throw new ValidationFailedException("INVITEE_DOES_NOT_PLAY", $"{invitee.DisplayName} این ورزش را بازی نمی‌کند.");
        }

        match.Invite(me.Id, request.PlayerIds ?? [], null, workflow.Now);
        return await workflow.SaveAndViewAsync(match, me.Id, cancellationToken);
    }
}

internal sealed class MatchActionHandler(MatchWorkflow workflow) : ICommandHandler<MatchActionCommand, MatchView>
{
    public async Task<MatchView> Handle(MatchActionCommand request, CancellationToken cancellationToken)
    {
        var me = await workflow.MeAsync(cancellationToken);
        var (match, _) = await workflow.LoadVisibleAsync(me, request.MatchId, cancellationToken);
        var now = workflow.Now;
        switch (request.Action)
        {
            case MatchAction.Withdraw:
                match.WithdrawRequest(me.Id, now);
                break;
            case MatchAction.AcceptInvitation:
                await workflow.EnsureNoConflictAsync(me.Id, match, cancellationToken);
                match.AnswerInvitation(me.Id, accept: true, now);
                break;
            case MatchAction.DeclineInvitation:
                match.AnswerInvitation(me.Id, accept: false, now);
                break;
            case MatchAction.ConfirmEarly:
                match.ConfirmEarly(me.Id, now);
                break;
            case MatchAction.Leave:
                if (match.Leave(me.Id, await workflow.BlockedWithAnyoneAsync(me.Id, match, cancellationToken), now))
                    workflow.RecordLate(me.Id, match);
                break;
            case MatchAction.RegenerateShareToken:
                match.RegenerateShareToken(me.Id);
                break;
        }

        return await workflow.SaveAndViewAsync(match, me.Id, cancellationToken);
    }
}

internal sealed class RemoveParticipantHandler(MatchWorkflow workflow) : ICommandHandler<RemoveParticipantCommand, MatchView>
{
    public async Task<MatchView> Handle(RemoveParticipantCommand request, CancellationToken cancellationToken)
    {
        var me = await workflow.MeAsync(cancellationToken);
        var (match, _) = await workflow.LoadVisibleAsync(me, request.MatchId, cancellationToken);
        match.RemoveParticipant(me.Id, request.PlayerId, workflow.Now);
        return await workflow.SaveAndViewAsync(match, me.Id, cancellationToken);
    }
}

internal sealed class CancelMatchHandler(MatchWorkflow workflow) : ICommandHandler<CancelMatchCommand, MatchView>
{
    public async Task<MatchView> Handle(CancelMatchCommand request, CancellationToken cancellationToken)
    {
        var me = await workflow.MeAsync(cancellationToken);
        var (match, _) = await workflow.LoadVisibleAsync(me, request.MatchId, cancellationToken);
        if (match.Cancel(me.Id, request.Reason, workflow.Now))
            workflow.RecordLate(me.Id, match);
        return await workflow.SaveAndViewAsync(match, me.Id, cancellationToken);
    }
}
