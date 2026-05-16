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
    Task ParticipantLeft(Guid participantId);
    Task PositionUpdated(PositionUpdateDto update);
    Task AreaAdded(AreaDto area);
    Task AreaRemoved(Guid areaId);
    Task PathStarted(PathDto path);
    Task PathUpdated(PathDto path);
    Task PathFinalized(Guid pathId);
    Task SearchUpdated(SearchUpdatedDto update);
    Task SearchEnded(string slug);
}
