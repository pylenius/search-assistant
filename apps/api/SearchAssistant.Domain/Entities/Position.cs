using NetTopologySuite.Geometries;

namespace SearchAssistant.Domain.Entities;

public class Position
{
    public Guid ParticipantId { get; set; }
    public Participant Participant { get; set; } = null!;

    public Point Location { get; set; } = null!;
    public double AccuracyMeters { get; set; }
    public double? HeadingDegrees { get; set; }
    public DateTimeOffset RecordedAt { get; set; }
}
