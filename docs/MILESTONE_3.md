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

The build runs the 28 economy/simulation checks, 10 street-activity checks, 16 actor/nature regressions and actual-scene layout/Low tire-grounding checks. Regressions exercise a full stride without facing changes, mirrored left movement, front/back selection, stable diagonal facing, feet baselines, idle/frame-count independence, changed lower-body pixels, a dedicated grounded standing pose, dog/bird movement and gust/quality behavior. Browser and Android exports use version 0.4.0; Android version code is 4. Screenshots are under `docs/screenshots/milestone3-*`.

New assets and exact generation prompts are documented in [ART_DIRECTION.md](ART_DIRECTION.md). The browser export includes the measured JSON metadata explicitly. Existing server schema/commands and cloud save codes are unchanged; redeploy the existing Coolify Compose app from latest `main`, keeping its database and password.

Native export/sign verification is not physical-phone performance or native HTTPS validation. Browser/Android memory, frame-time and thermal benchmarks are still required before public scaling. Animals and other ambient entities are cosmetic local state; they do not award coins or synchronize as multiplayer actors. Persistent relationships, combat, driveable travel, full interiors and an admin panel are later milestones.
