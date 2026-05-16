using System.Collections.Concurrent;

namespace SearchAssistant.Api.Services;

// Per-participant cooldown for SendPosition hub calls. Singleton, so the
// dictionary persists across hub method invocations (hubs are transient).
public class PositionRateLimiter
{
    // Client throttles to 1/s; we accept down to ~700ms to leave room for jitter.
    private static readonly long CooldownTicks = TimeSpan.FromMilliseconds(700).Ticks;

    private readonly ConcurrentDictionary<Guid, long> _lastTick = new();

    public bool TryAccept(Guid participantId)
    {
        var now = DateTime.UtcNow.Ticks;
        // AddOrUpdate atomically — only accept when the gap is big enough.
        var accepted = false;
        _lastTick.AddOrUpdate(
            participantId,
            _ => { accepted = true; return now; },
            (_, prev) =>
            {
                if (now - prev >= CooldownTicks) { accepted = true; return now; }
                return prev;
            });
        return accepted;
    }
}
