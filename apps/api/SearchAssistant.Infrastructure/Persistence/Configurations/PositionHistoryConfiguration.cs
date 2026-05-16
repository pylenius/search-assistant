using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SearchAssistant.Domain.Entities;

namespace SearchAssistant.Infrastructure.Persistence.Configurations;

public class PositionHistoryConfiguration : IEntityTypeConfiguration<PositionHistory>
{
    public void Configure(EntityTypeBuilder<PositionHistory> e)
    {
        e.ToTable("position_history");
        e.HasKey(x => x.Id);
        e.Property(x => x.Location).HasColumnType("geography (Point, 4326)").IsRequired();
        e.HasIndex(x => new { x.ParticipantId, x.RecordedAt });

        e.HasOne(x => x.Participant)
            .WithMany()
            .HasForeignKey(x => x.ParticipantId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
