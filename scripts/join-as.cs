#:package Microsoft.AspNetCore.SignalR.Client@10.0.*
#:property JsonSerializerIsReflectionEnabledByDefault=true

using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.SignalR.Client;

if (args.Length < 2)
{
    Console.Error.WriteLine("Usage: dotnet run join-as.cs -- <slug> <displayName> [seconds=15]");
    return 2;
}
var slug = args[0];
var name = args[1];
var seconds = args.Length >= 3 ? int.Parse(args[2]) : 15;

const string ApiBase = "http://localhost:5080";
using var http = new HttpClient { BaseAddress = new Uri(ApiBase) };
var joinResp = await http.PostAsJsonAsync($"/api/searches/{slug}/join",
    new { displayName = name });
joinResp.EnsureSuccessStatusCode();
var join = await joinResp.Content.ReadFromJsonAsync<JsonElement>();
var token = join.GetProperty("sessionToken").GetString()!;
Console.WriteLine($"REST joined: id={join.GetProperty("participantId").GetGuid()} color={join.GetProperty("color").GetString()}");

var hub = new HubConnectionBuilder().WithUrl($"{ApiBase}/hub/search").Build();
await hub.StartAsync();
await hub.InvokeAsync("JoinSearch", slug, token);
Console.WriteLine($"Hub joined as {name}. Holding open for {seconds}s…");
await Task.Delay(TimeSpan.FromSeconds(seconds));
await hub.DisposeAsync();
Console.WriteLine("disconnected");
return 0;
