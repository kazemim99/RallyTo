using FluentValidation;
using Rallyto.Contracts.Admin;
using Rallyto.Contracts.Identity;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Core.Application.Localization;
using Rallyto.Core.Application.Results;
using Rallyto.Identity.Application.Abstractions;
using Rallyto.Identity.Application.SignIn;
using Rallyto.Identity.Domain.Accounts;

namespace Rallyto.Identity.Application.Admin;

public sealed record AdminAccountDto(
    Guid UserId,
    string? PhoneNumber,
    IReadOnlyList<string> Roles,
    AccountStatus Status,
    DateTime? SuspendedUntil,
    string? StatusReason,
    DateTime CreatedAt);

public sealed record ListAccountsQuery(string? Search, AccountStatus? Status, int Page = 1, int PageSize = 20) : IQuery<PagedResult<AdminAccountDto>>;

public sealed record GetAccountQuery(Guid UserId) : IQuery<AdminAccountDto>;

public sealed record SuspendAccountCommand(Guid UserId, DateTime Until, string Reason) : ICommand;

public sealed record LiftSuspensionCommand(Guid UserId, string Reason) : ICommand;

public sealed record BanAccountCommand(Guid UserId, string Reason) : ICommand;

public sealed record GrantAdminCommand(Guid UserId) : ICommand;

public sealed record RevokeAdminCommand(Guid UserId) : ICommand;

internal sealed class SuspendAccountValidator : AbstractValidator<SuspendAccountCommand>
{
    public SuspendAccountValidator() => RuleFor(c => c.Reason).NotEmpty().WithErrorCode("REASON_REQUIRED").WithMessage("دلیل را بنویسید.").MaximumLength(500);
}

internal sealed class BanValidator : AbstractValidator<BanAccountCommand>
{
    public BanValidator() => RuleFor(c => c.Reason).NotEmpty().WithErrorCode("REASON_REQUIRED").WithMessage("دلیل را بنویسید.").MaximumLength(500);
}

internal sealed class ListAccountsHandler(IAccountRepository accounts) : IQueryHandler<ListAccountsQuery, PagedResult<AdminAccountDto>>
{
    public async Task<PagedResult<AdminAccountDto>> Handle(ListAccountsQuery request, CancellationToken cancellationToken)
    {
        var digits = PersianFormat.ToAsciiDigits(request.Search ?? string.Empty).Where(char.IsAsciiDigit).ToArray();
        var search = new string(digits).TrimStart('0');
        var page = await accounts.ListAsync(search.Length == 0 ? null : search, request.Status,
            Math.Max(1, request.Page), Math.Clamp(request.PageSize, 1, 100), cancellationToken);
        return new PagedResult<AdminAccountDto>(page.Items.Select(AdminAccountMapping.ToDto).ToList(), page.Page, page.PageSize, page.TotalCount);
    }
}

internal sealed class GetAccountHandler(IAccountRepository accounts) : IQueryHandler<GetAccountQuery, AdminAccountDto>
{
    public async Task<AdminAccountDto> Handle(GetAccountQuery request, CancellationToken cancellationToken) =>
        AdminAccountMapping.ToDto(await accounts.GetByIdAsync(request.UserId, cancellationToken) ?? throw new NotFoundException());
}

internal static class AdminAccountMapping
{
    public static AdminAccountDto ToDto(UserAccount a) =>
        new(a.Id, a.Phone?.Value, TokenIssuer.RoleNames(a.Roles), a.Status, a.SuspendedUntil, a.StatusReason, a.RegisteredAt);
}

