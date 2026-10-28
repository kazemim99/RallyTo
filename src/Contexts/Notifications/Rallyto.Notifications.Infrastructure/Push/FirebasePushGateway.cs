using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Rallyto.Notifications.Application.Abstractions;

namespace Rallyto.Notifications.Infrastructure.Push;

/// <summary>
/// Firebase Cloud Messaging, ported from AsanRezerve's <c>FirebaseMessagingGateway</c>. Credentials come from
/// <c>Notifications:Firebase:CredentialsJson</c> or <c>CredentialsPath</c>; without them pushes are skipped, never faked.
/// </summary>
public sealed class FirebasePushGateway : IPushGateway
{
    /// <summary>Errors that mean the token is permanently gone, as opposed to a transient gateway problem.</summary>
    private static readonly HashSet<string> DeadTokenCodes = new(StringComparer.OrdinalIgnoreCase) { "UNREGISTERED", "INVALID_ARGUMENT", "SENDER_ID_MISMATCH" };

    private readonly ILogger<FirebasePushGateway> _logger;
    private readonly FirebaseMessaging? _messaging;

    public FirebasePushGateway(IConfiguration configuration, ILogger<FirebasePushGateway> logger)
    {
        _logger = logger;
        try
        {
            var credential = ResolveCredential(configuration["Notifications:Firebase:CredentialsPath"], configuration["Notifications:Firebase:CredentialsJson"]);
            if (credential is null)
            {
                _logger.LogWarning("Firebase is not configured; push notifications will be skipped on this environment");
                return;
            }

            // FirebaseApp is process-wide and throws if created twice.
            var app = FirebaseApp.DefaultInstance ?? FirebaseApp.Create(new AppOptions { Credential = credential });
            _messaging = FirebaseMessaging.GetMessaging(app);
        }
        catch (Exception ex)
        {
            // A misconfigured environment degrades to "push is skipped", never to a host that will not start.
            _logger.LogError(ex, "Firebase could not be initialised; push notifications will be skipped");
        }
    }

    public bool IsConfigured => _messaging is not null;

    public async Task<PushSendResult> SendAsync(string deviceToken, string title, string body, IReadOnlyDictionary<string, string> data, CancellationToken cancellationToken = default)
    {
        if (_messaging is null)
            return new PushSendResult(false, null, "Firebase is not configured");
        // The app registers FCM registration tokens (firebase_messaging getToken), which is what Token addresses;
        // Fid is a different identifier (Firebase installation id), so the deprecation does not apply to this use.
#pragma warning disable CS0618
        var message = new Message
        {
            Token = deviceToken,
            Notification = new Notification { Title = title, Body = body },
            Data = data.ToDictionary(kv => kv.Key, kv => kv.Value),
            Android = new AndroidConfig { Priority = Priority.High, Notification = new AndroidNotification { ChannelId = "rallyto", Tag = data.GetValueOrDefault("notificationId") } },
        };
#pragma warning restore CS0618
        try
        {
            return new PushSendResult(true, await _messaging.SendAsync(message, cancellationToken), null);
        }
        catch (FirebaseMessagingException ex)
        {
            var dead = ex.MessagingErrorCode is MessagingErrorCode.Unregistered or MessagingErrorCode.SenderIdMismatch || DeadTokenCodes.Contains(ex.ErrorCode.ToString());
            _logger.LogWarning(ex, "Firebase rejected a push ({ErrorCode}); token dead: {Dead}", ex.MessagingErrorCode, dead);
            return new PushSendResult(false, null, ex.Message, dead);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Push send failed");
            return new PushSendResult(false, null, ex.Message);
        }
    }

    private static GoogleCredential? ResolveCredential(string? path, string? json)
    {
        if (!string.IsNullOrWhiteSpace(json))
            return CredentialFactory.FromJson<ServiceAccountCredential>(json).ToGoogleCredential();
        if (!string.IsNullOrWhiteSpace(path) && File.Exists(path))
            return CredentialFactory.FromFile<ServiceAccountCredential>(path).ToGoogleCredential();
        return null;
    }
}
