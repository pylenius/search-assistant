using NetTopologySuite.Geometries;

namespace SearchAssistant.Domain.Entities;

public class Search
{
    public Guid Id { get; set; }
    public string Slug { get; set; } = null!;
    public string Title { get; set; } = null!;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? ExpiresAt { get; set; }
    public string OwnerToken { get; set; } = null!;
    public Point? Center { get; set; }
    public int DefaultZoom { get; set; } = 13;

    public List<Participant> Participants { get; set; } = new();
    public List<SearchArea> Areas { get; set; } = new();
    public List<Path> Paths { get; set; } = new();
}
