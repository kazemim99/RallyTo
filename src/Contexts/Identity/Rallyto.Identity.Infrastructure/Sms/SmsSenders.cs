using System.Diagnostics;
using System.Globalization;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Rallyto.Identity.Application.Abstractions;

namespace Rallyto.Identity.Infrastructure.Sms;

/// <summary>Development sender: writes the code to the log. The production guard refuses <c>Sms:Provider=Fake</c>.</summary>
internal sealed class LoggingSmsSender(ILogger<LoggingSmsSender> logger) : ISmsSender
{
    public Task<SmsSendResult> SendOtpAsync(string localMobile, string code, CancellationToken cancellationToken = default)
    {
        logger.LogWarning("Development SMS (not sent) to {Recipient}: sign-in digits {Digits}", localMobile, code);
        return Task.FromResult(new SmsSendResult(true, $"dev-{Guid.NewGuid():N}"));
    }
}

public sealed class MeliPayamakOptions
{
    public const string SectionName = "MeliPayamak";
    public string BaseUrl { get; set; } = "https://rest.payamak-panel.com/api/SendSMS/";
    public string? UserName { get; set; }
    public string? ApiKey { get; set; }
    public int OtpBodyId { get; set; }
    public int ConnectTimeoutSeconds { get; set; } = 5;
}

/// <summary>
/// Sends the code through MeliPayamak's approved shared-line template (<c>BaseServiceNumber</c> with <c>bodyId</c>),
/// ported from AsanRezerve. A connection that never opened is retried up to 3 times within 18 s; a request that
/// reached MeliPayamak is never sent twice.
/// </summary>
internal sealed class MeliPayamakSmsSender(HttpClient http, IOptions<MeliPayamakOptions> options, ILogger<MeliPayamakSmsSender> logger) : ISmsSender
{
    private const int MaxConnectAttempts = 3;
    private static readonly TimeSpan RetryBudget = TimeSpan.FromSeconds(18);
    private readonly MeliPayamakOptions _options = options.Value;

    public async Task<SmsSendResult> SendOtpAsync(string localMobile, string code, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_options.UserName) || string.IsNullOrWhiteSpace(_options.ApiKey) || _options.OtpBodyId <= 0)
        {
            logger.LogError("MeliPayamak is not configured (UserName, ApiKey and OtpBodyId are required); no SMS sent to {Recipient}", localMobile);
            return new SmsSendResult(false, Error: "MeliPayamak is not configured");
        }

        var form = new Dictionary<string, string>
        {
            ["username"] = _options.UserName,
            ["password"] = _options.ApiKey,
            ["to"] = localMobile,
            ["bodyId"] = _options.OtpBodyId.ToString(CultureInfo.InvariantCulture),
            ["text"] = code,
        };
        var url = _options.BaseUrl.TrimEnd('/') + "/BaseServiceNumber";

        var first = Stopwatch.GetTimestamp();
        for (var attempt = 1; ; attempt++)
        {
            var started = Stopwatch.GetTimestamp();
            try
            {
                using var response = await http.PostAsync(url, new FormUrlEncodedContent(form), cancellationToken);
                var body = await response.Content.ReadAsStringAsync(cancellationToken);
                if (!response.IsSuccessStatusCode)
                {
                    logger.LogError("MeliPayamak answered {Status} for {Recipient}: {Body}", (int)response.StatusCode, localMobile, body);
                    return new SmsSendResult(false, Error: $"MeliPayamak HTTP {(int)response.StatusCode}");
                }

                return Interpret(localMobile, body);
            }
            catch (Exception ex) when (attempt < MaxConnectAttempts && Stopwatch.GetElapsedTime(first) < RetryBudget
                                       && IsConnectionFailure(ex, Stopwatch.GetElapsedTime(started), cancellationToken))
            {
                logger.LogWarning(ex, "MeliPayamak unreachable for {Recipient} (try {Attempt}); retrying", localMobile, attempt);
            }
            catch (Exception ex) when (!cancellationToken.IsCancellationRequested)
            {
                logger.LogError(ex, "MeliPayamak failed for {Recipient} after {Attempts} attempt(s)", localMobile, attempt);
                return new SmsSendResult(false, Error: $"MeliPayamak unreachable: {ex.GetType().Name}");
            }
        }
    }

    private SmsSendResult Interpret(string localMobile, string body)
    {
        string? value = null;
        int? retStatus = null;
        try
        {
            using var json = JsonDocument.Parse(body);
            if (json.RootElement.TryGetProperty("Value", out var v))
                value = v.ValueKind == JsonValueKind.String ? v.GetString() : v.GetRawText();
            if (json.RootElement.TryGetProperty("RetStatus", out var r) && r.TryGetInt32(out var rs))
                retStatus = rs;
        }
        catch (JsonException)
        {
            // fall through: treated as a refusal below
        }

        // A message id is a long positive number; short values are MeliPayamak's error codes.
        if (retStatus == 1 && value is { Length: >= 5 } && long.TryParse(value, out var id) && id > 0)
            return new SmsSendResult(true, value);

        logger.LogError("MeliPayamak refused the code to {Recipient}: {Code}; answer {Body}", localMobile, value ?? retStatus?.ToString(CultureInfo.InvariantCulture), body);
        return new SmsSendResult(false, Error: $"MeliPayamak refused: {value ?? retStatus?.ToString(CultureInfo.InvariantCulture)}");
    }

    private bool IsConnectionFailure(Exception ex, TimeSpan elapsed, CancellationToken cancellationToken)
    {
        if (cancellationToken.IsCancellationRequested)
            return false;
        return ex switch
        {
            HttpRequestException { HttpRequestError: HttpRequestError.ConnectionError or HttpRequestError.NameResolutionError } => true,
            TaskCanceledException => elapsed <= TimeSpan.FromSeconds(_options.ConnectTimeoutSeconds + 1),
            _ => false,
        };
    }
}
