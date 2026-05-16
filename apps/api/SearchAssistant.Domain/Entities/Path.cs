using NetTopologySuite.Geometries;

namespace SearchAssistant.Domain.Entities;

public class Path
{
    public Guid Id { get; set; }
    public Guid SearchId { get; set; }
    public Search Search { get; set; } = null!;
    public Guid ParticipantId { get; set; }
    public Participant Participant { get; set; } = null!;

    public LineString Geometry { get; set; } = null!;
    public DateTimeOffset StartedAt { get; set; }
    public DateTimeOffset? EndedAt { get; set; }
}
