using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using SearchAssistant.Api.Auth;
using SearchAssistant.Api.Realtime;
using SearchAssistant.Infrastructure.Persistence;

namespace SearchAssistant.Api.Endpoints;

public static class ManageEndpoints
{
    public record UpdateSearchRequest(string? Title, DateTimeOffset? ExpiresAt);

    public static IEndpointRouteBuilder MapManageEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPatch("/api/searches/{slug}", UpdateSearch).RequireOwner();
        app.MapDelete("/api/searches/{slug}", DeleteSearch).RequireOwner();
        app.MapDelete("/api/searches/{slug}/paths", ClearPaths).RequireOwner();
        app.MapDelete("/api/searches/{slug}/participants/{id:guid}", RemoveParticipant).RequireOwner();
        return app;
    }

    private static async Task<IResult> UpdateSearch(
        string slug,
        UpdateSearchRequest req,
        AppDbContext db,
        IHubContext<SearchHub, ISearchClient> hub,
        HttpContext http,
        CancellationToken ct)
    {
        var search = http.GetSearch();

        if (req.Title is not null)
        {
            var t = req.Title.Trim();
            if (t.Length is < 1 or > 200)
            {
                return Results.ValidationProblem(new Dictionary<string, string[]>
                {
                    ["title"] = ["Title must be 1–200 chars."]
                });
            }
            search.Title = t;
        }

        if (req.ExpiresAt is not null)
        {
            search.ExpiresAt = req.ExpiresAt;
        }

        await db.SaveChangesAsync(ct);

        await hub.Clients
            .Group(SearchHub.GroupNameFor(search.Id))
            .SearchUpdated(new SearchUpdatedDto(search.Title, search.ExpiresAt));

        return Results.Ok(new { search.Title, search.ExpiresAt });
    }

    private static async Task<IResult> DeleteSearch(
        string slug,
        AppDbContext db,
        IHubContext<SearchHub, ISearchClient> hub,
        HttpContext http,
        CancellationToken ct)
    {
        var search = http.GetSearch();
        var groupName = SearchHub.GroupNameFor(search.Id);

        // Broadcast first so currently-connected clients are told to navigate away;
        // then delete. Order matters because the group disappears once disconnects fire.
        await hub.Clients.Group(groupName).SearchEnded(search.Slug);

        db.Searches.Remove(search);
        await db.SaveChangesAsync(ct);

        return Results.NoContent();
    }

    private static async Task<IResult> ClearPaths(
        string slug,
        AppDbContext db,
        IHubContext<SearchHub, ISearchClient> hub,
        HttpContext http,
        CancellationToken ct)
    {
        var search = http.GetSearch();
        var pathIds = await db.Paths
            .Where(p => p.SearchId == search.Id)
            .Select(p => p.Id)
            .ToListAsync(ct);

        if (pathIds.Count == 0) return Results.NoContent();

        await db.Paths.Where(p => p.SearchId == search.Id).ExecuteDeleteAsync(ct);

        var group = SearchHub.GroupNameFor(search.Id);
        foreach (var id in pathIds)
        {
            await hub.Clients.Group(group).PathRemoved(id);
        }

        return Results.Ok(new { cleared = pathIds.Count });
    }

    /// Removes a person from the search along with everything they produced:
    /// their trails, the areas they drew, their live position and its history.
    ///
    /// This is the owner's tool for a mis-join — someone who joined the wrong
    /// search, or a duplicate from a phone that lost its session token — so it
    /// erases rather than tombstones. Their session token stops resolving the
    /// moment the row goes, which is what ejects their device.
    private static async Task<IResult> RemoveParticipant(
        string slug,
        Guid id,
        AppDbContext db,
        IHubContext<SearchHub, ISearchClient> hub,
        HttpContext http,
        CancellationToken ct)
    {
        var search = http.GetSearch();

        var participant = await db.Participants
            .FirstOrDefaultAsync(p => p.Id == id && p.SearchId == search.Id, ct);
        if (participant is null) return Results.NotFound();

        var pathIds = await db.Paths
            .Where(p => p.ParticipantId == id)
            .Select(p => p.Id)
            .ToListAsync(ct);
        var areaIds = await db.Areas
            .Where(a => a.CreatedByParticipantId == id)
            .Select(a => a.Id)
            .ToListAsync(ct);

        // Areas must go first and explicitly: their creator FK is Restrict, so
        // leaving them would fail the participant delete outright. Paths and
        // positions would cascade, but they're deleted here too so the ids are
        // known before the rows vanish — clients need them to drop the shapes.
        if (areaIds.Count > 0)
        {
            await db.Areas.Where(a => a.CreatedByParticipantId == id).ExecuteDeleteAsync(ct);
        }
        if (pathIds.Count > 0)
        {
            await db.Paths.Where(p => p.ParticipantId == id).ExecuteDeleteAsync(ct);
        }

        db.Participants.Remove(participant);
        await db.SaveChangesAsync(ct);

        var group = SearchHub.GroupNameFor(search.Id);
        foreach (var areaId in areaIds)
        {
            await hub.Clients.Group(group).AreaRemoved(areaId);
        }
        foreach (var pathId in pathIds)
        {
            await hub.Clients.Group(group).PathRemoved(pathId);
        }
        await hub.Clients.Group(group).ParticipantRemoved(id);

        return Results.Ok(new { removedPaths = pathIds.Count, removedAreas = areaIds.Count });
    }
}
