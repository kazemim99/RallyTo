using Microsoft.Extensions.Options;
using Rallyto.Contracts.Identity;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Core.Application.Localization;
using Rallyto.Identity.Application.Abstractions;
using Rallyto.Identity.Domain;
using Rallyto.Identity.Domain.Accounts;
using Rallyto.Identity.Domain.Verification;

namespace Rallyto.Identity.Application.SignIn;

public sealed record AuthTokens(
    string AccessToken,
    DateTime AccessTokenExpiresAt,
    string RefreshToken,
    DateTime RefreshTokenExpiresAt,
    bool ProfileCompleted,
    IReadOnlyList<string> Roles);

public sealed record SendSignInCodeCommand(string PhoneNumber) : ICommand<SendCodeResult>;

public sealed record VerifySignInCodeCommand(string PhoneNumber, string Code) : ICommand<AuthTokens>;

public sealed record RefreshTokensCommand(string RefreshToken) : ICommand<AuthTokens>;

public sealed record SignOutCommand(string RefreshToken) : ICommand;

internal sealed class SendSignInCodeHandler(OtpService otp) : ICommandHandler<SendSignInCodeCommand, SendCodeResult>
{
    public Task<SendCodeResult> Handle(SendSignInCodeCommand request, CancellationToken cancellationToken) =>
        otp.SendAsync(PhoneNumber.Parse(request.PhoneNumber), VerificationPurpose.SignIn, cancellationToken);
}

internal sealed class VerifySignInCodeHandler(
    OtpService otp,
    IAccountRepository accounts,
    ISecretHasher hasher,
    TokenIssuer tokens,
    IAccountStatusCache statusCache,
    IIntegrationEventPublisher events,
    IIdentityUnitOfWork unitOfWork,
    TimeProvider clock) : ICommandHandler<VerifySignInCodeCommand, AuthTokens>
{
    public async Task<AuthTokens> Handle(VerifySignInCodeCommand request, CancellationToken cancellationToken)
    {
        var phone = PhoneNumber.Parse(request.PhoneNumber);
        await otp.VerifyAsync(phone, VerificationPurpose.SignIn, request.Code, cancellationToken);
        var now = clock.GetUtcNow().UtcDateTime;

        var account = await accounts.GetByPhoneAsync(phone, cancellationToken);
        if (account is null)
        {
            if (await accounts.IsPhoneBannedAsync(hasher.HashPhone(phone), cancellationToken))
                throw AccountAccess.Banned();
            account = UserAccount.Register(phone, isInitialAdmin: false, now);
            accounts.Add(account);
        }
        else if (account.ExpireSuspensionIfDue(now))
        {
            accounts.AddStatusChange(AccountStatusChange.Record(account.Id, AccountStatus.Suspended, AccountStatus.Active, "suspension ended", null, now));
            events.Enqueue(new AccountReactivated(account.Id));
            await statusCache.EvictAsync(account.Id, cancellationToken);
        }

        AccountAccess.EnsureCanSignIn(account);
        var issued = tokens.IssueNewSession(account, now);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return issued;
    }
}

