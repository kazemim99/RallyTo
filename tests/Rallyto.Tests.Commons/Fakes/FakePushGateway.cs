using System.Collections.Concurrent;
using Rallyto.Notifications.Application.Abstractions;

namespace Rallyto.Tests.Commons.Fakes;

public sealed record SentPush(string Token, string Title, string Body, IReadOnlyDictionary<string, string> Data);

/// <summary>Records pushes instead of calling Firebase. Tokens in <see cref="DeadTokens"/> answer like an uninstalled app.</summary>
public sealed class FakePushGateway : IPushGateway
{
    private readonly ConcurrentQueue<SentPush> _sent = new();

    public ConcurrentDictionary<string, bool> DeadTokens { get; } = new();

    public bool IsConfigured => true;

    public IReadOnlyList<SentPush> Sent => [.. _sent];

    public IReadOnlyList<SentPush> SentTo(string token) => _sent.Where(p => p.Token == token).ToList();

    public Task<PushSendResult> SendAsync(string deviceToken, string title, string body, IReadOnlyDictionary<string, string> data, CancellationToken cancellationToken = default)
    {
        if (DeadTokens.ContainsKey(deviceToken))
            return Task.FromResult(new PushSendResult(false, null, "UNREGISTERED", TokenIsDead: true));
        _sent.Enqueue(new SentPush(deviceToken, title, body, data));
        return Task.FromResult(new PushSendResult(true, $"fake-{_sent.Count}", null));
    }

    public void Reset()
    {
        _sent.Clear();
        DeadTokens.Clear();
    }
}
