#:package Microsoft.AspNetCore.SignalR.Client@10.0.*
#:property JsonSerializerIsReflectionEnabledByDefault=true

using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.SignalR.Client;

const string ApiBase = "http://localhost:5080";
using var http = new HttpClient { BaseAddress = new Uri(ApiBase) };

// Fresh search so persisted Position is clean.
var create = await http.PostAsJsonAsync("/api/searches", new { title = "Rate limit test", centerLng = 24.94, centerLat = 60.17 });
create.EnsureSuccessStatusCode();
var c = await create.Content.ReadFromJsonAsync<JsonElement>();
var slug = c.GetProperty("slug").GetString()!;

var join = await http.PostAsJsonAsync($"/api/searches/{slug}/join", new { displayName = "Burster" });
var j = await join.Content.ReadFromJsonAsync<JsonElement>();
var token = j.GetProperty("sessionToken").GetString()!;

var hub = new HubConnectionBuilder().WithUrl($"{ApiBase}/hub/search").Build();
var received = 0;
hub.On<JsonElement>("PositionUpdated", _ => Interlocked.Increment(ref received));
await hub.StartAsync();
await hub.InvokeAsync("JoinSearch", slug, token);

// Fire 20 invocations as fast as possible — each ~50ms apart.
const int N = 20;
for (var i = 0; i < N; i++)
{
    await hub.InvokeAsync("SendPosition", 24.94 + i * 0.0001, 60.17, 5.0, (double?)null);
    await Task.Delay(50);
}

// Let any in-flight broadcasts arrive
await Task.Delay(300);

Console.WriteLine($"Invoked: {N}");
Console.WriteLine($"PositionUpdated broadcasts received: {received}");
Console.WriteLine($"Expected ≤ ~{(int)Math.Ceiling((N * 0.05) / 0.7) + 2} (cooldown 700ms)");

await hub.DisposeAsync();
return 0;