internal sealed class RefreshTokensHandler(
    IRefreshTokenRepository refreshTokens,
    IAccountRepository accounts,
    ISecretHasher hasher,
    TokenIssuer tokens,
    IIdentityUnitOfWork unitOfWork,
    TimeProvider clock) : ICommandHandler<RefreshTokensCommand, AuthTokens>
{
    public async Task<AuthTokens> Handle(RefreshTokensCommand request, CancellationToken cancellationToken)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var token = await refreshTokens.GetByHashAsync(hasher.HashToken(request.RefreshToken ?? string.Empty), cancellationToken)
            ?? throw new UnauthorizedException("نشست شما معتبر نیست. دوباره وارد شوید.", "REFRESH_TOKEN_INVALID");

        if (token.WasRotated)
        {
            // A rotated token came back: it was copied. End every session descended from it.
            await refreshTokens.RevokeFamilyAsync(token.FamilyId, now, cancellationToken);
            throw new UnauthorizedException("نشست شما به دلیل امنیتی پایان یافت. دوباره وارد شوید.", "REFRESH_TOKEN_REUSED");
        }

        if (!token.IsUsable(now))
            throw new UnauthorizedException("نشست شما منقضی شده است. دوباره وارد شوید.", "REFRESH_TOKEN_INVALID");

        var account = await accounts.GetByIdAsync(token.AccountId, cancellationToken)
            ?? throw new UnauthorizedException("نشست شما معتبر نیست. دوباره وارد شوید.", "REFRESH_TOKEN_INVALID");
        if (account.StatusAt(now) != AccountStatus.Active)
            throw new UnauthorizedException("حساب کاربری فعال نیست.", "ACCOUNT_INACTIVE");

        var issued = tokens.Rotate(account, token, now);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return issued;
    }
}

internal sealed class SignOutHandler(
    IRefreshTokenRepository refreshTokens,
    ISecretHasher hasher,
    IIdentityUnitOfWork unitOfWork,
    TimeProvider clock) : ICommandHandler<SignOutCommand>
{
    public async Task Handle(SignOutCommand request, CancellationToken cancellationToken)
    {
        var token = await refreshTokens.GetByHashAsync(hasher.HashToken(request.RefreshToken ?? string.Empty), cancellationToken);
        if (token is null)
            return;
        token.Revoke(clock.GetUtcNow().UtcDateTime);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
    }
}

/// <summary>Creates access and refresh tokens for an account.</summary>
public sealed class TokenIssuer(ITokenService tokenService, IRefreshTokenRepository refreshTokens, ISecretHasher hasher, ICurrentUserService currentUser)
{
    public AuthTokens IssueNewSession(UserAccount account, DateTime now)
    {
        var raw = tokenService.CreateRefreshToken();
        var refresh = RefreshToken.Issue(account.Id, Guid.NewGuid(), hasher.HashToken(raw), now, tokenService.RefreshTokenLifetime, currentUser.IpAddress);
        refreshTokens.Add(refresh);
        return Build(account, now, raw, refresh);
    }

    public AuthTokens Rotate(UserAccount account, RefreshToken current, DateTime now)
    {
        var raw = tokenService.CreateRefreshToken();
        var next = current.Rotate(hasher.HashToken(raw), now, tokenService.RefreshTokenLifetime, currentUser.IpAddress);
        refreshTokens.Add(next);
        return Build(account, now, raw, next);
    }

    private AuthTokens Build(UserAccount account, DateTime now, string rawRefresh, RefreshToken refresh)
    {
        var access = tokenService.CreateAccessToken(account, now);
        return new AuthTokens(access.Token, access.ExpiresAt, rawRefresh, refresh.ExpiresAt, account.ProfileCompleted, RoleNames(account.Roles));
    }

    public static IReadOnlyList<string> RoleNames(AccountRoles roles) =>
        Enum.GetValues<AccountRoles>().Where(r => r != AccountRoles.None && roles.HasFlag(r)).Select(r => r.ToString()).ToList();
}

/// <summary>Sign-in refusals for accounts that are not Active (spec identity-access).</summary>
public static class AccountAccess
{
    public static void EnsureCanSignIn(UserAccount account)
    {
        switch (account.Status)
        {
            case AccountStatus.Suspended:
                throw new ForbiddenException($"حساب کاربری شما تا {PersianFormat.Date(account.SuspendedUntil!.Value)} مسدود است.", "ACCOUNT_SUSPENDED");
            case AccountStatus.Banned:
                throw Banned();
            case AccountStatus.Deleted:
                throw new ForbiddenException("حساب کاربری حذف شده است.", "ACCOUNT_DELETED");
        }
    }

    public static ForbiddenException Banned() => new("حساب کاربری این شماره مسدود شده است.", "ACCOUNT_BANNED");
}
