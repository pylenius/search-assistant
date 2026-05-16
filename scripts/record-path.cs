#:property JsonSerializerIsReflectionEnabledByDefault=true

using System.Net.Http.Json;
using System.Text.Json;
using System.Globalization;

if (args.Length < 4)
{
    Console.Error.WriteLine("Usage: dotnet run record-path.cs -- <slug> <displayName> <startLng> <startLat> [steps=12]");
    return 2;
}
var slug = args[0];
var name = args[1];
var lng0 = double.Parse(args[2], CultureInfo.InvariantCulture);
var lat0 = double.Parse(args[3], CultureInfo.InvariantCulture);
var steps = args.Length >= 5 ? int.Parse(args[4]) : 12;

const string ApiBase = "http://localhost:5080";
using var http = new HttpClient { BaseAddress = new Uri(ApiBase) };

var joinResp = await http.PostAsJsonAsync($"/api/searches/{slug}/join", new { displayName = name });
joinResp.EnsureSuccessStatusCode();
var join = await joinResp.Content.ReadFromJsonAsync<JsonElement>();
var token = join.GetProperty("sessionToken").GetString()!;
Console.WriteLine($"Joined {name} color={join.GetProperty("color").GetString()}");

double[] PosFor(int i)
{
    var lng = lng0 + i * 0.00060;
    var lat = lat0 + Math.Sin(i / 3.0) * 0.00040;
    return new[] { lng, lat };
}

HttpRequestMessage Auth(HttpRequestMessage m) { m.Headers.Add("X-Session-Token", token); return m; }

// Start with 2 points
var startResp = await http.SendAsync(Auth(new HttpRequestMessage(HttpMethod.Post, $"/api/searches/{slug}/paths")
{
    Content = JsonContent.Create(new { points = new[] { PosFor(0), PosFor(1) } }),
}));
startResp.EnsureSuccessStatusCode();
var pathDto = await startResp.Content.ReadFromJsonAsync<JsonElement>();
var pathId = pathDto.GetProperty("id").GetGuid();
Console.WriteLine($"Path started: {pathId}");

// Append remaining points in chunks of 3
for (var i = 2; i < steps; i += 3)
{
    var batch = Enumerable.Range(i, Math.Min(3, steps - i)).Select(PosFor).ToArray();
    var patch = await http.SendAsync(Auth(new HttpRequestMessage(HttpMethod.Patch, $"/api/searches/{slug}/paths/{pathId}")
    {
        Content = JsonContent.Create(new { points = batch }),
    }));
    patch.EnsureSuccessStatusCode();
    Console.WriteLine($"Appended {batch.Length} points (step {i}..{i + batch.Length - 1})");
    await Task.Delay(800);
}

var finalize = await http.SendAsync(Auth(new HttpRequestMessage(HttpMethod.Patch, $"/api/searches/{slug}/paths/{pathId}")
{
    Content = JsonContent.Create(new { finalize = true }),
}));
finalize.EnsureSuccessStatusCode();
Console.WriteLine("Path finalized");
return 0;
