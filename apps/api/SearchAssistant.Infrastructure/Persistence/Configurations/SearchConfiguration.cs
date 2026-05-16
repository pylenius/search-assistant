using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SearchAssistant.Domain.Entities;

namespace SearchAssistant.Infrastructure.Persistence.Configurations;

public class SearchConfiguration : IEntityTypeConfiguration<Search>
{
    public void Configure(EntityTypeBuilder<Search> e)
    {
        e.ToTable("searches");
        e.HasKey(x => x.Id);
        e.Property(x => x.Slug).HasMaxLength(32).IsRequired();
        e.HasIndex(x => x.Slug).IsUnique();
        e.Property(x => x.Title).HasMaxLength(200).IsRequired();
        e.Property(x => x.OwnerToken).HasMaxLength(64).IsRequired();
        e.Property(x => x.Center).HasColumnType("geography (Point, 4326)");
        e.Property(x => x.DefaultZoom);
        e.Property(x => x.CreatedAt);
        e.Property(x => x.ExpiresAt);
    }
}
