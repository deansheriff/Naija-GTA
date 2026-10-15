# Build and verification

Pinned official Godot 4.6.3 standard/GDScript. `scripts/fetch_godot.py` verifies the portable editor against official SHA512 checksums and extracts templates with ZIP CRC checks. Tools live in ignored `.tools/`; system Java/SDK settings are not changed.

## Browser

`scripts/build.ps1 -Target web` copies canonical campaign JSON into the game, exports the street review catalogue with source hashes, imports resources, checks script compilation, measures alpha bounds without editing PNGs, runs 28 simulation, 18 street-activity, 16 actor/nature, 22 district, 39 world/travel, 40 NPC, 10 owner-control, 32 career/inventory, 44 errand, 20 radio, 66 campaign, 41 Tunde-driving, 110 Ajo Day, 162 Four Percent 235 Family Meeting 261 Generator Wars and 26 cloud-protocol checks (1,170 total), plus actual-scene HUD/modal-fit/tire-grounding/recycled-gait checks. It exports single-threaded WebGL 2/WASM and packages `web/dist`. The loading shell streams gzip WASM through DecompressionStream. Same-origin game fetches bypass cache and the engine script has a content hash to avoid mixed build versions.

The illustrated street uses independent building shells/roofs, tree trunks/canopies, actor atlases and code-native ground/road/pavement/furniture. Version 0.7 adds named NPC routines, walking art and saved relationship/favor dialogue on top of the 0.6 seeded districts/T junctions, guided danfo boarding/travel/arrival, bounded scenery streaming and the elevated side-follow camera. The obsolete background, legacy protagonist sheet and old painting-wind shader are excluded from both exports. The browser payload is about 21.75 MiB; `web/dist/build-info.json` gives actual bytes/hashes. Both presets explicitly include `*.json` for actor/environment metadata. Expanded WASM is about 36 MiB before initialization; download size is not runtime memory. Three active transit chunks reuse art and omit navigation grids; this bounded node count is not a physical-phone memory/performance benchmark. Optional HD packs and phone frame-time/memory/thermal measurements remain pending. Version 0.12 adds a text-first Up NEPA! wedding introduction with original posed leads and separately saved checkpoints. Later acts, directional hero animation and full accessibility remain in production.

Version 0.10 adds the saved lantern errand, journal and code-native installed lantern; no new raster payload is added. Both placement branches and Low evening visibility are covered by client tests.

The 0.8 owner console is copied from `web/owner` into `web/dist/owner` by the packager; it is HTML/CSS/JS with no extra front-end build dependency. Backend tests cover owner isolation, content, code rotation, rate limits and migration 2; CI adds a PostgreSQL dump/restore comparison and append-only trigger checks.

The web shell detects `/api/health` and supplies a same-origin endpoint when available. Otherwise the game can use local saves or a manually configured server. Cloud caches do not complete/award activities locally. Pending intents persist before network submission. Graphics and local credentials remain device-local; progress is authoritative when connected.

## Android

Configure an existing Android SDK and JDK using `scripts/configure_android.ps1`, then build `-Target android`. This machine uses the existing Android Studio JBR 25; Godot recommends JDK 17. Configuration is local to the portable editor. The development signing key under `.tools/` is never included in Git or used for a store release.

`build/android/naija-street-life-debug.apk` is an engine-native ARM64/x86_64 debug APK, minimum API 24, target API 36, version 0.18.1/code 20. Internet permission supports HTTPS cloud saves. Enter the actual deployed game domain in Cloud save; no API hostname/secrets are embedded. Physical phones and native HTTPS/input/rendering still need verification. A Play release requires AAB, production signing and store review.

The prior 0.1 blockout APK reached the main loop in a clean host-GPU emulator. Software SwiftShader failed GLES uniform limits. That earlier result does not establish the new artwork's phone performance or native network behavior.

## Backend / Docker

From `server/`, run `npm ci`, `npm run check`, `npm test`, `npm run build`. Local runtime uses SQLite; production requires PostgreSQL. The root Dockerfile uses a multi-stage Node build and runs as the non-root `node` user. Compose adds PostgreSQL 17 with a persistent private volume and readiness check. GitHub Actions tests a real PostgreSQL service and image startup. Docker is not installed on the authoring Windows host; do not claim a local Docker build was executed.

[Coolify/Cloudflare setup](COOLIFY.md) covers the repository settings and domain routing. The committed browser export means no Godot editor/Android toolchain is needed on the deployment server. Game source changes must be exported again before committing; Docker recompiles server changes automatically.

## References

- [Godot web export](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html)
- [Godot Android export](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html)
- [Official pinned release](https://godotengine.org/download/archive/4.6.3-stable/)
- [Coolify Compose](https://coolify.io/docs/applications/builds/docker-compose)
