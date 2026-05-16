using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SearchAssistant.Domain.Entities;

namespace SearchAssistant.Infrastructure.Persistence.Configurations;

public class SearchAreaConfiguration : IEntityTypeConfiguration<SearchArea>
{
    public void Configure(EntityTypeBuilder<SearchArea> e)
    {
        e.ToTable("search_areas");
        e.HasKey(x => x.Id);
        e.Property(x => x.Geometry).HasColumnType("geography (Polygon, 4326)").IsRequired();
        e.HasIndex(x => x.Geometry).HasMethod("GIST");
        e.HasIndex(x => x.SearchId);
        e.Property(x => x.Title).HasMaxLength(80);
        e.Property(x => x.Color).HasMaxLength(9);

        e.HasOne(x => x.Search)
            .WithMany(s => s.Areas)
            .HasForeignKey(x => x.SearchId)
            .OnDelete(DeleteBehavior.Cascade);

        e.HasOne(x => x.CreatedBy)
            .WithMany()
            .HasForeignKey(x => x.CreatedByParticipantId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
