using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;
using SearchAssistant.Api.Contracts;
using SearchAssistant.Api.Services;
using SearchAssistant.Domain.Entities;
using SearchAssistant.Infrastructure.Persistence;

namespace SearchAssistant.Api.Realtime;

public class SearchHub(AppDbContext db, PositionRateLimiter rateLimiter) : Hub<ISearchClient>
{
    private const string ParticipantIdItemKey = "participantId";
    private const string SearchIdItemKey = "searchId";

    public async Task<JoinHubResult> JoinSearch(string slug, string sessionToken)
    {
        var participant = await db.Participants
            .Include(p => p.Search)
            .FirstOrDefaultAsync(p => p.SessionToken == sessionToken);

        if (participant is null || !string.Equals(participant.Search.Slug, slug, StringComparison.Ordinal))
        {
            throw new HubException("Invalid slug or session token.");
        }

        var group = GroupNameFor(participant.SearchId);
        await Groups.AddToGroupAsync(Context.ConnectionId, group);

        Context.Items[ParticipantIdItemKey] = participant.Id;
        Context.Items[SearchIdItemKey] = participant.SearchId;

        participant.LastSeenAt = DateTimeOffset.UtcNow;
        await db.SaveChangesAsync();

        await Clients.OthersInGroup(group).ParticipantJoined(ToDto(participant));

        return new JoinHubResult(participant.Id, participant.SearchId);
    }

    public async Task SendPosition(double lng, double lat, double accuracyMeters, double? headingDegrees)
    {
        if (Context.Items[ParticipantIdItemKey] is not Guid participantId
            || Context.Items[SearchIdItemKey] is not Guid searchId)
        {
            throw new HubException("Connection has not joined a search.");
        }

        // Server-side rate limit on top of the ~1/s client throttle.
        if (!rateLimiter.TryAccept(participantId)) return;

        var now = DateTimeOffset.UtcNow;
        var location = new Point(lng, lat) { SRID = 4326 };

        var existing = await db.Positions.FirstOrDefaultAsync(p => p.ParticipantId == participantId);
        if (existing is null)
        {
            db.Positions.Add(new Domain.Entities.Position
            {
                ParticipantId = participantId,
                Location = location,
                AccuracyMeters = accuracyMeters,
                HeadingDegrees = headingDegrees,
                RecordedAt = now,
            });
        }
        else
        {
            existing.Location = location;
            existing.AccuracyMeters = accuracyMeters;
            existing.HeadingDegrees = headingDegrees;
            existing.RecordedAt = now;
        }
        await db.SaveChangesAsync();

        var update = new PositionUpdateDto(
            participantId, lng, lat, accuracyMeters, headingDegrees, now);
        await Clients.Group(GroupNameFor(searchId)).PositionUpdated(update);
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        if (Context.Items[ParticipantIdItemKey] is Guid participantId
            && Context.Items[SearchIdItemKey] is Guid searchId)
        {
            await Clients.OthersInGroup(GroupNameFor(searchId)).ParticipantLeft(participantId);
        }
        await base.OnDisconnectedAsync(exception);
    }

    public static string GroupNameFor(Guid searchId) => $"search-{searchId}";

    private static ParticipantDto ToDto(Participant p) => new(
        p.Id, p.DisplayName, p.Color, p.JoinedAt, p.LastSeenAt, p.Position?.Location);
}
