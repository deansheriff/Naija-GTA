# 0.9.0 — Repeatable repair work and a home of your own

This milestone turns the one-time starter gig into a small repeatable career, with persistent purchases visible in the actual home interior. Browser and native Android use the same Godot rules/content. Cloud rewards, prices, needs and eligibility are authoritative on the server.

## Play

Visit Yemi’s workshop after practicing once and completing his starter radio repair. Scroll to **Repeatable repair work**. The board shows requirements, costs, rewards and the next-customer countdown. Gigs links back to the workshop; the profile and current goal show career progress.

| Work | Unlock | Duration | Upfront cost | Completion reward |
|---|---|---|---|---|
| Standing fan | Starter radio finished, Repair 2 | 20 seconds | 18 energy, 8 food | 45 SC, +1 Repair, +1 career job |
| Inverter diagnosis | Starter radio finished, Repair 4, 3 career jobs | 30 seconds | 26 energy, 12 food | 75 SC, +1 Repair, +1 career job |

Start with at least 20 food and the energy cost plus 5. Both jobs share a 45-second cooldown measured from the scheduled completion time. You can rest, eat, study or explore during that cooldown. One active activity is allowed; returning after an absence settles that job once and starts no additional work. Balance is provisional: these short prototype timings need longer player sessions before a larger economy.

Rest at home takes 8 seconds and restores 35 energy for free. A 25 SC meal restores 35 food and 4 energy. Amaka also offers a free 12-second community plate (+25 food) only when food is below 20 and coins below 25. This prevents an empty-wallet hunger lock without granting money or skill.

## Home catalogue

At **Your little corner → Home catalogue & inventory**, buy a woven mat (90 SC), desk plant (60 SC) or table radio (180 SC). A purchase owns and places the item atomically. Place/store owned items for free; there is no resale, duplicate quantity or stat bonus. These are fictional StreetCoins with no redemption.

**Step inside to see your furnishings** closes the catalogue and walks home when needed. Desk accessories share the existing desk footprint. The flat mat fits within the open doorway. Separate scene objects use the neighborhood’s depth sorting and roof reveal, remain on Low and add no navigation obstacle. Original code-native shapes extend the existing furniture kit; no new raster asset is included.

## Persistence and deployment

Additive save fields are `career` and `inventory`; JSON save version stays 1 and SQL remains at migration 2. Old balances, starter completion, lunch-favor stages, relationships, wall colors, private drafts and world seeds are retained. Online snapshots convert server deadlines to display-only timers; the client never pays a cloud reward. Pending commands, revisions and exact durable receipts retain their existing behavior.

The SQLite and PostgreSQL stores execute completion, reward/price ledger entries, ownership, revision and receipt writes in one transaction. Concurrent acceptance permits one job; identical completion retries return one payment receipt. Invalid prices/rewards/state injection are rejected. Owner inspection automatically includes the new saved JSON fields and ledger reasons; existing maintenance/suspension controls apply.

Deploy `main` using the existing Coolify `/compose.yaml`. Keep the database volume/password and take a backup first. No additional environment variable is required for this milestone. Coming from a pre-0.8 deployment also applies operations migration 2; follow [owner operations](OWNER_PANEL.md) for its upgrade/rollback boundary. An older backend does not understand active career work: rollback requires compatible code and the matching pre-upgrade database backup. Location is still client presentation, not an authoritative shared world.

## Verification

- 205 game assertions: 28 simulation, 18 street activity, 16 actors/nature, 22 district layout, 39 travel/world, 40 NPC/relationships, 10 operations-client and 32 career/inventory checks. Actual-scene checks additionally cover HUD bounds, Low tire grounding, recycled gait and catalogue/workshop/food modal scrolling.
- 13 backend tests, including one shared career HTTP contract across SQLite and embedded PostgreSQL; the same PostgreSQL scenario runs against real PostgreSQL 17 in CI. Tests cover time boundaries, needs/cooldowns/unlocks, concurrency, exact replay, purchases, ownership, insufficient balances, recovery meals, old saves and restart persistence. CI also builds/starts Docker/Compose and verifies PostgreSQL dump/restore.
- Rebuilt single-threaded browser export and engine-native Android debug APK, version 0.9.0/code 10. Browser download remains about 20.62 MiB, with 35.95 MiB expanded WASM before initialization.
- Desktop and 390×844 portrait browser QA uses disposable local test characters, seeded through approved starter commands. Production player records are not edited. Proof: [career board](screenshots/milestone8-career-desktop.png), [desktop inventory](screenshots/milestone8-inventory-desktop.png), [portrait inventory](screenshots/milestone8-inventory-mobile.png), [desktop room](screenshots/milestone8-home-desktop.png) and [portrait room](screenshots/milestone8-home-mobile.png). Browser QA confirmed a 45 SC completion, three purchases totalling 330 SC, free store/place and retained ownership/balance after reload.

Phone hardware, native HTTPS/input and 20-minute memory/frame-time/thermal measurements remain unverified. These jobs are timed workshop activities; custom repair minigames, shared marketplace work, unrestricted furnishing placement and a playable Up NEPA! campaign remain future work.

## Next

[0.10 neighborhood errands and interactions](ROADMAP.md) expands the existing cast with a bounded authored errand chain and saved dialogue consequences. Playtest the career’s earning/recovery balance before growing the economy. The Up NEPA! story bible still awaits narrative review before subsequent campaign deliverables.
