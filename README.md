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

Version **0.11.0** makes Yemi's starter radio playable: turn six labelled signal dials to match their targets. The server validates every move and pays the original one-time 90 SC reward after all matches and the minimum test time. Close/resume from the activity panel; interrupted puzzles persist. Old timed repairs already in progress still complete normally. See [interactive repair](docs/MILESTONE_10.md).

Version **0.13.0** adds **Dialogue review** to `/owner/`: search 77 current wedding/street units, read scene context and hints, approve/request changes/return to pending, and keep version-specific notes and append-only history. Changed text needs a new review; suggestions ship in a future game build. This provides the admin review mechanism, not an automatic cultural sign-off. See [admin review](docs/MILESTONE_12.md). PostgreSQL advances additively to migration 3; retain the existing volume/password.

Version **0.14.0** continues the wedding into Tunde's **Baba God Dey** mission: accelerate/brake/change lane through three short road legs, use safe bays or the guided alternative, resolve passenger/fare choices and record the bag. The server owns driving progress and one-time story rewards; street currency stays separate. Existing wedding saves upgrade without replay. The admin queue contains 86 text units in that release. See [Tunde and driving](docs/MILESTONE_13.md).

Version **0.15.0** adds Ngozi's **Ajo Day**: eleven saved checkpoints under her canteen awning, readable contribution/receipt cards, date/status/partial-entry comparisons, patient or firm agreed terms, Nneka's private follow-up and the catering invoice. Both negotiation approaches work; errors give free hints. Campaign version 3 preserves older wedding/Tunde/road saves. The admin queue covers 97 units, including all displayed record text. See [Ajo Day](docs/MILESTONE_14.md). Four Percent and the remaining campaign are still in production.

Version **0.16.0** adds **Four Percent**: KC's illustrated camera pans/changes width to keep three subjects in frame. Saved attempts cost 1% story battery; empty battery has free recovery. Follow any of three charging leads, compare the crop with its private original and choose whether to admit the omission now or leave a saved conversation for later. Eleven checkpoints grant original-source evidence/mastery once; earlier saves are preserved. The admin queue covers 108 units, including all route/subject text. See [KC and framing](docs/MILESTONE_15.md). Family Meeting and later acts remain in production.

Version **0.17.0** adds the **Family Meeting** convergence and evidence journal. Compare the three leads' sources, respect the private follow-up, record custody and choose either informed pact across twelve saved checkpoints. The journal separates source records from accounts, rechecks only earned sources and shows disclosure/custody/pact decisions. Cached summaries/navigation remain usable offline while save actions stay protected. Campaign version 5 retains earlier phone/road/record progress. The owner review queue covers 126 units. See [Family Meeting and journal](docs/MILESTONE_16.md). Spread, Election Day, full animation and release validation remain in production.

Version **0.12.0** opens **Naija Street Life: Up NEPA!** with a playable text-first wedding introduction starring Tunde, Ngozi and KC. Choose **Up NEPA! · Story mode** in the sidebar or Explore menu. Complete invitation, food-ticket and filming tasks across 14 saved checkpoints; pause/resume freely and unlock Family Meeting after the title scene. Original painted protagonists appear in layered wedding staging. Campaign progress/mastery/evidence are separate from street currency, needs and jobs. See [wedding milestone](docs/MILESTONE_11.md), [story bible](docs/STORY_BIBLE_UP_NEPA.md) and [production roadmap](docs/ROADMAP.md). The full game remains in production under [PRODUCTION_PLAN.md](docs/PRODUCTION_PLAN.md); The remaining Act 1 missions follow.

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

Not implemented: remaining Up NEPA! Act 1 missions, Acts 2–3/endings/chapter replay, free-roaming directional animation for its three leads, unrestricted city generation, unrestricted city driving/traffic collisions/turning traffic, shared marketplace/applications, multiplayer rooms, actual elections, Jev, licensed news, real funds/escrow, airtime/data rewards, email/password account recovery, HD packs or full screen-reader support. StreetCoins cannot be redeemed. The seeded district kit and guided rides are not a complete procedural city or shared traffic simulation. Phone performance is not established by desktop screenshots.

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
