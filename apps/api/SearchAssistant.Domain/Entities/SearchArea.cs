using NetTopologySuite.Geometries;

namespace SearchAssistant.Domain.Entities;

public class SearchArea
{
    public Guid Id { get; set; }
    public Guid SearchId { get; set; }
    public Search Search { get; set; } = null!;

    public Polygon Geometry { get; set; } = null!;
    public Guid CreatedByParticipantId { get; set; }
    public Participant CreatedBy { get; set; } = null!;
    public DateTimeOffset CreatedAt { get; set; }

    public string? Title { get; set; }
    public string? Color { get; set; }
}
