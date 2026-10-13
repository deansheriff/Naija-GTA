# Street life — version 0.3

The street now has passing danfos, cars and kekes, pedestrians who walk and pause, a conductor by the parked danfo, and three original park characters: Razor, Smallie and Chidi. They act like a territorial street crew and offer introductions, banter, neighborhood advice, directions to Yemi and a link to the existing practice poll. Players can decline the conversation and leave.

## Play

Choose **Park crew** in the desktop sidebar or phone Explore menu. Tapping a crew member walks over, or opens dialogue if already near the park. E also interacts nearby. After an introduction, the crew recognizes the player during that running session. Amaka/Yemi, the crew and conductor have nearby authored speech bubbles, including exchanges between NPCs. These are scripted lines, not generated AI responses.

Traffic follows two bounded lanes, keeps a gap behind another vehicle and yields when the player is ahead in its lane. Pedestrians use authored pavement routes with idle pauses. Sprites share the existing fixed elevated side view. Painted foreground polygons place traffic behind the left tree and bus shelter; scene clipping keeps vehicles within the painted street. No nodes are continuously spawned and discarded.

Low uses one vehicle and one pedestrian, Medium three of each, and High five vehicles/six pedestrians. View distance further caps pedestrians. Named interaction characters remain available at every tier. Selecting any quality preset enables street motion; the Ambient animation switch pauses it independently. Low removes contact shadows and idle sway. The painted background, crews and traffic use original AI-generated art; prompts and provenance are in [ART_DIRECTION.md](ART_DIRECTION.md).

## Validation

- All 28 existing game simulation checks pass.
- Ten street checks cover yielding/resuming, following gaps, wrapping, density, the motion switch, bounded long-running routes, frame-rate independence, dialogue exits and actual atlas transparency.
- Actual scene layout checks pass; the sidebar scrolls within the viewport.
- Browser and native Android 0.3 exports succeed; the debug APK passes the exporter's signing/verification stage.
- Browser inspection checks movement, a player dialogue branch, visible speech bubbles, settings and portrait navigation. Screenshots are under `docs/screenshots/milestone2-*`.

The game browser payload is 14.69 MiB plus the landing image. No database schema or server command changes are needed. Existing cloud characters and save codes continue to use schema 1. Redeploy `main` in the existing Coolify Compose application with the existing password and persistent volume. The owner-domain API was healthy before this update; deployment of the new export is a separate verification.

## Limits

Traffic, pedestrian positions and chatter are local cosmetic simulation, not synchronized multiplayer state. Conversation familiarity resets on reload and is not saved as a cloud relationship. The crew does not steal balances, fight, pursue players or run quests yet. Vehicles cannot be driven or ridden to another district. Buildings remain a painted scene; full world collision, procedural scenery, layered foliage and interiors are future work. There is no admin content panel yet.

The 0.3 APK has been exported, not tested on a physical phone. Desktop/portrait browser inspection does not establish Android performance, battery use or native HTTPS behavior. Voice, street audio and optional HD packs are also future work.
