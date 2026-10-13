# Milestones after the player review

## 0.4 — Movement and nature

Implemented: consistent player facing and visibly changing leg poses, distance-based strides, grounded traffic on every graphics tier, distinct pedestrian types, shopkeepers behind their benches, roaming dogs, flying birds and occasional foliage gusts. Keep browser and native builds aligned, and validate all new art as actual animation cycles rather than only checking a still screenshot.

## 0.5 — Modular neighborhood foundation

Replace the painted-only world geometry with a reusable district kit: ground tiles, road segments/intersections, sidewalks, separate buildings, trees, furniture, roofs and shop counters. Use one clear ground plane and a feet/wheel anchor for every asset. Separate canopy/trunk layers make wind and occlusion consistent. Add collisions and traversable doorways; prevent walking through benches, buildings and the parked bus.

Build an authored reference block first, then seeded layout rules for connected roads, safe paths and sensible building/tree placement. Roads must connect; buildings and trees must not obstruct entries or spawn over pavement. Use the same fixed elevated side camera in both clients. Keep named NPCs, objectives and shops reachable at every graphics tier. Performance gates require frame-time/memory measurements on actual mobile browsers and Android devices.

## 0.6 — Vehicle travel and streamed scenery

Implement boarding, routes, departure/arrival and a camera that follows the vehicle from above and the side. Load/unload district chunks along the road, with seeds/versioned world layout so a route is reproducible. Add traffic crossings, road-aware dog behavior and pedestrian avoidance. Essential traffic/animal cues remain on Low; optional crowd density, foliage effects and richer art depend on measured budgets.

## 0.7 — NPC routines and persistent relationships

Give shopkeepers opening/work/break/home routines; introduce more ages, professions, clothes and body types. The park crew, vendors, commuters and neighbors should react to context. Expand authored player choices and NPC-to-NPC conversation graphs. Store consequential relationship/quest state on the server, with approved intents and replay-safe receipts. Keep cosmetic chatter local when it has no consequences.

Plan faction/conflict behavior, safe ways to decline and player recovery before adding fights or theft. Any balance/inventory changes require authoritative rules. Jev-generated decisions wait for provider/key/budget confirmation; authored dialogue already works without that dependency.

## 0.8 — Owner tools and live operations

Build an authenticated admin panel for NPC/dialogue content, world seeds, quest availability, player-save inspection, moderation and audit logs. Add save-code rotation/account recovery, database backups with restore proof, receipt/session retention, observability and rate limiting that works behind the Coolify/Cloudflare proxy. Keep these infrastructure checks running alongside world milestones before opening the game to wider access.

## Release gates

Every milestone ships a rebuilt browser export, native APK, regression checks, an in-motion animation review and screenshots. Recheck the deployed version through `build-info.json`. Physical-phone HTTPS/input/rendering and 20-minute thermal sessions are separate evidence from desktop tests. Larger shared markets, real election data, payments and reward redemption remain separate later work under the original approved plan.
