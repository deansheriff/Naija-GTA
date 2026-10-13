# Naija Street Life

An original illustrated Nigerian life-game prototype for browsers and native Android, with self-hosted authoritative saves. Godot 4.6.3/GDScript client, TypeScript/Fastify API and PostgreSQL deployment.

## Deploy on Coolify

Use this repository with **Docker Compose**, branch `main`, base directory `/`, file `/compose.yaml`. Set the secret `POSTGRES_PASSWORD`, assign service `app` your game domain with internal port `8787`, and deploy. The root `Dockerfile` builds the combined game website/API. PostgreSQL stays private in a persistent volume.

**[Full Coolify and Cloudflare instructions](docs/COOLIFY.md)** explain domains, tunnels, backups, Dockerfile-only deployment and Android connection.

## Play and save

Visit `/play/` on the deployed domain. Greet Amaka, practice at Yemi's bench, complete the radio gig, and customize your home accent. Desktop: WASD/arrows, click the street, E nearby, Tab/Enter for menus. Phones: Explore and venue buttons.

Version **0.4.1** makes passing pedestrians walk continuously across the street and exit beyond the scene edges, without stopping or reversing at short route endpoints. They re-enter off-screen with their heading and gait intact. The 0.4 artwork fixes the protagonist's leg animation/facing and grounds traffic with wheel-contact shadows. It adds distinct market/office/older pedestrians, roaming dogs, flying birds and occasional canopy gusts. Shopkeepers work behind their shop benches. Use **Park crew** in Explore/the sidebar, tap a crew member, or press E nearby for branching conversations. Nearby NPCs exchange authored speech bubbles. Low retains essential movement/animals; Ambient animation pauses the street independently of the player. See [movement and nature](docs/MILESTONE_3.md) and the [next milestones](docs/ROADMAP.md).

The web build discovers the same-origin API. Activities, fictional coins, skills, profile, home accent, private gig drafts and practice-poll choice are saved on the server. In Settings → Cloud save, keep your private **save access code** to open the same character on another browser or Android device. Lost codes cannot be recovered yet. Graphics settings stay on each device. Local prototype balances are never imported into cloud saves.

Android: build `build/android/naija-street-life-debug.apk`, then enter your deployed HTTPS game domain in Cloud save. This is a native Godot APK, not a WebView wrapper. Physical-device/native HTTPS testing remains necessary; the debug package is not a Play release.

## Local development

```powershell
cd server
npm ci
npm run check
npm test
npm run dev
```

Open `http://127.0.0.1:8787/`. Development uses persistent SQLite in ignored `server/data/`. Production requires PostgreSQL via separate `PGHOST`, `PGUSER`, `PGDATABASE`, `PGPASSWORD` fields (Compose), or `DATABASE_URL` (external database), and refuses SQLite fallback. Docker builds the TypeScript server; the browser export in `web/dist` is committed so the deployment host needs no Godot toolchain.

To update the game export:

```powershell
python scripts/fetch_godot.py
.\scripts\build.ps1 -Target web
# Android additionally needs your SDK/JDK:
.\scripts\configure_android.ps1 -AndroidSdk 'C:\path\to\Android\Sdk' -JavaSdk 'C:\path\to\JDK'
.\scripts\build.ps1 -Target android
```

Commit the regenerated `web/dist` with game source changes. See [build notes](docs/BUILD.md), [backend contract](server/README.md), [art prompts/provenance](docs/ART_DIRECTION.md) and [checkpoint](docs/MILESTONE_1.md).

## Included / remaining

Painted street and original AI-generated sprite art; venue travel and eight-frame directional protagonist; starter needs/skills/story; one-time starter gig; home accent; profile; private drafts with fee/budget/refund rules; private practice poll; graphics controls; local and server saves. Server commands use revisions, durable idempotency receipts, server deadlines and an append-only virtual ledger. A pending command survives interruption and can be retried; conflicting devices refresh rather than silently overwrite progress.

Not implemented: shared marketplace/applications, multiplayer rooms, actual elections, Jev, licensed news, real funds/escrow, airtime/data rewards, email/password account recovery, HD packs or full screen-reader support. StreetCoins cannot be redeemed. The first street uses a painted background, not a complete modular city. Phone performance is not established by desktop screenshots.

## Layout

| Directory | Purpose |
|---|---|
| `game/` | Canonical Godot source, painted assets and local/HTTP adapters. |
| `server/` | API, SQLite/PostgreSQL stores, migration and integration tests. |
| `web/` | Landing source and committed browser export. |
| `scripts/` | Portable engine setup, exports and local static preview. |
| `docs/` | Deployment, build, art and evidence. |
| `.github/workflows/` | Real PostgreSQL tests and Docker build/start smoke checks. |

Local toolchains, credentials, databases, earlier private Sites checkout and research captures are excluded from this repository. Engine/third-party license texts are available in game Settings → Engine credits & licenses.
