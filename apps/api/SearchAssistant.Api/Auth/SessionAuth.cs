using Microsoft.EntityFrameworkCore;
using SearchAssistant.Domain.Entities;
using SearchAssistant.Infrastructure.Persistence;

namespace SearchAssistant.Api.Auth;

public static class SessionAuth
{
    public const string SessionHeader = "X-Session-Token";
    public const string OwnerHeader = "X-Owner-Token";
    public const string ParticipantItem = "participant";
    public const string SearchItem = "search";

    public static Participant GetParticipant(this HttpContext ctx)
    {
        if (ctx.Items[ParticipantItem] is not Participant p)
        {
            throw new InvalidOperationException(
                "No participant on the request. Did you forget RequireParticipant() on the endpoint?");
        }
        return p;
    }

    public static Search GetSearch(this HttpContext ctx)
    {
        if (ctx.Items[SearchItem] is not Search s)
        {
            throw new InvalidOperationException(
                "No search on the request. Did you forget RequireOwner() on the endpoint?");
        }
        return s;
    }

    public static RouteHandlerBuilder RequireParticipant(this RouteHandlerBuilder b)
        => b.AddEndpointFilter<RequireParticipantFilter>();

    public static RouteHandlerBuilder RequireOwner(this RouteHandlerBuilder b)
        => b.AddEndpointFilter<RequireOwnerFilter>();
}

public class RequireParticipantFilter(AppDbContext db) : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var http = context.HttpContext;

        if (!http.Request.Headers.TryGetValue(SessionAuth.SessionHeader, out var tokenValues)
            || tokenValues.Count == 0
            || string.IsNullOrWhiteSpace(tokenValues[0]))
        {
            return Results.Unauthorized();
        }
        var token = tokenValues[0]!;

        if (http.GetRouteValue("slug") is not string slug)
        {
            return Results.Problem("Route is missing required {slug} parameter.", statusCode: 500);
        }

        var participant = await db.Participants
            .Include(p => p.Search)
            .FirstOrDefaultAsync(p => p.SessionToken == token);

        if (participant is null || participant.Search.Slug != slug)
        {
            return Results.Unauthorized();
        }

        participant.LastSeenAt = DateTimeOffset.UtcNow;
        await db.SaveChangesAsync(http.RequestAborted);

        http.Items[SessionAuth.ParticipantItem] = participant;
        return await next(context);
    }
}

public class RequireOwnerFilter(AppDbContext db) : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var http = context.HttpContext;

        if (!http.Request.Headers.TryGetValue(SessionAuth.OwnerHeader, out var tokenValues)
            || tokenValues.Count == 0
            || string.IsNullOrWhiteSpace(tokenValues[0]))
        {
            return Results.Unauthorized();
        }
        var token = tokenValues[0]!;

        if (http.GetRouteValue("slug") is not string slug)
        {
            return Results.Problem("Route is missing required {slug} parameter.", statusCode: 500);
        }

        var search = await db.Searches
            .FirstOrDefaultAsync(s => s.Slug == slug);
        if (search is null || !string.Equals(search.OwnerToken, token, StringComparison.Ordinal))
        {
            return Results.Unauthorized();
        }

        http.Items[SessionAuth.SearchItem] = search;
        return await next(context);
    }
}
