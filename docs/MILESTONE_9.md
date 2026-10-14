# 0.10.0 — A light for the square

An authored neighbourhood errand now connects Amaka, Yemi and the park crew. The player carries a rechargeable lantern between them, repairs it, chooses a permanent spot and sees the result in the street. This is a sandbox errand; the Up NEPA! campaign remains on its separate review/production track.

## Play-through

1. Say hello to Amaka and finish Yemi's starter radio repair. Open **A light for the square** at Amaka's kitchen or in her conversation. Accept whenever ready; leaving the dialogue has no penalty.
2. Visit the park crew and collect Chidi's old lantern.
3. At Yemi's workshop, choose the lantern errand and repair it. It takes 10 seconds and costs 8 energy; start with at least 15 energy. This step grants no coins, skill or paid career-job credit. Rest at home if needed.
4. Return to the park and choose the noticeboard or shaded bench. The lantern appears on that fixture and keeps its placement.
5. Return to Amaka for a one-time 40 fictional StreetCoin thank-you, +1 Social and bounded relationship updates.

The **Neighbourhood errands** journal is available in Gigs, Explore and Profile. It shows the next venue, carried lantern and completed stages, alongside the existing lunch favour. The HUD tracks an accepted lantern errand; the lunch favour remains available in the journal. There is no deadline or off-screen failure. Venue notes keep the errand accessible when shopkeepers are on a break or at home. Regular repair jobs remain available.

## World and dialogue

The installed lantern is a separate code-native prop, mounted inside an existing board/bench collision footprint. It has no additional blocking obstacle. Between 18:00 and 06:00 game time, a soft static halo and ground pool appear, including on Low with ambient effects/shadows disabled. This is a small local visual consequence of saved state; it does not add a global night renderer or shared-world lighting.

Amaka and Yemi have stage-aware authored lines. Park dialogue remembers the chosen spot, and paired park chatter changes after installation. A saved request for park space remains intact; helping does not enable unsolicited approach greetings. Active lunch-favour instructions keep their dialogue priority so a second errand cannot hide delivery guidance.

## Persistence and economy

`errand: {stage, spot}` is an additive JSON field; older saves default to available/empty. JSON save version remains 1 and SQL remains migration 2. Career progress, home inventory, starter history, lunch favour, relationships, private drafts and world seed are retained. The carried lantern is a quest prop, separate from purchased home items.

The server enforces greeting/starter prerequisites, legal stage order, the timed repair and one installation choice. Completion pays through the existing transaction, revision, exact command receipt and append-only ledger (`square_lantern_errand`). Concurrent retries return one reward receipt. Fresh attempts to claim again or change the installed spot are rejected. Maintenance/suspension rules apply. Location/proximity and NPC schedules remain client presentation; this is not an authoritative shared-world travel system.

Back up before redeploying `main` with Coolify `/compose.yaml`; keep the existing volume/password. No new environment variable or SQL migration is needed when upgrading from 0.9. An older backend cannot interpret an active lantern repair, so rollback requires compatible code and the matching database snapshot. Production owner setup and earlier migration-2 boundaries remain in [OWNER_PANEL.md](OWNER_PANEL.md).

## Validation

- 249 game assertions: the prior 205 plus 44 errand checks. Both placement branches, locked stages, energy/timing, local save round-trips, old saves, cloud cache, dialogue memory, collision-safe anchors and Low evening visibility are covered. Actual-scene checks also cover every active errand HUD step clearing the needs panel, modal bounds, grounded tires and continuous gait.
- 14 backend tests. The shared errand HTTP contract runs against SQLite, embedded PostgreSQL and real PostgreSQL 17 in CI, covering forged/out-of-order commands, both branches, save recovery during the errand, exact replay, concurrent payout retries, independent favour/park memory, legacy defaults and one reward ledger entry. SQLite adds process-restart persistence.
- Browser export rebuilt (about 20.63 MiB; expanded WASM 35.95 MiB). Native Android debug APK rebuilt and signature-verified, version 0.10.0/code 11, ARM64/x86_64, minimum API 24, target 36.
- Browser QA uses a disposable local test save seeded with approved starter commands. It checks the actual venue/journal flow, walking and repair timer, installation/reward, reload persistence and portrait layout. Proof: [desktop placement choice](screenshots/milestone9-choice-desktop.png), [portrait placement choice](screenshots/milestone9-choice-mobile.png), [paid portrait outcome](screenshots/milestone9-complete-mobile.png), [completed desktop journal](screenshots/milestone9-journal-desktop.png), [desktop lantern](screenshots/milestone9-lantern-desktop.png) and [portrait lantern](screenshots/milestone9-lantern-mobile.png) and [reloaded portrait journal](screenshots/milestone9-journal-mobile.png). The browser wallet changed from 330 to 370 SC on completion. The disposable test clock was advanced through normal server settlement to verify evening rendering; production records were not changed.

A separate cloud-response probe covers valid JSON, proxy HTML and a refused connection; invalid bodies fail cleanly without JSON console errors. Network failures retain the existing pending-intent recovery behavior.

Physical-phone HTTPS/input/rendering and frame-time/memory/20-minute thermal testing remain pending. CI Docker/PostgreSQL checks do not establish these device measurements.

## Next

[0.11 hands-on repair tasks](ROADMAP.md) adds a small playable repair interaction with server-issued puzzle state and validated outcomes. Broader shared marketplaces, player-controlled driving and the Up NEPA! campaign remain separate milestones.
