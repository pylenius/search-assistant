namespace SearchAssistant.Api.Endpoints;

public static class WellKnownEndpoints
{
    // Bundle ID prefixed with team ID. Apple expects "<TEAMID>.<bundleid>".
    private const string AppleAppId = "HEJK7U967E.fi.eport.searchassistant";

    public static IEndpointRouteBuilder MapWellKnownEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/.well-known/apple-app-site-association", () =>
        {
            // Apple's spec uses the literal key "/" for the path pattern — only
            // representable via a dictionary, not an anonymous object.
            var payload = new Dictionary<string, object?>
            {
                ["applinks"] = new Dictionary<string, object?>
                {
                    ["details"] = new[]
                    {
                        new Dictionary<string, object?>
                        {
                            ["appIDs"] = new[] { AppleAppId },
                            ["components"] = new[]
                            {
                                new Dictionary<string, object?>
                                {
                                    ["/"] = "/s/*",
                                    ["comment"] = "Share links open the app",
                                },
                            },
                        },
                    },
                },
            };
            return Results.Json(payload, contentType: "application/json");
        });

        return app;
    }
}
