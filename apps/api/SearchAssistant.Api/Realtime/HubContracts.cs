using SearchAssistant.Api.Contracts;

namespace SearchAssistant.Api.Realtime;

public record JoinHubResult(Guid ParticipantId, Guid SearchId);

public record PositionUpdateDto(
    Guid ParticipantId,
    double Lng,
    double Lat,
    double AccuracyMeters,
    double? HeadingDegrees,
    DateTimeOffset RecordedAt);

public record SearchUpdatedDto(string Title, DateTimeOffset? ExpiresAt);

public interface ISearchClient
{
    Task ParticipantJoined(ParticipantDto participant);

    /// Disconnected, but still part of the search — they may well come back.
    Task ParticipantLeft(Guid participantId);

    /// Removed by the owner: gone for good, along with everything they drew.
    /// Distinct from <see cref="ParticipantLeft"/> because the two want
    /// opposite handling — one keeps the name in the list, the other erases it.
    Task ParticipantRemoved(Guid participantId);

    Task PositionUpdated(PositionUpdateDto update);
    Task AreaAdded(AreaDto area);
    Task AreaRemoved(Guid areaId);
    Task PathStarted(PathDto path);
    Task PathUpdated(PathDto path);
    Task PathFinalized(Guid pathId);

    /// The path is gone from the server. `PathFinalized` won't do here: a
    /// finalized path is still drawn, so a client told the wrong one keeps a
    /// deleted trail on screen until the next reload.
    Task PathRemoved(Guid pathId);

    Task SearchUpdated(SearchUpdatedDto update);
    Task SearchEnded(string slug);
}