/// <summary>Shared steps of every admin status change: audit row, token revocation, cache eviction, events.</summary>
internal sealed class AccountAdministration(
    IAccountRepository accounts,
    IRefreshTokenRepository refreshTokens,
    ICurrentUserService currentUser,
    IAccountStatusCache statusCache,
    IRealtimePublisher realtime,
    IIntegrationEventPublisher events,
    IIdentityUnitOfWork unitOfWork,
    TimeProvider clock)
{
    public DateTime Now => clock.GetUtcNow().UtcDateTime;

    public Guid AdminId => currentUser.RequireUserId();

    public async Task<UserAccount> LoadTargetAsync(Guid userId, CancellationToken cancellationToken)
    {
        if (userId == AdminId)
            throw new ConflictException("CANNOT_ACT_ON_SELF", "این کار روی حساب خودتان ممکن نیست.");
        return await accounts.GetByIdAsync(userId, cancellationToken) ?? throw new NotFoundException();
    }

    public async Task CommitStatusChangeAsync(UserAccount account, AccountStatus from, string action, string reason,
        IntegrationEvent statusEvent, bool endSessions, CancellationToken cancellationToken)
    {
        accounts.AddStatusChange(AccountStatusChange.Record(account.Id, from, account.Status, reason, AdminId, Now));
        if (endSessions)
            await refreshTokens.RevokeAllForAccountAsync(account.Id, Now, cancellationToken);
        events.Enqueue(statusEvent);
        events.Enqueue(new AdminActionRecorded(AdminId, action, "Account", account.Id.ToString(), account.Id, reason));
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);

        await statusCache.EvictAsync(account.Id, cancellationToken);
        if (endSessions)
            await realtime.DisconnectUserAsync(account.Id, cancellationToken);
    }

    public async Task CommitRoleChangeAsync(UserAccount account, string action, CancellationToken cancellationToken)
    {
        events.Enqueue(new AdminActionRecorded(AdminId, action, "Account", account.Id.ToString(), account.Id, null));
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
    }
}

internal sealed class SuspendAccountHandler(AccountAdministration admin) : ICommandHandler<SuspendAccountCommand>
{
    public async Task Handle(SuspendAccountCommand request, CancellationToken cancellationToken)
    {
        var account = await admin.LoadTargetAsync(request.UserId, cancellationToken);
        var from = account.Status;
        var until = DateTime.SpecifyKind(request.Until, DateTimeKind.Utc);
        account.Suspend(until, request.Reason, admin.Now);
        await admin.CommitStatusChangeAsync(account, from, "account.suspend", request.Reason,
            new AccountSuspended(account.Id, until, request.Reason), endSessions: true, cancellationToken);
    }
}

internal sealed class LiftSuspensionHandler(AccountAdministration admin) : ICommandHandler<LiftSuspensionCommand>
{
    public async Task Handle(LiftSuspensionCommand request, CancellationToken cancellationToken)
    {
        var account = await admin.LoadTargetAsync(request.UserId, cancellationToken);
        var from = account.Status;
        account.LiftSuspension();
        await admin.CommitStatusChangeAsync(account, from, "account.lift-suspension", request.Reason,
            new AccountReactivated(account.Id), endSessions: false, cancellationToken);
    }
}

internal sealed class BanAccountHandler(AccountAdministration admin, IAccountRepository accounts, ISecretHasher hasher) : ICommandHandler<BanAccountCommand>
{
    public async Task Handle(BanAccountCommand request, CancellationToken cancellationToken)
    {
        var account = await admin.LoadTargetAsync(request.UserId, cancellationToken);
        var from = account.Status;
        account.Ban(request.Reason);
        if (account.Phone is { } phone)
            accounts.AddBannedPhone(BannedPhone.Record(hasher.HashPhone(phone), account.Id, admin.Now));
        await admin.CommitStatusChangeAsync(account, from, "account.ban", request.Reason,
            new AccountBanned(account.Id, request.Reason), endSessions: true, cancellationToken);
    }
}

internal sealed class GrantAdminHandler(AccountAdministration admin) : ICommandHandler<GrantAdminCommand>
{
    public async Task Handle(GrantAdminCommand request, CancellationToken cancellationToken)
    {
        var account = await admin.LoadTargetAsync(request.UserId, cancellationToken);
        account.GrantAdmin();
        await admin.CommitRoleChangeAsync(account, "account.grant-admin", cancellationToken);
    }
}

internal sealed class RevokeAdminHandler(AccountAdministration admin, IAccountRepository accounts) : ICommandHandler<RevokeAdminCommand>
{
    public async Task Handle(RevokeAdminCommand request, CancellationToken cancellationToken)
    {
        var account = await accounts.GetByIdAsync(request.UserId, cancellationToken) ?? throw new NotFoundException();
        if (account.IsAdmin && account.Status == AccountStatus.Active && await accounts.CountActiveAdminsAsync(cancellationToken) <= 1)
            throw new ConflictException("LAST_ADMIN", "دست‌کم یک ادمین فعال باید باقی بماند.");
        account.RevokeAdmin();
        await admin.CommitRoleChangeAsync(account, "account.revoke-admin", cancellationToken);
    }
}
