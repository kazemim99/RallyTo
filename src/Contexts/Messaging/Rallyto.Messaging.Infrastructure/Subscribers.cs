using DotNetCore.CAP;
using Microsoft.EntityFrameworkCore;
using Rallyto.Contracts.Community;
using Rallyto.Contracts.Identity;
using Rallyto.Messaging.Application.Conversations;
using Rallyto.Messaging.Infrastructure.Persistence;

namespace Rallyto.Messaging.Infrastructure;

/// <summary>Match chats follow the match roster; every participant change triggers a resync (spec chat › Match group conversations).</summary>
public sealed class MatchEventsSubscriber(MatchConversationSync sync) : ICapSubscribe
{
    [CapSubscribe(MatchTopics.JoinRequestAnswered, Group = MessagingModule.CapGroup)]
    public Task OnJoinAnswered(JoinRequestAnswered message) => message.Accepted ? sync.SyncAsync(message.MatchId, CancellationToken.None) : Task.CompletedTask;

    [CapSubscribe(MatchTopics.InvitationAnswered, Group = MessagingModule.CapGroup)]
    public Task OnInvitationAnswered(InvitationAnswered message) => message.Accepted ? sync.SyncAsync(message.MatchId, CancellationToken.None) : Task.CompletedTask;

    [CapSubscribe(MatchTopics.MatchConfirmed, Group = MessagingModule.CapGroup)]
    public Task OnConfirmed(MatchConfirmed message) => sync.SyncAsync(message.MatchId, CancellationToken.None);

    [CapSubscribe(MatchTopics.ParticipantLeft, Group = MessagingModule.CapGroup)]
    public Task OnLeft(ParticipantLeft message) => sync.SyncAsync(message.MatchId, CancellationToken.None);

    [CapSubscribe(MatchTopics.ParticipantRemoved, Group = MessagingModule.CapGroup)]
    public Task OnRemoved(ParticipantRemoved message) => sync.SyncAsync(message.MatchId, CancellationToken.None);
}

/// <summary>An admin deleted a message as a moderation action; Community decided, Messaging owns the message.</summary>
public sealed class ModerationSubscriber(MessagingDbContext db, TimeProvider clock) : ICapSubscribe
{
    [CapSubscribe(SafetyTopics.MessageRemovalRequested, Group = MessagingModule.CapGroup)]
    public async Task OnMessageRemovalRequested(MessageRemovalRequested message)
    {
        if (await db.Messages.FirstOrDefaultAsync(m => m.Id == message.MessageId) is not { } target)
            return;
        target.RemoveByModerator(clock.GetUtcNow().UtcDateTime);
        await db.SaveChangesAsync();
    }
}

/// <summary>A suspended, banned or deleted member cannot be written to; their earlier messages stay (spec chat › Inactive members).</summary>
public sealed class AccountStatusSubscriber(MessagingDbContext db) : ICapSubscribe
{
    [CapSubscribe(IdentityTopics.AccountSuspended, Group = MessagingModule.CapGroup)]
    public Task OnSuspended(AccountSuspended message) => SetInactiveAsync(message.UserId, true);

    [CapSubscribe(IdentityTopics.AccountBanned, Group = MessagingModule.CapGroup)]
    public Task OnBanned(AccountBanned message) => SetInactiveAsync(message.UserId, true);

    [CapSubscribe(IdentityTopics.AccountDeleted, Group = MessagingModule.CapGroup)]
    public Task OnDeleted(AccountDeleted message) => SetInactiveAsync(message.UserId, true);

    [CapSubscribe(IdentityTopics.AccountReactivated, Group = MessagingModule.CapGroup)]
    public Task OnReactivated(AccountReactivated message) => SetInactiveAsync(message.UserId, false);

    private Task SetInactiveAsync(Guid userId, bool inactive) =>
        db.ConversationMembers.Where(m => m.UserId == userId).ExecuteUpdateAsync(s => s.SetProperty(m => m.AccountInactive, inactive));
}
