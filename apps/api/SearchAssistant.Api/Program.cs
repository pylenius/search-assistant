using Microsoft.EntityFrameworkCore;
using NetTopologySuite.IO.Converters;
using SearchAssistant.Api.Endpoints;
using SearchAssistant.Api.Realtime;
using SearchAssistant.Api.Services;
using SearchAssistant.Infrastructure;
using SearchAssistant.Infrastructure.Persistence;

namespace SearchAssistant.Api;

public class Program
{
    public const string AppCorsPolicy = "app";

    // Browser SPA on the live domain is same-origin so doesn't need CORS.
    // Only the Vite dev server at :5173 needs an explicit allowance during
    // local development. (Native iOS/Android apps don't go through CORS.)
    private static readonly string[] AllowedOrigins =
    [
        "http://localhost:5173",
    ];

    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        var connectionString = builder.Configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("ConnectionStrings:Default is not configured.");

        builder.Services.AddInfrastructure(connectionString);
        builder.Services.AddOpenApi();

        builder.Services.ConfigureHttpJsonOptions(o =>
        {
            o.SerializerOptions.Converters.Add(new GeoJsonConverterFactory());
        });

        builder.Services
            .AddSignalR()
            .AddJsonProtocol(o =>
            {
                o.PayloadSerializerOptions.Converters.Add(new GeoJsonConverterFactory());
            });

        builder.Services.AddSingleton<PositionRateLimiter>();
        builder.Services.AddHostedService<SearchExpiryService>();

        builder.Services.AddCors(o => o.AddPolicy(AppCorsPolicy, p =>
            p.WithOrigins(AllowedOrigins)
             .AllowAnyHeader()
             .AllowAnyMethod()
             .AllowCredentials()));

        var app = builder.Build();

        // Apply any pending EF Core migrations on startup. Small enough scale that
        // bundling this into the same process is fine; if we later need zero-downtime
        // deploys with schema changes, split this into a separate one-shot job.
        using (var scope = app.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Database.Migrate();
        }

        // CORS must run before endpoints so preflights respond before MVC pipeline.
        app.UseCors(AppCorsPolicy);

        if (app.Environment.IsDevelopment())
        {
            app.MapOpenApi();
        }

        app.MapGet("/api/health", async (AppDbContext db) =>
        {
            var ok = await db.Database.CanConnectAsync();
            var postgis = await db.Database
                .SqlQueryRaw<string>("SELECT postgis_version() AS \"Value\"")
                .FirstOrDefaultAsync();
            return Results.Ok(new { ok, postgis });
        });

        app.MapSearchEndpoints();
        app.MapAreaEndpoints();
        app.MapPathEndpoints();
        app.MapManageEndpoints();
        app.MapExportEndpoints();
        app.MapWellKnownEndpoints();
        app.MapLegalEndpoints();
        app.MapHub<SearchHub>("/hub/search");

        app.Run();
    }
}
