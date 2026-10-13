# Movement and nature — version 0.4

The user review identified sliding legs, inconsistent facing, floating traffic, repeated pedestrian silhouettes and shopkeepers standing outside. This milestone fixes the actor presentation and adds street wildlife while preserving existing cloud characters.

## What changed

- The protagonist uses new direction-consistent walk and neutral standing sheets. Sideways left movement mirrors the entire rightward cycle; front/back use separate rows. Pose changes follow distance travelled, not the frame clock. Direction hysteresis prevents tiny diagonal changes from flickering facing. When movement stops or hits a world boundary, the stride stops and a separate idle pose plants both feet. Keyboard/click speeds are now 160/180 world units per second instead of 220/340, with a 100-unit protagonist stride.
- Alpha bounds and head anchors are measured into a committed metadata file. Feet keep the same y baseline through every pose. The source PNGs are not edited by the metadata tool. Vehicle silhouette ranges are found from the actual source alpha, avoiding coordinates from resized previews.
- Traffic uses new side-view art with nearly level wheel baselines, larger road-appropriate proportions, road-aligned rotation and permanent tire-contact patches. Optional soft cast shadows can be disabled; tire contact remains visible on Low.
- Pedestrians now include a market shopper, an office worker and an older woman with distinct clothes/body silhouettes. They use their own gait frames, not recolored copies of the player.
- Amaka works inside the kitchen stall and Yemi inside the workshop. Painted counter/workbench foregrounds cover their lower bodies. They remain reachable from their original venue buttons and nearby E interaction.
- One or two dogs roam and pause on pavement routes. One to three pied crows cross the street with changing wing poses. Medium/High add intermittent foliage gusts and a small number of drifting leaves. Ambient animation pauses wildlife/traffic/wind independently of the player's own walking animation. Portrait follows the player vertically as well as horizontally to keep walking and the park crew above the bottom HUD.

## World representation

The buildings, road and much of the vegetation **are still one painted scenery image**. Characters, traffic, animals, speech, foreground masks and leaves are separate runtime objects. Wind warps selected painted canopy zones; it is not a full physically simulated tree. Painted counter masks improve shopkeeper depth but are not enterable interiors.

This stage fixes the visible defects and establishes a reusable actor renderer. The next world milestone must replace the painted geometry with modular ground/road/building/tree layers, authored collisions, doorways and consistent ground anchors. See [ROADMAP.md](ROADMAP.md); the user's elevated side camera, NPC diversity, working shopkeepers, dogs, birds and intermittent wind are explicit requirements.

## Validation and deployment

### 0.4.1 pedestrian flow correction

Passing pedestrians now follow staggered, full-width pavement routes in both directions. They walk beyond the clipped scene and recycle at 240-unit margins, so the complete sprite exits before re-entering on the opposite side. There are no waypoint pauses or visible U-turns. Real per-frame step distance drives the sprite gait separately from the off-screen position reset, preserving facing and cadence. Named shopkeepers and the park crew retain their venue roles; dogs retain their roaming routines.

The build runs 28 economy/simulation checks, 18 street-activity checks, 16 actor/nature regressions and actual-scene layout/Low tire-grounding/recycled-gait checks. The additional pedestrian checks run every route for 200 simulated seconds, verify uninterrupted steps, stable travel direction and fully hidden resets in both directions, and cover frame-rate independence plus ambient/density toggles. Actual-scene checks force both leftward and rightward exits and verify the rendered heading and stride through recycling. Existing regressions exercise leg poses, feet baselines, idle behavior, animals and gust/quality behavior. Browser and Android exports use version 0.4.1; Android version code is 5. Original 0.4 artwork screenshots are under `docs/screenshots/milestone3-*`.

The 0.4.1 browser preview was inspected in desktop and portrait layouts; no browser console errors were reported. A current preview capture is [pedestrian-flow-v041.png](screenshots/pedestrian-flow-v041.png). New assets and exact generation prompts are documented in [ART_DIRECTION.md](ART_DIRECTION.md). The browser export includes the measured JSON metadata explicitly. Existing server schema/commands and cloud save codes are unchanged; redeploy the existing Coolify Compose app from latest `main`, keeping its database and password.

Native export/sign verification is not physical-phone performance or native HTTPS validation. Browser/Android memory, frame-time and thermal benchmarks are still required before public scaling. Animals and other ambient entities are cosmetic local state; they do not award coins or synchronize as multiplayer actors. Persistent relationships, combat, driveable travel, full interiors and an admin panel are later milestones.
