using MediatR;
using Microsoft.EntityFrameworkCore;
using Rallyto.Community.Application.Safety;
using Rallyto.Identity.Application.Admin;
using Rallyto.Messaging.Infrastructure.Persistence;

namespace Rallyto.Host.Composition;

/// <summary>Community's evidence snapshots of messages, read in-process from Messaging (design D3).</summary>
public sealed class InProcessMessageEvidenceReader(MessagingDbContext messaging) : IMessageEvidenceReader
{
    public async Task<MessageEvidence?> ForReporterAsync(Guid reporterId, Guid messageId, CancellationToken cancellationToken)
    {
        var message = await messaging.Messages.AsNoTracking().FirstOrDefaultAsync(m => m.Id == messageId, cancellationToken);
        if (message is null || message.Body is null || message.SenderId == reporterId)
            return null;
        var member = await messaging.ConversationMembers.AsNoTracking()
            .FirstOrDefaultAsync(m => m.ConversationId == message.ConversationId && m.UserId == reporterId, cancellationToken);
        return member is not null && member.CanSee(message.Seq) ? new MessageEvidence(message.SenderId, message.Body, message.SentAt) : null;
    }

    public async Task<Guid?> SenderOfAsync(Guid messageId, CancellationToken cancellationToken) =>
        await messaging.Messages.AsNoTracking().Where(m => m.Id == messageId).Select(m => (Guid?)m.SenderId).FirstOrDefaultAsync(cancellationToken);
}

/// <summary>Moderation's account actions, sent to Identity's own audited commands in-process (design D11).</summary>
public sealed class InProcessAccountModeration(ISender sender) : IAccountModeration
{
    public Task SuspendAsync(Guid userId, DateTime untilUtc, string reason, CancellationToken cancellationToken) =>
        sender.Send(new SuspendAccountCommand(userId, untilUtc, reason), cancellationToken);

    public Task LiftSuspensionAsync(Guid userId, string reason, CancellationToken cancellationToken) =>
        sender.Send(new LiftSuspensionCommand(userId, reason), cancellationToken);

    public Task BanAsync(Guid userId, string reason, CancellationToken cancellationToken) =>
        sender.Send(new BanAccountCommand(userId, reason), cancellationToken);
}
