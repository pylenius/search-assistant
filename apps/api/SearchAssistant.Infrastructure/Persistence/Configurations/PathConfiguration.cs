using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SearchAssistant.Domain.Entities;

namespace SearchAssistant.Infrastructure.Persistence.Configurations;

public class PathConfiguration : IEntityTypeConfiguration<Domain.Entities.Path>
{
    public void Configure(EntityTypeBuilder<Domain.Entities.Path> e)
    {
        e.ToTable("paths");
        e.HasKey(x => x.Id);
        e.Property(x => x.Geometry).HasColumnType("geography (LineString, 4326)").IsRequired();
        e.HasIndex(x => x.Geometry).HasMethod("GIST");
        e.HasIndex(x => x.SearchId);
        e.HasIndex(x => x.ParticipantId);

        e.HasOne(x => x.Search)
            .WithMany(s => s.Paths)
            .HasForeignKey(x => x.SearchId)
            .OnDelete(DeleteBehavior.Cascade);

        e.HasOne(x => x.Participant)
            .WithMany(p => p.Paths)
            .HasForeignKey(x => x.ParticipantId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
