# search-assistant

Collaborative GPS + map search assistant. Share a link, everyone sees the same search area, walked paths, and live positions.

See `/Users/pekka/.claude/plans/lets-plan-for-search-crystalline-flurry.md` for the full design.

## Local development

```sh
# 1. Start the database
docker compose -f compose.dev.yml up -d

# 2. Run the API
cd apps/api && dotnet run --project SearchAssistant.Api

# 3. Run the web app
cd apps/web && npm install && npm run dev
```

## Mobile

Native apps live in `apps/ios/` (SwiftUI + MapKit) and `apps/android/`
(Jetpack Compose + Google Maps). See `AGENT.md` for build details.

## Stack

- Backend: .NET 10 + ASP.NET Core + EF Core + NetTopologySuite, SignalR for realtime
- Database: Postgres 16 + PostGIS 3
- Frontend: Vue 3 + Vite + TypeScript + MapLibre GL JS + Tailwind
- Mobile: native iOS (SwiftUI/MapKit) and Android (Compose/Google Maps)
- Hosting: Docker Compose on a single VM, Caddy for TLS

## Publishing

```sh
./docker-publish.sh
```

Builds `searchassistant-api` and `searchassistant-web` for `linux/amd64`,
tags them as `docker-repository.eport.fi/searchassistant-{api,web}:latest`,
and pushes. Override the target API URL baked into the SPA with
`VITE_API_BASE=https://your-host ./docker-publish.sh`.

## License

MIT — see [LICENSE](./LICENSE).
