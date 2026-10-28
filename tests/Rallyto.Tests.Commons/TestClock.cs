namespace Rallyto.Tests.Commons;

/// <summary>
/// A clock tests can set and move freely, including backwards between tests (FakeTimeProvider refuses that).
/// Only "now" is faked; timers and stopwatches stay real.
/// </summary>
public sealed class TestClock(DateTimeOffset start) : TimeProvider
{
    private long _utcTicks = start.UtcTicks;

    public override DateTimeOffset GetUtcNow() => new(Interlocked.Read(ref _utcTicks), TimeSpan.Zero);

    public void SetUtcNow(DateTimeOffset value) => Interlocked.Exchange(ref _utcTicks, value.UtcTicks);

    public void Advance(TimeSpan by) => Interlocked.Add(ref _utcTicks, by.Ticks);
}
