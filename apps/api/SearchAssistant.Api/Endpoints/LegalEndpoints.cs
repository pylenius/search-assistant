namespace SearchAssistant.Api.Endpoints;

public static class LegalEndpoints
{
    // Single source of truth for the "last updated" date so the privacy page
    // and any future signal (e.g. a banner reminding users to re-read) stay
    // in lockstep. Update this whenever the policy text below changes.
    private const string PrivacyUpdatedDate = "2026-05-17";

    public static IEndpointRouteBuilder MapLegalEndpoints(this IEndpointRouteBuilder app)
    {
        // Single-page privacy policy served straight from the API. Used as
        // the publicly-listed privacy policy URL on Apple App Store Connect
        // and Google Play Console — both stores require a stable HTTP(S)
        // URL when an app collects location.
        app.MapGet("/privacy", () => Results.Text(BuildPrivacyHtml(), "text/html; charset=utf-8"));

        // Convenience alias — some app-store flows ask specifically for a
        // "privacy-policy" path.
        app.MapGet("/privacy-policy", () => Results.Redirect("/privacy", permanent: true));

        return app;
    }

    private static string BuildPrivacyHtml() => $$"""
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Search Assistant — Privacy Policy</title>
<style>
  :root { color-scheme: light dark; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    max-width: 720px; margin: 2rem auto; padding: 0 1.2rem;
    line-height: 1.55; color: #1f2937;
  }
  @media (prefers-color-scheme: dark) {
    body { background:#0f172a; color:#e2e8f0; }
    a { color:#34d399; }
    h1, h2 { color:#e2e8f0; }
    .muted { color:#94a3b8; }
  }
  h1 { font-size: 1.6rem; margin-bottom: 0.25rem; }
  h2 { font-size: 1.05rem; margin-top: 1.8rem; }
  .muted { color:#6b7280; font-size:0.9rem; }
  ul { padding-left: 1.2rem; }
  li { margin: 0.25rem 0; }
  code { background:rgba(127,127,127,0.15); padding: 0 0.25rem; border-radius: 3px; }
</style>
</head>
<body>

<h1>Search Assistant — Privacy Policy</h1>
<p class="muted">Last updated: {{PrivacyUpdatedDate}}</p>

<p>
This page describes what Search Assistant collects, why, and what we do
with it. Plain language, no legal padding.
</p>

<h2>Who runs this app</h2>
<p>
Search Assistant is operated by <strong>ePort</strong> (Finland). For
privacy questions, contact <a href="mailto:pekka@ogoship.com">pekka@ogoship.com</a>.
</p>

<h2>What we collect</h2>
<ul>
  <li><strong>A display name</strong> you type when you join a search.
      No real name required.</li>
  <li><strong>Your live location</strong> while you actively toggle
      "Share location" or "Record path" inside a search. Coordinates are
      sent to the server roughly once per second.</li>
  <li><strong>Drawings and recorded paths</strong> you submit to a search
      (polygons you draw, GPS tracks you record).</li>
  <li><strong>A device-generated session token</strong>, kept in the app's
      local storage so you don't have to re-join the same search every time.</li>
</ul>
<p>
We do <strong>not</strong> collect: email addresses, phone numbers,
contacts, photos, files, advertising identifiers, payment information,
device sensors beyond GPS, or browsing activity outside the app. There
are no analytics SDKs, ad networks, or third-party trackers.
</p>

<h2>Why we collect it</h2>
<p>
Solely to make the app work: render markers and paths on a shared map
for everyone in the same search. Without the location, the app has
nothing to show.
</p>

<h2>Who sees your data</h2>
<ul>
  <li>Other participants in the <strong>same search</strong>. Sharing is
      link-based: anyone with the search's URL can join it. Treat the URL
      like a meeting link — share it only with people you want to share
      your live position with.</li>
  <li>No one else. We do not sell, rent, license, or hand your data to
      advertisers, brokers, or any third party. We do not use it to train
      machine-learning models.</li>
</ul>

<h2>Where it's stored</h2>
<p>
On a single server we operate in Finland (EU). Data sits in a
PostgreSQL/PostGIS database protected by access controls and TLS in
transit (HTTPS).
</p>

<h2>How long we keep it</h2>
<ul>
  <li>Your live position is overwritten on every new update. Older
      positions accumulate in a per-search history that gets deleted
      together with the search.</li>
  <li>A search (including all its participants, areas, paths, and
      positions) is deleted when its owner ends it, or automatically when
      its expiry time passes. If no expiry was set, the search is
      retained while it remains in use.</li>
  <li>The locally-stored session token on your device is removed when
      you uninstall the app or clear its storage.</li>
</ul>

<h2>Your rights</h2>
<p>
You can:
</p>
<ul>
  <li>Stop sharing your location at any time by toggling
      <em>Share location</em> off, closing the app, or denying the
      location permission in your phone settings.</li>
  <li>Leave a search by stopping sharing and uninstalling the app, or by
      clearing the app's data — your session token is then forgotten.</li>
  <li>Delete a search you created via the Manage screen, which removes
      everything in it (your data and other participants' data alike) for
      everyone.</li>
  <li>Contact us at <a href="mailto:pekka@ogoship.com">pekka@ogoship.com</a>
      to request deletion of a specific search you participated in. If
      you're an EU resident, GDPR's rights of access / rectification /
      erasure / portability / objection apply.</li>
</ul>

<h2>Background location</h2>
<p>
If you turn on path recording, the app keeps collecting GPS fixes while
the screen is off. iOS shows the standard blue location indicator;
Android shows a persistent notification. The app does not collect
location while it is in the background <em>unless</em> path recording
is active. You can revoke background location at any time in your
device settings.
</p>

<h2>Children</h2>
<p>
Search Assistant is not directed at children under 13 (or under 16 in
the EU). We do not knowingly collect data from children below those ages.
</p>

<h2>Security</h2>
<p>
All traffic between the app and the server goes over HTTPS/TLS. Database
access is restricted to the API host. We do not store passwords because
the app has no user accounts — only per-search session tokens, which
are revocable by deleting the search.
</p>

<h2>Changes</h2>
<p>
If we materially change what is collected or how it's used, the
"Last updated" date above will change and we will surface a notice
in-app on next launch. Continued use of the app after the update means
acceptance of the revised policy.
</p>

<h2>Contact</h2>
<p>
Questions, requests, or complaints:
<a href="mailto:pekka@ogoship.com">pekka@ogoship.com</a>.
</p>

</body>
</html>
""";
}
