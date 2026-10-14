# Naija Street Life

An original illustrated Nigerian life-game prototype for browsers and native Android, with self-hosted authoritative saves. Godot 4.6.3/GDScript client, TypeScript/Fastify API and PostgreSQL deployment.

## Deploy on Coolify

Use this repository with **Docker Compose**, branch `main`, base directory `/`, file `/compose.yaml`. Set the secret `POSTGRES_PASSWORD`, assign service `app` your game domain with internal port `8787`, and deploy. The root `Dockerfile` builds the combined game website/API. PostgreSQL stays private in a persistent volume.

**[Full Coolify and Cloudflare instructions](docs/COOLIFY.md)** explain domains, tunnels, backups, Dockerfile-only deployment and Android connection.

## Play and save

Visit `/play/` on the deployed domain. Greet Amaka, practice at Yemi's bench, complete the radio gig, and customize your home accent. Desktop: WASD/arrows, click the street, E nearby, Tab/Enter for menus. Phones: Explore and venue buttons.

Version **0.5.0** assembles the neighborhood from separate ground/road/sidewalk layers, painted building shells and roofs, tree trunks/canopies, counters, benches and a parked danfo. Keyboard movement stops at solid footprints; click/venue travel routes around obstacles and through the shop doorway. Roofs reveal the room as you approach. Passing pedestrians keep walking off-scene without endpoint stops or U-turns. The protagonist's gait/facing, grounded traffic, distinct pedestrians, dogs, birds and occasional canopy gusts remain. Use **Park crew** in Explore/the sidebar, tap a crew member, or press E nearby for branching conversations. Low retains essential movement/animals and interior visibility. See [modular district foundation](docs/MILESTONE_4.md) and [movement and nature](docs/MILESTONE_3.md).

Version **0.6.0** adds **Ride between districts** in the sidebar/Explore menu. Walk to the boarding point, then ride a danfo to Market Road or Palm Junction while an elevated side camera follows the bus through streamed seeded scenery. Skip to arrival or return to the starting stop. Incoming blocks load ahead and old blocks unload behind; at most three transit chunks remain active. New districts have generated building/tree/furniture placements and connected T junctions. Starter venues remain on Home street; choosing one while away queues the return ride. Rides are free local presentation, without currency or mission rewards. Location is session-local and reopening starts on Home street. See [transport and seeded districts](docs/MILESTONE_5.md).

Version **0.7.0** brings Amaka and Yemi to life with walking work/break/home routines. Tap a shopkeeper or use their venue’s **Talk/Find** button. Say hello to Amaka, then complete **A plate for Yemi** for a one-time 30 SC thank-you and trusted-neighbor dialogue. Your profile shows relationships and favor progress. The park crew remembers introductions and requests for space. These choices persist in cloud/local saves; older saves are preserved. See [NPC routines and relationships](docs/MILESTONE_6.md).

Version **0.8.0** adds an opt-in **[owner console](docs/OWNER_PANEL.md)** at `/owner/`: save/ledger inspection, access moderation, validated street content/status/seed controls and audit history. Players can replace their save access code and sign out other devices. PostgreSQL now shares rate limits across app instances, with explicit trusted proxies, retention tooling and backup/restore verification. Set the documented owner secrets in Coolify; no production owner password is included. See [owner tools milestone](docs/MILESTONE_7.md).

Version **0.9.0** adds repeatable repair work at Yemi's: standing fans pay 45 SC; inverter diagnosis pays 75 SC after three career jobs and Repair 4. Jobs spend food/energy on acceptance, pay on completion and share a 45-second cooldown. Rest is free; meals cost 25 SC, with a free community plate for hungry neighbors below 25 SC. At home, buy a woven mat, desk plant or table radio, then place/store owned items for free. Your room and profile reflect saved progress. Existing saves retain starter/favor history. See [careers and home inventory](docs/MILESTONE_8.md).

Version **0.10.0** adds **A light for the square**, a saved neighbourhood errand: ask Amaka after finishing the starter radio, collect Chidi's lantern, repair it at Yemi's, choose the noticeboard or shaded bench, then return for a one-time 40 SC thank-you. The lantern remains in the world and glows in the evening, even on Low. NPC dialogue and park chatter remember your help. Find the journal in Gigs, Explore or Profile. See [neighbourhood errands](docs/MILESTONE_9.md).

**Naija Street Life: Up NEPA!** is the planned three-protagonist comedy campaign starring Tunde, Ngozi and KC. The [draft story bible](docs/STORY_BIBLE_UP_NEPA.md) and [production roadmap](docs/ROADMAP.md) preserve the supplied seed and review order. The campaign is not playable yet; its future versioned checkpoints will be separate from existing sandbox saves.

The web build discovers the same-origin API. Activities, fictional coins, skills, profile, home accent/inventory, repair-career progress/cooldowns, private gig drafts, relationships, the lunch favor, lantern errand/placement and practice-poll choice are saved on the server. In Settings → Cloud save, keep your private **save access code** to open the same character on another browser or Android device. Lost codes cannot be recovered yet. Graphics settings stay on each device. Local prototype balances are never imported into cloud saves.

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

Authored modular street and original AI-generated painted sprites; collision-aware venue travel and directional protagonist gait; starter needs/skills/story; one-time starter gig and repeatable repair career; home accent and persistent furnishings; profile; private drafts with fee/budget/refund rules; private practice poll; graphics controls; local and server saves. Server commands use revisions, durable idempotency receipts, server deadlines and an append-only virtual ledger. A pending command survives interruption and can be retried; conflicting devices refresh rather than silently overwrite progress.

Not implemented: Up NEPA! campaign missions/character switching, unrestricted city generation, player-controlled driving/turning traffic, shared marketplace/applications, multiplayer rooms, actual elections, Jev, licensed news, real funds/escrow, airtime/data rewards, email/password account recovery, HD packs or full screen-reader support. StreetCoins cannot be redeemed. The seeded district kit and guided rides are not a complete procedural city or shared traffic simulation. Phone performance is not established by desktop screenshots.

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
