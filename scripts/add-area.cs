#:property JsonSerializerIsReflectionEnabledByDefault=true

using System.Net.Http.Json;
using System.Text.Json;
using System.Globalization;

if (args.Length < 4)
{
    Console.Error.WriteLine("Usage: dotnet run add-area.cs -- <slug> <displayName> <centerLng> <centerLat>");
    return 2;
}
var slug = args[0];
var name = args[1];
var lng = double.Parse(args[2], CultureInfo.InvariantCulture);
var lat = double.Parse(args[3], CultureInfo.InvariantCulture);

const string ApiBase = "http://localhost:5080";
using var http = new HttpClient { BaseAddress = new Uri(ApiBase) };

var joinResp = await http.PostAsJsonAsync($"/api/searches/{slug}/join", new { displayName = name });
joinResp.EnsureSuccessStatusCode();
var join = await joinResp.Content.ReadFromJsonAsync<JsonElement>();
var token = join.GetProperty("sessionToken").GetString()!;
Console.WriteLine($"Joined as {name}: id={join.GetProperty("participantId").GetGuid()} color={join.GetProperty("color").GetString()}");

// Build a small square polygon (~150m on each side at latitude ~61).
double dLng = 0.002;
double dLat = 0.001;
var coords = new[]
{
    new[] { lng - dLng, lat - dLat },
    new[] { lng + dLng, lat - dLat },
    new[] { lng + dLng, lat + dLat },
    new[] { lng - dLng, lat + dLat },
    new[] { lng - dLng, lat - dLat },
};
var polygon = new
{
    geometry = new
    {
        type = "Polygon",
        coordinates = new[] { coords },
    },
};

var areaReq = new HttpRequestMessage(HttpMethod.Post, $"/api/searches/{slug}/areas")
{
    Content = JsonContent.Create(polygon),
};
areaReq.Headers.Add("X-Session-Token", token);

var areaResp = await http.SendAsync(areaReq);
var body = await areaResp.Content.ReadAsStringAsync();
Console.WriteLine($"POST /areas → {(int)areaResp.StatusCode}");
Console.WriteLine(body);
return areaResp.IsSuccessStatusCode ? 0 : 1;
