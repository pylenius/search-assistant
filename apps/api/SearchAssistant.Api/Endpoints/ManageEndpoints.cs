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
            await hub.Clients.Group(group).PathFinalized(id);
        }

        return Results.Ok(new { cleared = pathIds.Count });
    }
}
