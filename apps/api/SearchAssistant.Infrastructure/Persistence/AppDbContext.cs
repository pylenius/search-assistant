using Microsoft.EntityFrameworkCore;
using SearchAssistant.Domain.Entities;

namespace SearchAssistant.Infrastructure.Persistence;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<Search> Searches => Set<Search>();
    public DbSet<Participant> Participants => Set<Participant>();
    public DbSet<SearchArea> Areas => Set<SearchArea>();
    public DbSet<Domain.Entities.Path> Paths => Set<Domain.Entities.Path>();
    public DbSet<Position> Positions => Set<Position>();
    public DbSet<PositionHistory> PositionHistory => Set<PositionHistory>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasPostgresExtension("postgis");
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}
