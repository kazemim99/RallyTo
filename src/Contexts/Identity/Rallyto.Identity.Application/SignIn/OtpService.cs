using Microsoft.Extensions.Options;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Identity.Application.Abstractions;
using Rallyto.Identity.Domain;
using Rallyto.Identity.Domain.Verification;

namespace Rallyto.Identity.Application.SignIn;

public sealed record SendCodeResult(int ExpiresInSeconds, int ResendAfterSeconds);

/// <summary>Sends and checks sign-in codes with the per-number limits of spec identity-access.</summary>
public sealed class OtpService(
    IPhoneVerificationRepository verifications,
    ISmsSender sms,
    IOtpCodeGenerator generator,
    ISecretHasher hasher,
    IIdentityUnitOfWork unitOfWork,
    TimeProvider clock,
    IOptions<OtpOptions> options)
{
    private readonly OtpOptions _options = options.Value;

    public async Task<SendCodeResult> SendAsync(PhoneNumber phone, VerificationPurpose purpose, CancellationToken cancellationToken)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        await EnsureNotBlockedAsync(phone, now, cancellationToken);

        var recent = await verifications.GetSendTimesSinceAsync(phone, now - _options.Window, cancellationToken);
        if (recent.Count > 0 && now - recent[^1] < _options.ResendCooldown)
        {
            throw new TooManyRequestsException("کمی صبر کنید و دوباره درخواست کد بدهید.",
                _options.ResendCooldown - (now - recent[^1]), "OTP_RESEND_TOO_SOON");
        }

        if (recent.Count >= _options.MaxSendsPerWindow)
        {
            throw new TooManyRequestsException("تعداد درخواست کد زیاد است. چند دقیقه بعد دوباره تلاش کنید.",
                recent[0] + _options.Window - now, "OTP_SEND_LIMIT");
        }

        foreach (var pending in await verifications.GetPendingAsync(phone, purpose, cancellationToken))
            pending.Supersede();

        var code = generator.Generate(_options.CodeLength);
        var verification = PhoneVerification.Create(phone, purpose, hasher.HashCode(phone, code), now, _options.Lifetime);
        verifications.Add(verification);

        var result = await sms.SendOtpAsync(phone.LocalForm, code, cancellationToken);
        if (!result.Success)
        {
            verification.Cancel();
            await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
            throw new ExternalServiceException("SMS_SEND_FAILED", "ارسال پیامک ناموفق بود. چند لحظه بعد دوباره تلاش کنید.");
        }

        await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
        return new SendCodeResult(_options.LifetimeSeconds, _options.ResendCooldownSeconds);
    }

    /// <summary>Checks the latest code; throws for a wrong, expired or blocked attempt (after saving the attempt).</summary>
    public async Task VerifyAsync(PhoneNumber phone, VerificationPurpose purpose, string code, CancellationToken cancellationToken)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        await EnsureNotBlockedAsync(phone, now, cancellationToken);

        var normalizedCode = Core.Application.Localization.PersianFormat.ToAsciiDigits(code ?? string.Empty).Trim();
        var verification = await verifications.GetLatestPendingAsync(phone, purpose, cancellationToken);
        if (verification is null || normalizedCode.Length != _options.CodeLength || !normalizedCode.All(char.IsAsciiDigit))
            throw new ValidationFailedException("CODE_INVALID", "کد واردشده درست نیست.");

        var outcome = verification.Verify(hasher.HashCode(phone, normalizedCode), now, _options.MaxAttempts, _options.Block);
        switch (outcome)
        {
            case VerificationOutcome.Verified:
                return;
            case VerificationOutcome.Expired:
                throw new ValidationFailedException("CODE_EXPIRED", "کد منقضی شده است. کد جدید بگیرید.");
            default:
                await unitOfWork.SaveAndPublishEventsAsync(cancellationToken);
                throw new ValidationFailedException("CODE_INVALID", "کد واردشده درست نیست.");
        }
    }

    private async Task EnsureNotBlockedAsync(PhoneNumber phone, DateTime now, CancellationToken cancellationToken)
    {
        if (await verifications.GetBlockedUntilAsync(phone, now, cancellationToken) is { } until)
        {
            throw new TooManyRequestsException("به دلیل تلاش‌های ناموفق، ورود با این شماره موقتاً ممکن نیست.",
                until - now, "VERIFICATION_BLOCKED");
        }
    }
}
