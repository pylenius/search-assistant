using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;
using SearchAssistant.Api.Auth;
using SearchAssistant.Api.Contracts;
using SearchAssistant.Api.Realtime;
using SearchAssistant.Domain.Entities;
using SearchAssistant.Infrastructure.Persistence;

namespace SearchAssistant.Api.Endpoints;

public static class AreaEndpoints
{
    public record AddAreaRequest(Polygon Geometry);

    public static IEndpointRouteBuilder MapAreaEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/searches/{slug}/areas");
        group.MapPost("/", AddArea).RequireParticipant();
        group.MapDelete("/{id:guid}", RemoveArea).RequireParticipant();
        return app;
    }

    private static async Task<IResult> AddArea(
        string slug,
        AddAreaRequest req,
        AppDbContext db,
        IHubContext<SearchHub, ISearchClient> hub,
        HttpContext http,
        CancellationToken ct)
    {
        if (req.Geometry is null || req.Geometry.IsEmpty)
        {
            return Results.ValidationProblem(new Dictionary<string, string[]>
            {
                ["geometry"] = ["Polygon geometry is required."],
            });
        }

        var participant = http.GetParticipant();
        var geometry = req.Geometry;
        SetSrid4326(geometry);

        var area = new SearchArea
        {
            Id = Guid.NewGuid(),
            SearchId = participant.SearchId,
            CreatedByParticipantId = participant.Id,
            Geometry = geometry,
            CreatedAt = DateTimeOffset.UtcNow,
        };
        db.Areas.Add(area);
        await db.SaveChangesAsync(ct);

        var dto = new AreaDto(area.Id, area.CreatedByParticipantId, area.CreatedAt, area.Geometry);
        await hub.Clients
            .Group(SearchHub.GroupNameFor(participant.SearchId))
            .AreaAdded(dto);

        return Results.Created($"/api/searches/{slug}/areas/{area.Id}", dto);
    }

    private static async Task<IResult> RemoveArea(
        string slug,
        Guid id,
        AppDbContext db,
        IHubContext<SearchHub, ISearchClient> hub,
        HttpContext http,
        CancellationToken ct)
    {
        var participant = http.GetParticipant();
        var area = await db.Areas
            .FirstOrDefaultAsync(a => a.Id == id && a.SearchId == participant.SearchId, ct);
        if (area is null) return Results.NotFound();

        db.Areas.Remove(area);
        await db.SaveChangesAsync(ct);

        await hub.Clients
            .Group(SearchHub.GroupNameFor(participant.SearchId))
            .AreaRemoved(id);

        return Results.NoContent();
    }

    private static void SetSrid4326(Geometry g)
    {
        g.SRID = 4326;
        if (g is Polygon p)
        {
            p.ExteriorRing.SRID = 4326;
            foreach (var r in p.InteriorRings) r.SRID = 4326;
        }
    }
}
