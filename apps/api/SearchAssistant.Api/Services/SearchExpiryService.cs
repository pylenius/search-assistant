using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using SearchAssistant.Api.Realtime;
using SearchAssistant.Infrastructure.Persistence;

namespace SearchAssistant.Api.Services;

// Background sweep that purges searches past their ExpiresAt. Cascades to
// participants/areas/paths/positions via FK ON DELETE CASCADE.
public class SearchExpiryService(IServiceProvider sp, ILogger<SearchExpiryService> log)
    : BackgroundService
{
    private static readonly TimeSpan PollInterval = TimeSpan.FromMinutes(5);

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        // Run once shortly after startup, then on the interval.
        await Task.Delay(TimeSpan.FromSeconds(10), ct);

        while (!ct.IsCancellationRequested)
        {
            try
            {
                await SweepAsync(ct);
            }
            catch (OperationCanceledException) { break; }
            catch (Exception ex)
            {
                log.LogWarning(ex, "expiry sweep failed");
            }
            try { await Task.Delay(PollInterval, ct); }
            catch (OperationCanceledException) { break; }
        }
    }

    private async Task SweepAsync(CancellationToken ct)
    {
        await using var scope = sp.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var hub = scope.ServiceProvider.GetRequiredService<IHubContext<SearchHub, ISearchClient>>();

        var now = DateTimeOffset.UtcNow;
        var expired = await db.Searches
            .Where(s => s.ExpiresAt != null && s.ExpiresAt < now)
            .Select(s => new { s.Id, s.Slug })
            .ToListAsync(ct);

        if (expired.Count == 0) return;

        foreach (var s in expired)
        {
            // Best-effort notify any still-connected clients.
            try { await hub.Clients.Group(SearchHub.GroupNameFor(s.Id)).SearchEnded(s.Slug); }
            catch (Exception ex) { log.LogDebug(ex, "notify SearchEnded {Slug} failed", s.Slug); }
        }

        var deleted = await db.Searches
            .Where(s => s.ExpiresAt != null && s.ExpiresAt < now)
            .ExecuteDeleteAsync(ct);

        log.LogInformation("expired {Count} searches", deleted);
    }
}
