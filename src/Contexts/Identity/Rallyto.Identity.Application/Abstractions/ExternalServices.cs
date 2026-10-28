namespace Rallyto.Identity.Application.Abstractions;

public sealed record SmsSendResult(bool Success, string? MessageId = null, string? Error = null);

/// <summary>Sends sign-in codes. MeliPayamak in production (shared-line OTP template); a fake elsewhere.</summary>
public interface ISmsSender
{
    /// <param name="localMobile">The number in local form, <c>09xxxxxxxxx</c>.</param>
    Task<SmsSendResult> SendOtpAsync(string localMobile, string code, CancellationToken cancellationToken = default);
}
