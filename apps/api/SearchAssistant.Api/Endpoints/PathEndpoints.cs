using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;
using NetTopologySuite.Simplify;
using SearchAssistant.Api.Auth;
using SearchAssistant.Api.Contracts;
using SearchAssistant.Api.Realtime;
using SearchAssistant.Domain.Entities;
using SearchAssistant.Infrastructure.Persistence;

namespace SearchAssistant.Api.Endpoints;

public static class PathEndpoints
{
    public record StartPathRequest(double[][] Points);
    public record UpdatePathRequest(double[][]? Points, bool? Finalize);

    // Tolerances are in degrees (geometry treated as planar for simplification).
    // Roughly: 0.00003° ≈ 3m at mid-latitudes; 0.00001° ≈ 1m. Good enough for casual paths.
    private const double SimplifyToleranceRecording = 0.00003;
    private const double SimplifyToleranceFinal = 0.00001;

    public static IEndpointRouteBuilder MapPathEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/searches/{slug}/paths");
        group.MapPost("/", StartPath).RequireParticipant();
        group.MapPatch("/{id:guid}", UpdatePath).RequireParticipant();
        return app;
    }

    private static async Task<IResult> StartPath(
        string slug,
        StartPathRequest req,
        AppDbContext db,
        IHubContext<SearchHub, ISearchClient> hub,
        HttpContext http,
        CancellationToken ct)
    {
        if (req.Points is null || req.Points.Length < 2)
        {
            return Results.ValidationProblem(new Dictionary<string, string[]>
            {
                ["points"] = ["At least 2 points required to start a path."],
            });
        }

        var participant = http.GetParticipant();
        var line = BuildLineString(req.Points);
        line.SRID = 4326;

        var path = new Domain.Entities.Path
        {
            Id = Guid.NewGuid(),
            SearchId = participant.SearchId,
            ParticipantId = participant.Id,
            Geometry = line,
            StartedAt = DateTimeOffset.UtcNow,
            EndedAt = null,
        };
        db.Paths.Add(path);
        await db.SaveChangesAsync(ct);

        var dto = ToDto(path);
        await hub.Clients
            .Group(SearchHub.GroupNameFor(participant.SearchId))
            .PathStarted(dto);

        return Results.Created($"/api/searches/{slug}/paths/{path.Id}", dto);
    }

    private static async Task<IResult> UpdatePath(
        string slug,
        Guid id,
        UpdatePathRequest req,
        AppDbContext db,
        IHubContext<SearchHub, ISearchClient> hub,
        HttpContext http,
        CancellationToken ct)
    {
        var participant = http.GetParticipant();
        var path = await db.Paths
            .FirstOrDefaultAsync(p => p.Id == id && p.ParticipantId == participant.Id, ct);
        if (path is null) return Results.NotFound();
        if (path.EndedAt is not null) return Results.Conflict("Path already finalized.");

        var changed = false;

        if (req.Points is { Length: > 0 })
        {
            var existing = path.Geometry.Coordinates;
            var added = req.Points.Select(p => new Coordinate(p[0], p[1])).ToArray();
            var combined = existing.Concat(added).ToArray();
            var line = new LineString(combined) { SRID = 4326 };
            path.Geometry = SimplifyLine(line, SimplifyToleranceRecording);
            changed = true;
        }

        if (req.Finalize == true)
        {
            path.Geometry = SimplifyLine(path.Geometry, SimplifyToleranceFinal);
            path.EndedAt = DateTimeOffset.UtcNow;
            changed = true;
        }

        if (!changed) return Results.NoContent();

        await db.SaveChangesAsync(ct);

        var dto = ToDto(path);
        var group = SearchHub.GroupNameFor(participant.SearchId);
        if (req.Finalize == true)
        {
            await hub.Clients.Group(group).PathFinalized(path.Id);
        }
        else
        {
            await hub.Clients.Group(group).PathUpdated(dto);
        }
        return Results.Ok(dto);
    }

    private static LineString BuildLineString(double[][] points)
    {
        var coords = points.Select(p => new Coordinate(p[0], p[1])).ToArray();
        return new LineString(coords);
    }

    private static LineString SimplifyLine(LineString line, double tolerance)
    {
        if (line.NumPoints <= 2) { line.SRID = 4326; return line; }
        var simplified = (LineString)DouglasPeuckerSimplifier.Simplify(line, tolerance);
        simplified.SRID = 4326;
        return simplified;
    }

    private static PathDto ToDto(Domain.Entities.Path p)
        => new(p.Id, p.ParticipantId, p.StartedAt, p.EndedAt, p.Geometry);
}
