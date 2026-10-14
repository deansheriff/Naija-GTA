# Naija Street Life — world and story roadmap

The playable sandbox and the **Naija Street Life: Up NEPA!** campaign share world technology, art direction and controls. Campaign progress will be versioned separately from existing sandbox saves. The story brief and [draft story bible](STORY_BIBLE_UP_NEPA.md) are now part of this roadmap. The campaign itself is not playable yet.

## 0.4 — Movement and nature

Implemented: consistent player facing and visibly changing leg poses, distance-based strides, grounded traffic on every graphics tier, distinct pedestrian types, shopkeepers behind their benches, roaming dogs, flying birds and occasional foliage gusts. Keep browser and native builds aligned, and validate all new art as actual animation cycles rather than only checking a still screenshot.

0.4.1 replaces short pedestrian loops with continuous pavement crossings and fully off-scene recycling; preserve that behavior when adding world obstacles.

## 0.5 — Modular neighborhood foundation

The first authored reference block is implemented in 0.5.0: independent ground/road/sidewalk layers, painted building shells and separate roofs, tree trunks/canopies, benches, counters, noticeboard and parked bus. Keyboard movement uses solid footprints; click/venue travel plans a clear route through the front doorway. Approached roofs fade to reveal the room and working shopkeepers. The elevated side camera, grounded vehicles, wildlife and continuous pedestrian crossings remain.

Version 0.6 adds deterministic seeded destination blocks and reserved northbound T-junction modules. Building order/positions, trees, furniture and surface colors vary within validated lots; roads connect and door/corridor clearance is preserved. The home block retains its starter venues. This is a bounded district kit, not an unrestricted procedural city. Performance gates still require frame-time/memory measurements on actual mobile browsers and Android devices.

Story benefit: the same modular rooms and entrances will support Ngozi's canteen, KC's apartment, wedding staging and bus-stop scenes without baking all geometry into a background painting.

## 0.6 — Vehicle travel and streamed scenery

Implemented in 0.6.0: walk to the stop, board a guided danfo ride, pull onto the road, cruise through seeded scenery and park at the destination. Home street, Market Road and Palm Junction use a shared world seed/layout version. The camera follows from above and the side in both desktop and portrait. At most three nearby transit chunks are active; incoming scenery loads before it enters view, and obsolete chunks unload behind the camera. Transit chunks skip unused navigation grids. Skip retains the arrival animation; cancelling returns to the starting stop. Essential bus movement/tire contact remains on Low with ambient animation disabled.

New districts are walkable. Starter venue shortcuts queue a ride back to Home street before continuing on foot. The transport prototype is free and does not change server balances, missions or unlocks. Travel/location is local session state; reopening starts on Home street. Dogs keep clear of the main traffic lanes; pedestrians step around the player where pavement clearance allows, then return to their through route.

Next transport extensions: player-controlled driving, lane changes, vehicles turning through junctions, traffic-aware main-road crossing decisions, richer passenger conversations and authoritative location/transport consequences if needed. Physical-device frame-time/memory/thermal gates remain pending. The current guided ride is not a shared-world traffic or rigid-body simulation.

## 0.7 — NPC routines and persistent relationships

Implemented in 0.7.0: Amaka and Yemi follow opening/work/tea/lunch/home schedules with collision-safe pavement routes and identity-matched walking art. Conversations hold their movement, and venue notes keep starter activities available while owners are away. Authored dialogue and nearby NPC exchanges react to their schedules and the new **A plate for Yemi** favor. Introductions, trusted-neighbor relationships, park-crew boundaries and quest stages persist in local/cloud saves. The one-time 30 SC favor reward uses approved server intents, durable receipts and an append-only ledger. Older version-1 saves upgrade without resetting existing progress. See [NPC routines and relationships](MILESTONE_6.md).

Extend the existing varied pedestrian cast with more named professions/ages and deeper commuter, park-crew and household routines. Cosmetic chatter and visual schedules stay local; they cannot award authoritative progress. This is a bounded authored neighborhood slice, not a general autonomous NPC simulation.

Plan faction/conflict behavior, safe ways to decline and player recovery before adding fights or theft. Any balance/inventory changes require authoritative rules. Jev-generated decisions wait for provider/key/budget confirmation; authored dialogue already works without that dependency.

## 0.8 — Owner tools and live operations

