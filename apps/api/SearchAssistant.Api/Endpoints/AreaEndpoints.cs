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
    public record AddAreaRequest(Polygon Geometry, string? Title, string? Color);

    private static readonly System.Text.RegularExpressions.Regex HexColorRe =
        new("^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$");

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

        var title = req.Title?.Trim();
        if (title?.Length == 0) title = null;
        if (title is { Length: > 80 })
        {
            return Results.ValidationProblem(new Dictionary<string, string[]>
            {
                ["title"] = ["Title must be 1–80 chars."],
            });
        }

        var color = req.Color?.Trim();
        if (color?.Length == 0) color = null;
        if (color is not null && !HexColorRe.IsMatch(color))
        {
            return Results.ValidationProblem(new Dictionary<string, string[]>
            {
                ["color"] = ["Color must be a hex string like #aabbcc."],
            });
        }

        var area = new SearchArea
        {
            Id = Guid.NewGuid(),
            SearchId = participant.SearchId,
            CreatedByParticipantId = participant.Id,
            Geometry = geometry,
            CreatedAt = DateTimeOffset.UtcNow,
            Title = title,
            Color = color,
        };
        db.Areas.Add(area);
        await db.SaveChangesAsync(ct);

        var dto = new AreaDto(area.Id, area.CreatedByParticipantId, area.CreatedAt, area.Geometry, area.Title, area.Color);
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
