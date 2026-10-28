using System.Collections.Concurrent;
using Rallyto.Identity.Application.Abstractions;

namespace Rallyto.Tests.Commons.Fakes;

/// <summary>Records every code instead of sending it. Set <see cref="Fail"/> to simulate a provider outage.</summary>
public sealed class FakeSmsSender : ISmsSender
{
    private readonly ConcurrentQueue<SentSms> _sent = new();

    public bool Fail { get; set; }

    public IReadOnlyList<SentSms> Sent => [.. _sent];

    public Task<SmsSendResult> SendOtpAsync(string localMobile, string code, CancellationToken cancellationToken = default)
    {
        _sent.Enqueue(new SentSms(localMobile, code, Fail));
        return Task.FromResult(Fail ? new SmsSendResult(false, Error: "simulated outage") : new SmsSendResult(true, $"fake-{_sent.Count}"));
    }

    public string LastCodeFor(string localMobile) =>
        _sent.LastOrDefault(s => s.To == localMobile)?.Code
        ?? throw new InvalidOperationException($"No code was sent to {localMobile}");

    public int CountFor(string localMobile) => _sent.Count(s => s.To == localMobile && !s.Failed);

    public void Reset()
    {
        _sent.Clear();
        Fail = false;
    }
}

public sealed record SentSms(string To, string Code, bool Failed);
