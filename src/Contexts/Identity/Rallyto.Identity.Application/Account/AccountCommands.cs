using Rallyto.Contracts.Identity;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Identity.Application.Abstractions;
using Rallyto.Identity.Application.SignIn;
using Rallyto.Identity.Domain.Accounts;
using Rallyto.Identity.Domain.Verification;

namespace Rallyto.Identity.Application.Account;

public sealed record MyAccountDto(Guid UserId, string PhoneNumber, IReadOnlyList<string> Roles, AccountStatus Status, bool ProfileCompleted);

public sealed record GetMyAccountQuery : IQuery<MyAccountDto>;

public sealed record SendDeletionCodeCommand : ICommand<SendCodeResult>;

public sealed record DeleteAccountCommand(string Code) : ICommand;

internal sealed class GetMyAccountHandler(IAccountRepository accounts, ICurrentUserService currentUser) : IQueryHandler<GetMyAccountQuery, MyAccountDto>
{
    public async Task<MyAccountDto> Handle(GetMyAccountQuery request, CancellationToken cancellationToken)
    {
        var account = await accounts.GetByIdAsync(currentUser.RequireUserId(), cancellationToken) ?? throw new NotFoundException();
        return new MyAccountDto(account.Id, account.Phone?.Value ?? string.Empty, TokenIssuer.RoleNames(account.Roles), account.Status, account.ProfileCompleted);
    }
}

internal sealed class SendDeletionCodeHandler(IAccountRepository accounts, ICurrentUserService currentUser, OtpService otp)
    : ICommandHandler<SendDeletionCodeCommand, SendCodeResult>
{
    public async Task<SendCodeResult> Handle(SendDeletionCodeCommand request, CancellationToken cancellationToken)
    {
        var account = await accounts.GetByIdAsync(currentUser.RequireUserId(), cancellationToken) ?? throw new NotFoundException();
        return await otp.SendAsync(account.Phone!, VerificationPurpose.AccountDeletion, cancellationToken);
    }
}

/// <summary>Deletes the caller's account after a fresh code; the other contexts react to <see cref="AccountDeleted"/>.</summary>
internal sealed class DeleteAccountHandler(
    IAccountRepository accounts,
    IRefreshTokenRepository refreshTokens,
    ICurrentUserService currentUser,
    OtpService otp,
    IAccountStatusCache statusCache,
    IRealtimePublisher realtime,
    IIntegrationEventPublisher events,
    IIdentityUnitOfWork unitOfWork,
    TimeProvider clock) : ICommandHandler<DeleteAccountCommand>
{
    public async Task Handle(DeleteAccountCommand request, CancellationToken cancellationToken)
    {
        var account = await accounts.GetByIdAsync(currentUser.RequireUserId(), cancellationToken) ?? throw new NotFoundException();
        await otp.VerifyAsync(account.Phone!, VerificationPurpose.AccountDeletion, request.Code, cancellationToken);

        var now = clock.GetUtcNow().UtcDateTime;
        var previous = account.Status;
        account.Delete(now);
        accounts.AddStatusChange(AccountStatusChange.Record(account.Id, previous, AccountStatus.Deleted, "deleted by the player", account.Id, now));
        await refreshTokens.RevokeAllForAccountAsync(account.Id, now, cancellationToken);
        events.Enqueue(new AccountDeleted(account.Id));
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);

        await statusCache.EvictAsync(account.Id, cancellationToken);
        await realtime.DisconnectUserAsync(account.Id, cancellationToken);
    }
}
