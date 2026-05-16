using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;
using SearchAssistant.Api.Auth;
using SearchAssistant.Api.Common;
using SearchAssistant.Api.Contracts;
using SearchAssistant.Domain.Entities;
using SearchAssistant.Infrastructure.Persistence;

namespace SearchAssistant.Api.Endpoints;

public static class SearchEndpoints
{
    private const int MaxTitleLength = 200;
    private const int MaxDisplayNameLength = 60;
    private const int SlugCollisionRetries = 5;
    private static readonly TimeSpan DefaultLifetime = TimeSpan.FromDays(7);

    public static IEndpointRouteBuilder MapSearchEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/searches");

        group.MapPost("/", CreateSearch);
        group.MapGet("/{slug}", GetSearch);
        group.MapPost("/{slug}/join", JoinSearch);
        group.MapGet("/{slug}/me", GetMe).RequireParticipant();

        return app;
    }

    private static IResult GetMe(HttpContext http)
    {
        var p = http.GetParticipant();
        // Position is not eagerly loaded by the filter; we return null here
        // because /me is only used to populate the local "(you)" indicator.
        return Results.Ok(new ParticipantDto(
            p.Id, p.DisplayName, p.Color, p.JoinedAt, p.LastSeenAt, null));
    }

    private static async Task<IResult> CreateSearch(
        CreateSearchRequest req,
        AppDbContext db,
        HttpContext http,
        CancellationToken ct)
    {
        var title = (req.Title ?? string.Empty).Trim();
        if (title.Length == 0 || title.Length > MaxTitleLength)
        {
            return Results.ValidationProblem(new Dictionary<string, string[]>
            {
                ["title"] = [$"Title must be 1–{MaxTitleLength} chars."]
            });
        }

        Point? center = null;
        if (req.CenterLng is double lng && req.CenterLat is double lat)
        {
            center = new Point(lng, lat) { SRID = 4326 };
        }

        string slug = await GenerateUniqueSlug(db, ct);

        var now = DateTimeOffset.UtcNow;
        var search = new Search
        {
            Id = Guid.NewGuid(),
            Slug = slug,
            Title = title,
            CreatedAt = now,
            ExpiresAt = now + DefaultLifetime,
            OwnerToken = TokenGenerator.Generate(),
            Center = center,
            DefaultZoom = req.Zoom ?? 13,
        };

        db.Searches.Add(search);
        await db.SaveChangesAsync(ct);

        var joinUrl = BuildJoinUrl(http, slug);
        return Results.Created($"/api/searches/{slug}",
            new CreateSearchResponse(slug, search.OwnerToken, joinUrl));
    }

    private static async Task<IResult> GetSearch(
        string slug,
        AppDbContext db,
        CancellationToken ct)
    {
        var search = await db.Searches
            .AsNoTracking()
            .Include(s => s.Participants).ThenInclude(p => p.Position)
            .Include(s => s.Areas)
            .Include(s => s.Paths)
            .FirstOrDefaultAsync(s => s.Slug == slug, ct);

        if (search is null)
        {
            return Results.NotFound();
        }

        var dto = new SearchSnapshotDto(
            search.Slug,
            search.Title,
            search.CreatedAt,
            search.ExpiresAt,
            search.Center,
            search.DefaultZoom,
            search.Participants
                .OrderBy(p => p.JoinedAt)
                .Select(p => new ParticipantDto(
                    p.Id, p.DisplayName, p.Color, p.JoinedAt, p.LastSeenAt, p.Position?.Location))
                .ToList(),
            search.Areas
                .OrderBy(a => a.CreatedAt)
                .Select(a => new AreaDto(a.Id, a.CreatedByParticipantId, a.CreatedAt, a.Geometry, a.Title, a.Color))
                .ToList(),
            search.Paths
                .OrderBy(p => p.StartedAt)
                .Select(p => new PathDto(p.Id, p.ParticipantId, p.StartedAt, p.EndedAt, p.Geometry))
                .ToList());

        return Results.Ok(dto);
    }

    private static async Task<IResult> JoinSearch(
        string slug,
        JoinRequest req,
        AppDbContext db,
        CancellationToken ct)
    {
        var displayName = (req.DisplayName ?? string.Empty).Trim();
        if (displayName.Length == 0 || displayName.Length > MaxDisplayNameLength)
        {
            return Results.ValidationProblem(new Dictionary<string, string[]>
            {
                ["displayName"] = [$"DisplayName must be 1–{MaxDisplayNameLength} chars."]
            });
        }

        var search = await db.Searches.FirstOrDefaultAsync(s => s.Slug == slug, ct);
        if (search is null)
        {
            return Results.NotFound();
        }

        var participantCount = await db.Participants.CountAsync(p => p.SearchId == search.Id, ct);
        var now = DateTimeOffset.UtcNow;

        var participant = new Participant
        {
            Id = Guid.NewGuid(),
            SearchId = search.Id,
            DisplayName = displayName,
            Color = ColorPalette.PickForIndex(participantCount),
            SessionToken = TokenGenerator.Generate(),
            JoinedAt = now,
            LastSeenAt = now,
        };

        db.Participants.Add(participant);
        await db.SaveChangesAsync(ct);

        return Results.Ok(new JoinResponse(participant.Id, participant.SessionToken, participant.Color));
    }

    private static async Task<string> GenerateUniqueSlug(AppDbContext db, CancellationToken ct)
    {
        for (var i = 0; i < SlugCollisionRetries; i++)
        {
            var candidate = SlugGenerator.Generate();
            var taken = await db.Searches.AnyAsync(s => s.Slug == candidate, ct);
            if (!taken)
            {
                return candidate;
            }
        }
        throw new InvalidOperationException("Could not allocate a unique slug after retries.");
    }

    private static string BuildJoinUrl(HttpContext http, string slug)
    {
        var req = http.Request;
        return $"{req.Scheme}://{req.Host}/s/{slug}";
    }
}
