using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Identity.Application.Abstractions;
using Rallyto.Identity.Domain.Accounts;

namespace Rallyto.Identity.Application.SignIn;

/// <summary>The admin panel's sign-in (design D10): email and password. Players keep the SMS code.</summary>
public sealed record AdminSignInCommand(string Email, string Password) : ICommand<AuthTokens>;

internal sealed class AdminSignInHandler(
    IAccountRepository accounts,
    IPasswordHasher passwords,
    TokenIssuer tokens,
    IIdentityUnitOfWork unitOfWork,
    TimeProvider clock) : ICommandHandler<AdminSignInCommand, AuthTokens>
{
    public async Task<AuthTokens> Handle(AdminSignInCommand request, CancellationToken cancellationToken)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var account = string.IsNullOrWhiteSpace(request.Email) ? null : await accounts.GetByEmailAsync(UserAccount.NormaliseEmail(request.Email), cancellationToken);
        if (account?.PasswordHash is not { } hash || !account.IsAdmin)
        {
            // Same work and answer for an unknown email, so the response does not reveal which emails exist.
            passwords.Verify(passwords.DummyHash, request.Password ?? string.Empty);
            throw InvalidCredentials();
        }

        if (account.IsPasswordLocked(now))
            throw new TooManyRequestsException("ورود به دلیل تلاش‌های ناموفق موقتاً بسته شده است. کمی بعد دوباره تلاش کنید.",
                account.PasswordLockedUntil - now, "ADMIN_SIGN_IN_LOCKED");
        if (!passwords.Verify(hash, request.Password ?? string.Empty))
        {
            account.RecordPasswordFailure(now);
            await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
            throw InvalidCredentials();
        }

        AccountAccess.EnsureCanSignIn(account);
        account.RecordPasswordSuccess();
        var issued = tokens.IssueNewSession(account, now);
        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return issued;
    }

    private static UnauthorizedException InvalidCredentials() => new("ایمیل یا رمز عبور درست نیست.", "INVALID_CREDENTIALS");
}
