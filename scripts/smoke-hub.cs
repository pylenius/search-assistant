#:package Microsoft.AspNetCore.SignalR.Client@10.0.*
#:property JsonSerializerIsReflectionEnabledByDefault=true

using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.SignalR.Client;

const string ApiBase = "http://localhost:5080";
var jsonOpts = new JsonSerializerOptions(JsonSerializerDefaults.Web);
using var http = new HttpClient { BaseAddress = new Uri(ApiBase) };

Console.WriteLine("==> Create search");
var createResp = await http.PostAsJsonAsync("/api/searches",
    new { title = "Hub smoke test", centerLng = 24.94, centerLat = 60.17, zoom = 14 });
createResp.EnsureSuccessStatusCode();
var created = await createResp.Content.ReadFromJsonAsync<JsonElement>(jsonOpts);
var slug = created.GetProperty("slug").GetString()!;
Console.WriteLine($"   slug = {slug}");

async Task<(Guid Id, string Token)> Join(string name)
{
    var r = await http.PostAsJsonAsync($"/api/searches/{slug}/join", new { displayName = name });
    r.EnsureSuccessStatusCode();
    var j = await r.Content.ReadFromJsonAsync<JsonElement>(jsonOpts);
    return (j.GetProperty("participantId").GetGuid(), j.GetProperty("sessionToken").GetString()!);
}
var alice = await Join("Alice");
var bob = await Join("Bob");
Console.WriteLine($"==> Alice={alice.Id} Bob={bob.Id}");

HubConnection Build() => new HubConnectionBuilder()
    .WithUrl($"{ApiBase}/hub/search")
    .Build();

var aliceConn = Build();
var bobConn = Build();

var positionReceived = new TaskCompletionSource<JsonElement>(TaskCreationOptions.RunContinuationsAsynchronously);
var participantJoinedOnAlice = new TaskCompletionSource<JsonElement>(TaskCreationOptions.RunContinuationsAsynchronously);

aliceConn.On<JsonElement>("PositionUpdated", p => positionReceived.TrySetResult(p));
aliceConn.On<JsonElement>("ParticipantJoined", p => participantJoinedOnAlice.TrySetResult(p));

await aliceConn.StartAsync();
await bobConn.StartAsync();
Console.WriteLine("==> Both hubs connected");

await aliceConn.InvokeAsync("JoinSearch", slug, alice.Token);
Console.WriteLine("   Alice joined group");

await bobConn.InvokeAsync("JoinSearch", slug, bob.Token);
Console.WriteLine("   Bob joined group");

// Bob's join should trigger ParticipantJoined on Alice's connection.
var joinEvt = await participantJoinedOnAlice.Task.WaitAsync(TimeSpan.FromSeconds(5));
var joinedId = joinEvt.GetProperty("id").GetGuid();
if (joinedId != bob.Id)
{
    Console.Error.WriteLine($"FAIL: ParticipantJoined had id={joinedId}, expected {bob.Id}");
    return 1;
}
Console.WriteLine("   ✓ Alice received ParticipantJoined for Bob");

// Now Bob sends a position; Alice should see it.
await bobConn.InvokeAsync("SendPosition", 24.945, 60.171, 5.0, (double?)null);
Console.WriteLine("   Bob sent position");

var posEvt = await positionReceived.Task.WaitAsync(TimeSpan.FromSeconds(5));
var senderId = posEvt.GetProperty("participantId").GetGuid();
var lng = posEvt.GetProperty("lng").GetDouble();
var lat = posEvt.GetProperty("lat").GetDouble();
if (senderId != bob.Id || Math.Abs(lng - 24.945) > 1e-6 || Math.Abs(lat - 60.171) > 1e-6)
{
    Console.Error.WriteLine($"FAIL: PositionUpdated participantId={senderId} lng={lng} lat={lat}");
    return 1;
}
Console.WriteLine("   ✓ Alice received PositionUpdated from Bob");

// Negative case: a hub connection without JoinSearch must NOT receive anything.
var outsiderConn = Build();
await outsiderConn.StartAsync();
var outsiderGotEvt = false;
outsiderConn.On<JsonElement>("PositionUpdated", _ => outsiderGotEvt = true);
await bobConn.InvokeAsync("SendPosition", 24.95, 60.18, 5.0, (double?)null);
await Task.Delay(500);
if (outsiderGotEvt)
{
    Console.Error.WriteLine("FAIL: outsider (not in any group) received PositionUpdated");
    return 1;
}
Console.WriteLine("   ✓ Outsider not in group received nothing");

await aliceConn.DisposeAsync();
await bobConn.DisposeAsync();
await outsiderConn.DisposeAsync();

Console.WriteLine("PASS");
return 0;
