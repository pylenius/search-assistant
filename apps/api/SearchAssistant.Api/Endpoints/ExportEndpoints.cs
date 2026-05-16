using System.Globalization;
using System.Text;
using System.Xml.Linq;
using Microsoft.EntityFrameworkCore;
using SearchAssistant.Domain.Entities;
using SearchAssistant.Infrastructure.Persistence;

namespace SearchAssistant.Api.Endpoints;

public static class ExportEndpoints
{
    private static readonly XNamespace Gpx = "http://www.topografix.com/GPX/1/1";

    public static IEndpointRouteBuilder MapExportEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/searches/{slug}/export.gpx", ExportGpx);
        return app;
    }

    private static async Task<IResult> ExportGpx(string slug, AppDbContext db, CancellationToken ct)
    {
        var search = await db.Searches
            .AsNoTracking()
            .Include(s => s.Participants)
            .Include(s => s.Areas)
            .Include(s => s.Paths)
            .FirstOrDefaultAsync(s => s.Slug == slug, ct);
        if (search is null) return Results.NotFound();

        var participantsById = search.Participants.ToDictionary(p => p.Id);

        var root = new XElement(Gpx + "gpx",
            new XAttribute("version", "1.1"),
            new XAttribute("creator", "Search Assistant"),
            new XElement(Gpx + "metadata",
                new XElement(Gpx + "name", search.Title),
                new XElement(Gpx + "time", search.CreatedAt.UtcDateTime.ToString("o", CultureInfo.InvariantCulture))));

        foreach (var area in search.Areas.OrderBy(a => a.CreatedAt))
        {
            participantsById.TryGetValue(area.CreatedByParticipantId, out var creator);
            root.Add(BuildAreaTrk(area, creator));
        }

        foreach (var path in search.Paths.OrderBy(p => p.StartedAt))
        {
            participantsById.TryGetValue(path.ParticipantId, out var creator);
            root.Add(BuildPathTrk(path, creator));
        }

        var doc = new XDocument(new XDeclaration("1.0", "utf-8", null), root);
        var bytes = Encoding.UTF8.GetBytes(doc.Declaration + "\n" + doc);
        return Results.File(bytes, "application/gpx+xml", $"{slug}.gpx");
    }

    private static XElement BuildAreaTrk(SearchArea area, Participant? creator)
    {
        var ring = area.Geometry.ExteriorRing.Coordinates;
        return new XElement(Gpx + "trk",
            new XElement(Gpx + "name", $"Area · {creator?.DisplayName ?? "unknown"}"),
            new XElement(Gpx + "type", "search-area"),
            new XElement(Gpx + "trkseg",
                ring.Select(c => Pt(c.Y, c.X))));
    }

    private static XElement BuildPathTrk(Domain.Entities.Path path, Participant? creator)
    {
        return new XElement(Gpx + "trk",
            new XElement(Gpx + "name", $"Path · {creator?.DisplayName ?? "unknown"}"),
            new XElement(Gpx + "type", "path"),
            new XElement(Gpx + "trkseg",
                path.Geometry.Coordinates.Select(c => Pt(c.Y, c.X, path.StartedAt))));
    }

    private static XElement Pt(double lat, double lon, DateTimeOffset? time = null)
    {
        var el = new XElement(Gpx + "trkpt",
            new XAttribute("lat", lat.ToString("G15", CultureInfo.InvariantCulture)),
            new XAttribute("lon", lon.ToString("G15", CultureInfo.InvariantCulture)));
        if (time is { } t)
        {
            el.Add(new XElement(Gpx + "time", t.UtcDateTime.ToString("o", CultureInfo.InvariantCulture)));
        }
        return el;
    }
}
