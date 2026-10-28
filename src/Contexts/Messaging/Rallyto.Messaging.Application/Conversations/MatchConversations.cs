using Rallyto.Messaging.Application.Abstractions;
using Rallyto.Messaging.Domain.Conversations;

namespace Rallyto.Messaging.Application.Conversations;

/// <summary>
/// Keeps a match's group conversation in step with its roster (spec chat › Match group conversations). Called for
/// every participant event; it reads the current roster, so repeated or out-of-order events converge.
/// </summary>
public sealed class MatchConversationSync(
    IMatchRosterReader rosters,
    IConversationRepository conversations,
    IMessageRepository messages,
    IMessagingUnitOfWork unitOfWork,
    TimeProvider clock)
{
    /// <summary>The host and at least two accepted players. With fewer, the players use their direct conversation.</summary>
    public const int MinPlayersForGroup = 3;

    public async Task SyncAsync(Guid matchId, CancellationToken cancellationToken)
    {
        var roster = await rosters.GetAsync(matchId, cancellationToken);
        if (roster is null || roster.Capacity <= 2)
            return;
        var now = clock.GetUtcNow().UtcDateTime;
        var conversation = await conversations.GetForMatchAsync(matchId, cancellationToken);
        if (conversation is null)
        {
            if (roster.PlayerIds.Count < MinPlayersForGroup)
                return;
            conversations.Add(Conversation.ForMatch(matchId, roster.Title, roster.PlayerIds, now));
        }
        else
        {
            conversation.SyncMembers(roster.PlayerIds, await messages.LastSeqAsync(conversation.Id, cancellationToken), now);
        }

        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
    }
}
