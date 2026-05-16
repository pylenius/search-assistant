using NetTopologySuite.Geometries;

namespace SearchAssistant.Domain.Entities;

public class PositionHistory
{
    public long Id { get; set; }
    public Guid ParticipantId { get; set; }
    public Participant Participant { get; set; } = null!;

    public Point Location { get; set; } = null!;
    public DateTimeOffset RecordedAt { get; set; }
}
