namespace SearchAssistant.Domain.Entities;

public class Participant
{
    public Guid Id { get; set; }
    public Guid SearchId { get; set; }
    public Search Search { get; set; } = null!;

    public string DisplayName { get; set; } = null!;
    public string Color { get; set; } = null!;
    public string SessionToken { get; set; } = null!;
    public DateTimeOffset JoinedAt { get; set; }
    public DateTimeOffset LastSeenAt { get; set; }

    public Position? Position { get; set; }
    public List<Path> Paths { get; set; } = new();
}
