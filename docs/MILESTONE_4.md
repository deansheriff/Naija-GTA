# Modular neighborhood foundation — 0.5.0

The prior world was one painted background with runtime actors and painted occlusion masks. Version 0.5.0 replaces that world rendering with an authored modular block and adds collision-aware player travel. The former painting remains an archived art reference, not the live scene's geometry.

## Playable changes

- Ground, road and pavement are independent code-native layers with a common world coordinate system. The first block is authored and deterministic; texture variation does not generate a random city.
- Three original painted shells and three separate roof sprites assemble Amaka's kitchen, Yemi's workshop and the player's home. Roofs fade on approach to reveal the room, then restore when the player leaves. Front wall pieces sort over room occupants while the doorway remains open.
- Shopkeepers stand inside, behind individual counters. Counters, benches, noticeboard, building walls, tree roots and the parked bus have solid footprints with player-body clearance. Furniture and the bus are separate grounded objects rather than pixels in a background.
- Keyboard movement sweeps in small steps and slides along blocked axes. Click/venue travel uses a native A* grid, verifies exact endpoints and smooths only clear segments. A blocked click does not create a false arrival. Auto-travel reaches the interior through the front doorway before opening the existing venue menu.
- Every tree has a painted trunk and a separate canopy. Gusts move the canopy while the root/collision footprint stays fixed. Optional motion/shadows respect graphics preferences; essential roof visibility and tire-contact cues remain on Low.
- Continuous ambient pedestrian routes are retained and checked against the new obstacle map. The core feet/wheel anchors, protagonist animation, traffic yielding, dogs, birds, authored chatter and elevated side camera remain.

`world/district_layout.gd` is the shared authored layout/collision/navigation definition. `world/modular_scenery.gd` builds independent visual modules from it. Custom 2D footprint collision controls locomotion; this is not a rigid-body driving or combat simulation. Roads are visually modular layers in this block; reusable intersections and seeded road-network assembly are the next extension.

## Story track

The supplied **Naija Street Life: Up NEPA!** brief is preserved with a [draft story bible](STORY_BIBLE_UP_NEPA.md) and a separate production track in [ROADMAP.md](ROADMAP.md). The bible covers three leads, themes, voices, secrets, relationships, gags, world rules and ending intentions. Full mission lists/scripts follow narrative review in the brief's requested order. No campaign mission, switchable protagonist, story currency or fictional election command is exposed by this build.

Modular rooms and traversable thresholds prepare the world for later canteen, apartment and wedding scenes. Existing cloud saves, sandbox starter activities and server schema remain compatible. Campaign checkpoints will be a separate versioned state section.

## Validation and delivery

The build runs 28 simulation checks, 18 street-activity checks, 16 actor/nature checks, 22 district checks and actual-scene layout/tire/recycled-gait checks. District regressions cover all venue pairs, front entry/rear wall blocking, bench/counter/bus collision, large-step tunneling, blocked endpoints, reproducible detours, actual controller arrival, portrait interior camera tracking, separate render modules, shell depth/front anchors, roof reveal/restoration on Low and 200 seconds of all pedestrian corridors against the obstacle map.

Browser and native Android exports use version 0.5.0, Android code 6. The native debug export is signed and verified by the export tool; physical-device HTTPS/input/rendering/performance tests remain pending. Exported JSON includes measured environment alpha bounds as well as actor bounds. Original PNGs are never altered by the measurement scripts. New art and exact built-in generation prompts are in [ART_DIRECTION.md](ART_DIRECTION.md).

The final browser build was reviewed in desktop and 390×844 portrait views, including actual venue-menu arrival and the revealed workshop with the player visible below the objective panel. Browser console checks reported no errors or warnings. Captures: [street](screenshots/milestone4-desktop.png), [desktop room](screenshots/milestone4-interior.png), [portrait room](screenshots/milestone4-mobile-interior.png). The landing page uses the current in-game street capture. The browser payload is approximately 18.96 MiB after excluding obsolete game art.

The committed browser export is what Coolify serves. Redeploy `main` through the existing Compose app; retain its database/password. No database migration is required. [Godot's AStarGrid2D documentation](https://docs.godotengine.org/en/4.6/classes/class_astargrid2d.html) describes the native routing API used here.
