using NetTopologySuite.Geometries;

namespace SearchAssistant.Api.Contracts;

public record CreateSearchRequest(
    string Title,
    double? CenterLng,
    double? CenterLat,
    int? Zoom);

public record CreateSearchResponse(
    string Slug,
    string OwnerToken,
    string JoinUrl);

public record JoinRequest(string DisplayName);

public record JoinResponse(
    Guid ParticipantId,
    string SessionToken,
    string Color);

public record ParticipantDto(
    Guid Id,
    string DisplayName,
    string Color,
    DateTimeOffset JoinedAt,
    DateTimeOffset LastSeenAt,
    Point? LastPosition);

public record AreaDto(
    Guid Id,
    Guid CreatedByParticipantId,
    DateTimeOffset CreatedAt,
    Polygon Geometry);

public record PathDto(
    Guid Id,
    Guid ParticipantId,
    DateTimeOffset StartedAt,
    DateTimeOffset? EndedAt,
    LineString Geometry);

public record SearchSnapshotDto(
    string Slug,
    string Title,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ExpiresAt,
    Point? Center,
    int DefaultZoom,
    IReadOnlyList<ParticipantDto> Participants,
    IReadOnlyList<AreaDto> Areas,
    IReadOnlyList<PathDto> Paths);
