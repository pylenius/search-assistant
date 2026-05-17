namespace SearchAssistant.Api.Endpoints;

public static class WellKnownEndpoints
{
    // Bundle ID prefixed with team ID. Apple expects "<TEAMID>.<bundleid>".
    private const string AppleAppId = "HEJK7U967E.fi.eport.searchassistant";

    // Android app package ids that should verify against this domain.
    // Two entries because the debug build appends ".debug" via
    // applicationIdSuffix in app/build.gradle.kts — without explicitly
    // listing it here, debug-build App Links would never verify.
    private static readonly string[] AndroidPackageNames =
    {
        "fi.eport.searchassistant",
        "fi.eport.searchassistant.debug",
    };

    // SHA-256 fingerprints of every keystore that should be allowed to handle
    // verified App Links to /s/*. First entry is the local debug keystore
    // (~/.android/debug.keystore) so dev builds verify cleanly; subsequent
    // entries get added once a release keystore is generated.
    private static readonly string[] AndroidCertFingerprints =
    {
        "F0:EF:B2:BE:98:A5:23:AB:31:E3:14:FA:AA:33:0B:77:7C:72:F7:C3:1D:CE:3C:20:96:32:D9:35:44:2B:89:C4",
    };

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

        // Android App Links — verifies https://searchassistant.eport.fi/s/* so
        // the OS opens the native app directly without an "open with" prompt.
        // Built via Dictionary because "namespace" is a reserved C# keyword
        // and anonymous-type property names can't be escaped.
        app.MapGet("/.well-known/assetlinks.json", () =>
        {
            var doc = AndroidPackageNames.Select(pkg =>
                new Dictionary<string, object?>
                {
                    ["relation"] = new[] { "delegate_permission/common.handle_all_urls" },
                    ["target"] = new Dictionary<string, object?>
                    {
                        ["namespace"] = "android_app",
                        ["package_name"] = pkg,
                        ["sha256_cert_fingerprints"] = AndroidCertFingerprints,
                    },
                }).ToArray();
            return Results.Json(doc, contentType: "application/json");
        });

        return app;
    }
}
