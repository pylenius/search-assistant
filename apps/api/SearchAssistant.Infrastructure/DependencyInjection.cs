using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using SearchAssistant.Infrastructure.Persistence;

namespace SearchAssistant.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, string connectionString)
    {
        services.AddDbContext<AppDbContext>(opt =>
            opt.UseNpgsql(connectionString, o =>
            {
                o.UseNetTopologySuite();
                o.MigrationsAssembly(typeof(AppDbContext).Assembly.FullName);
            }));

        return services;
    }
}
