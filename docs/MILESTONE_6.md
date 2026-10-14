# NPC routines and persistent relationships — 0.7.0

Amaka and Yemi now leave their counters, take pavement breaks, return to work and walk off the street at closing time. Their original identities have new four-pose walking art and separate neutral idle poses. Feet remain grounded and distance drives the stride. Named-character routines remain on Low even with decorative ambient effects disabled. Conversations hold their movement; after closing the conversation, they take a route to the current scheduled destination without a visible teleport. Reopening during the night starts them off-scene.

## Daily life

Schedules use the existing game clock (0.8 game minutes per real second). Both open at 06:00. Amaka takes tea at 08:30–09:00 and lunch at 12:00–13:00, then closes at 20:00. Yemi takes tea at 08:45–09:00 and lunch at 12:15–13:15, then closes at 19:00. Morning tea is deliberately early enough to demonstrate routines in a short session. Home exits lead off the left/right edge along the north pavement. These two shopkeepers never enter the main traffic lanes. Building/counter routes use the same collision-safe navigation as the player.

Tap a shopkeeper, press E nearby, or use the venue's Talk/Find button. Finding a moving neighbor plans a route and checks proximity again at arrival. The food/workshop menu shows the owner's status. A note and self-service activities keep greeting, meals, practice and the radio gig reachable when owners are away. A nighttime favor can wait for the next opening; it never expires or loses its reward.

## A plate for Yemi

1. Say hello to Amaka, then talk with her and accept the covered lunch plate. You may freely decline by leaving the conversation.
2. Find Yemi and deliver the plate. His dialogue changes to acknowledge it.
3. Return to Amaka for a **one-time 30 StreetCoin** thank-you. Both become trusted neighbors, and subsequent dialogue/chatter recalls the delivery.

While active, the favor appears in the objective panel, with Take me there finding the relevant NPC on Home street. Profile shows the saved favor stage and relationships. Completing it restores the starter objective; it does not replace the radio gig. This is a sandbox favor, separate from the planned **Up NEPA!** campaign.

The park crew now remembers both introductions and requests for space. Reopening after asking for distance produces Chidi's remembered-boundary conversation. A saved request for space also suppresses the unsolicited approach greeting. You can introduce yourself later without penalties. Repeated introductions cannot farm social progress. Nearby Amaka/Yemi exchanges respond to breaks and lunch progress; cosmetic chatter has no rewards.

## Save and server behavior

New `neighbors` and `favor` fields are additive to version-1 saves. Existing coins, skills, activities and receipts remain intact. Both database adapters provide defaults when reading older JSON; the next successful command persists them. The cloud cache loader preserves these fields without local reward completion. Device-local and authoritative cloud saves remain separate.

The new `neighbor` intent accepts only authored choice IDs. The server enforces greeting, collect, deliver and thank-you order. Completion writes one 30 SC ledger entry in the same transaction as character state and the durable receipt. Repeated identical keys return the original response; changed bodies/stale revisions conflict, and a fresh key cannot claim a completed favor again. Recovery on another device restores relationships and quest progress. Schedules/proximity are client presentation, as with existing venues; the API does not establish shared-world authoritative location.

## Verification

- 163 Godot rule/model/render checks plus actual-scene UI layout, vehicle grounding and recycled pedestrian gait checks. The 40 new checks exercise both shopkeepers' work/break/home routes, bounded movement, collision/traffic-lane clearance, opening/midnight behavior, conversation pause, local/server outcome parity, old-save loading, real sprite pose changes, grounding on Low, actual alpha-row separation and remembered park boundaries.
- Eight backend tests pass locally, including the same neighbor HTTP contract against SQLite and embedded PostgreSQL: forged choices/state, order gates, repeated introductions, concurrent duplicate completion, stale devices, recovery and durable receipts after restart. CI also runs the contract against PostgreSQL 17, followed by Docker startup and Compose punctuation-password checks.
- Browser playthrough at 1280×720 and 390×844: greet, collect, find/deliver, return, receive 30 SC, reload and inspect trusted relationships/completed favor; ask the crew for space, reload and verify their remembered response. Live walking and idle transitions reviewed during lunch breaks. No browser warnings/errors in the captured check.
- Browser export rebuilt; native ARM64/x86_64 debug APK exported, signed and verified as 0.7.0/code 8. Browser payload is about 20.62 MiB; expanded engine about 35.95 MiB. Physical-phone frame-time/memory/thermal and native HTTPS/input testing remain pending.

Screenshots: [routine movement](screenshots/milestone6-routines-desktop.png), [completed favor](screenshots/milestone6-favor-desktop.png), [profile after reload](screenshots/milestone6-profile-mobile.png), [remembered park boundary after reload](screenshots/milestone6-park-memory-mobile.png).

This milestone covers the two named shopkeepers and saved park interactions. Deeper commuter/crew/household schedules, factions, combat, theft, multiplayer NPC simulation and generated AI decisions remain future work. The next numbered milestone is **0.8 authenticated owner tools and live operations**; there is no control panel yet. Campaign narrative review and physical-device/infrastructure gates continue alongside that work.
