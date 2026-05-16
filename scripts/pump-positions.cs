#:package Microsoft.AspNetCore.SignalR.Client@10.0.*
#:property JsonSerializerIsReflectionEnabledByDefault=true

using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.SignalR.Client;

if (args.Length < 4)
{
    Console.Error.WriteLine("Usage: dotnet run pump-positions.cs -- <slug> <displayName> <centerLng> <centerLat> [seconds=20]");
    return 2;
}
var slug = args[0];
var name = args[1];
var centerLng = double.Parse(args[2], System.Globalization.CultureInfo.InvariantCulture);
var centerLat = double.Parse(args[3], System.Globalization.CultureInfo.InvariantCulture);
var seconds = args.Length >= 5 ? int.Parse(args[4]) : 20;

const string ApiBase = "http://localhost:5080";
using var http = new HttpClient { BaseAddress = new Uri(ApiBase) };

var joinResp = await http.PostAsJsonAsync($"/api/searches/{slug}/join",
    new { displayName = name });
joinResp.EnsureSuccessStatusCode();
var join = await joinResp.Content.ReadFromJsonAsync<JsonElement>();
var token = join.GetProperty("sessionToken").GetString()!;
Console.WriteLine($"REST joined {name} id={join.GetProperty("participantId").GetGuid()}");

var hub = new HubConnectionBuilder().WithUrl($"{ApiBase}/hub/search").Build();
await hub.StartAsync();
await hub.InvokeAsync("JoinSearch", slug, token);
Console.WriteLine($"Hub joined, pumping positions for {seconds}s…");

var sw = System.Diagnostics.Stopwatch.StartNew();
var step = 0;
while (sw.Elapsed.TotalSeconds < seconds)
{
    // ~50m east per step (rough), traces a slow eastward line
    var lng = centerLng + step * 0.0005;
    var lat = centerLat + Math.Sin(step / 4.0) * 0.0002;
    await hub.InvokeAsync("SendPosition", lng, lat, 5.0, (double?)null);
    Console.WriteLine($"t={sw.Elapsed.TotalSeconds:F1}s pos=({lng:F5},{lat:F5})");
    await Task.Delay(1500);
    step++;
}

await hub.DisposeAsync();
Console.WriteLine("done");
return 0;
