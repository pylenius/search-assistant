using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SearchAssistant.Domain.Entities;

namespace SearchAssistant.Infrastructure.Persistence.Configurations;

public class ParticipantConfiguration : IEntityTypeConfiguration<Participant>
{
    public void Configure(EntityTypeBuilder<Participant> e)
    {
        e.ToTable("participants");
        e.HasKey(x => x.Id);
        e.Property(x => x.DisplayName).HasMaxLength(60).IsRequired();
        e.Property(x => x.Color).HasMaxLength(9).IsRequired();
        e.Property(x => x.SessionToken).HasMaxLength(64).IsRequired();
        e.HasIndex(x => x.SessionToken).IsUnique();
        e.HasIndex(x => x.SearchId);

        e.HasOne(x => x.Search)
            .WithMany(s => s.Participants)
            .HasForeignKey(x => x.SearchId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
