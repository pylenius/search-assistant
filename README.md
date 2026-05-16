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

## iOS (Capacitor)

The `apps/web/ios/` folder is a regenerated build artifact and is **not** checked in.
Every iOS customization lives in `apps/web/scripts/ios-bootstrap.sh`. Re-run anytime,
including after `rm -rf apps/web/ios`:

```sh
cd apps/web
./scripts/ios-bootstrap.sh
open ios/App/App.xcworkspace   # then set signing + Product → Archive
```

## Stack

- Backend: .NET 10 + ASP.NET Core + EF Core + NetTopologySuite, SignalR for realtime
- Database: Postgres 16 + PostGIS 3
- Frontend: Vue 3 + Vite + TypeScript + MapLibre GL JS + Tailwind
- Mobile: Capacitor (iOS first, Android later)
- Hosting: Docker Compose on a single VM, Caddy for TLS

## License

MIT — see [LICENSE](./LICENSE).
