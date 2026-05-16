using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SearchAssistant.Domain.Entities;

namespace SearchAssistant.Infrastructure.Persistence.Configurations;

public class PositionConfiguration : IEntityTypeConfiguration<Position>
{
    public void Configure(EntityTypeBuilder<Position> e)
    {
        e.ToTable("positions");
        e.HasKey(x => x.ParticipantId);
        e.Property(x => x.Location).HasColumnType("geography (Point, 4326)").IsRequired();
        e.HasIndex(x => x.Location).HasMethod("GIST");

        e.HasOne(x => x.Participant)
            .WithOne(p => p.Position!)
            .HasForeignKey<Position>(x => x.ParticipantId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