Implemented in 0.8.0: opt-in authenticated `/owner/` console with overview, paginated save/ledger inspection, suspension/resume, device revocation, validated/revision-checked content controls and append-only audit. Player self-service code replacement retains the requesting session and progress while invalidating the old code and other devices. Shared database rate limits, explicit trusted proxy IP/CIDRs, retention tooling, transactional migration 2 and PostgreSQL dump/restore CI proof are included. See [owner tools milestone](MILESTONE_7.md) and [Coolify setup/operations](OWNER_PANEL.md).

Broader quest/dialogue authoring, delegated staff roles/MFA, verified accounts/email recovery, external monitoring and actual off-host backup scheduling/restore proof remain production-readiness extensions. These are not established by a local panel review or CI restore test.

## 0.9 — Repeatable careers and home inventory

Implemented in 0.9.0: two repeatable repair jobs with server-owned eligibility, deadlines, a shared cooldown and replay-safe ledger rewards. Food and energy are spent on acceptance; free rest and paid meals provide recovery. Inverter work unlocks after three completed career jobs and Repair 4. Three cosmetic home items can be bought once, placed or stored, and rendered in the actual room. Career progress and ownership persist in local/cloud saves without resetting starter/favor history. See [career and inventory milestone](MILESTONE_8.md). Balance values are provisional and need longer player sessions before expanding the economy.

## 0.10 — Neighborhood errands and interactions

Extend the neighborhood loop with a bounded authored errand chain for the existing cast and more context-aware park/workshop dialogue. Use explicit quest stages, saved consequences and the existing receipt/ledger rules for any rewards. Keep clear routes, continuous pedestrian crossings and Low-tier animation. Shared marketplace applications, deliverables, reviews and moderation remain separate later work; expand those after the repeatable economy has been playtested.

## Up NEPA! — campaign production track

| Stage | Deliverable and dependency |
|---|---|
| S0 · Drafted | [Story bible](STORY_BIBLE_UP_NEPA.md): premise, themes, Tunde/Ngozi/KC voices and arcs, relationships, secrets, gags, world rules and ending intentions. Narrative review comes before the next story deliverable, as requested in the supplied brief. |
| S1 · Planned | Full mission list with objectives, set pieces, comedic beats and rewards, then the three-character ability/progression specification. Separate story props and campaign rewards from sandbox currency. |
| S2 · Planned | Prologue and Act 1 scripts, followed by ambient/failure/switching dialogue banks and the full systems integration specification. Tag slang and cultural delivery for native-speaker review. |
| S3 · Planned | A small replayable **Owambe, Owambe** vertical slice: wedding staging, blackout/light restoration, a tutorial perspective for each lead, Family Meeting switching, text-first cutscenes and skip summaries. Requires reviewed scripts, original protagonist art and checkpoint rules. |
| S4 · Planned | **Light Out**: the danfo/bag discovery, Ajo Day, Four Percent and Family Meeting. Add server-persisted campaign checkpoints, evidence, relationships, meters and replay-safe mission rewards. Vehicle missions depend on 0.6 travel; consequential NPC outcomes depend on 0.7 rules. |
| S5 · Planned | **Spread**, then the wholly fictional **Election Day** finale and four endings. Add scripted negotiation/chase/filming systems, bounded off-character catch-up incidents, receipt-and-witness investigations and evidence-driven public exposure. Test every branch, recovery path and ending. |

Tunde's Blood Pressure is a fictional stress meter; Ngozi's Aunty Aura supports authored negotiations; KC's Hype/Phone Battery support filming pressure. Closed-game battery drain, silent off-character losses and randomly broken story objectives are excluded. Low keeps mission cues and text staging; optional HD/voice assets follow measured download and device budgets. Blender assets are an optional future production route, not a switch away from the working Godot/browser/Android client.

The campaign's council contest is a fictional mission simulation. Do not wire it to real votes, actual elections or the current private improvement poll. The “Small Small Money” seed becomes an evidence-and-receipt collection mission rather than modeling cash-splitting or banking evasion. The Honest, Hustle, Japa and secret Receipts endings remain in the story bible.

Critical missions and dialogue remain scripted. Jev decisions and licensed live news are optional ambient additions after provider/key/budget and rights confirmation; neither can block story progression. Music style references are not permission to bundle commercial recordings. No real utility, politician, bank or telecom branding is introduced by this brief. Reward redemption and payments stay outside the campaign build.

## Release gates

Every milestone ships a rebuilt browser export, native APK, regression checks, an in-motion animation review and screenshots. Recheck the deployed version through `build-info.json`. Physical-phone HTTPS/input/rendering and 20-minute thermal sessions are separate evidence from desktop tests. Larger shared markets, real election data, payments and reward redemption remain separate later work under the original approved plan.
