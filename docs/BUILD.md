# Build and verification

Pinned official Godot 4.6.3 standard/GDScript. `scripts/fetch_godot.py` verifies the portable editor against official SHA512 checksums and extracts templates with ZIP CRC checks. Tools live in ignored `.tools/`; system Java/SDK settings are not changed.

## Browser

`scripts/build.ps1 -Target web` imports resources, measures source-alpha sprite bounds without editing PNGs, runs 28 simulation checks, 10 street-activity checks, 16 actor/nature regressions and actual-scene layout/tire-grounding checks, exports single-threaded WebGL 2/WASM and packages `web/dist`. The loading shell streams gzip WASM through DecompressionStream. Same-origin game fetches bypass cache and the engine script has a content hash to avoid mixed build versions.

The current illustrated street uses a painted PNG background plus protagonist/NPC/vehicle/wildlife sprite atlases. Version 0.4 fixes gait/facing and vehicle grounding, adds distinct pedestrian types, dogs/birds and masked canopy gusts, and places shopkeepers behind their benches. The browser payload is about 19.08 MiB; `web/dist/build-info.json` gives actual bytes/hashes. Both export presets explicitly include `*.json` so measured sprite metadata is available at runtime. Expanded WASM is about 36 MiB before initialization; download size is not runtime memory. Optional HD art packs and physical-phone frame-time/memory/thermal measurements remain pending.

The web shell detects `/api/health` and supplies a same-origin endpoint when available. Otherwise the game can use local saves or a manually configured server. Cloud caches do not complete/award activities locally. Pending intents persist before network submission. Graphics and local credentials remain device-local; progress is authoritative when connected.

## Android

Configure an existing Android SDK and JDK using `scripts/configure_android.ps1`, then build `-Target android`. This machine uses the existing Android Studio JBR 25; Godot recommends JDK 17. Configuration is local to the portable editor. The development signing key under `.tools/` is never included in Git or used for a store release.

`build/android/naija-street-life-debug.apk` is an engine-native ARM64/x86_64 debug APK, minimum API 24, target API 36, version 0.4.0/code 4. Internet permission supports HTTPS cloud saves. Enter the actual deployed game domain in Cloud save; no API hostname/secrets are embedded. Physical phones and native HTTPS/input/rendering still need verification. A Play release requires AAB, production signing and store review.

The prior 0.1 blockout APK reached the main loop in a clean host-GPU emulator. Software SwiftShader failed GLES uniform limits. That earlier result does not establish the new artwork's phone performance or native network behavior.

## Backend / Docker

From `server/`, run `npm ci`, `npm run check`, `npm test`, `npm run build`. Local runtime uses SQLite; production requires PostgreSQL. The root Dockerfile uses a multi-stage Node build and runs as the non-root `node` user. Compose adds PostgreSQL 17 with a persistent private volume and readiness check. GitHub Actions tests a real PostgreSQL service and image startup. Docker is not installed on the authoring Windows host; do not claim a local Docker build was executed.

[Coolify/Cloudflare setup](COOLIFY.md) covers the repository settings and domain routing. The committed browser export means no Godot editor/Android toolchain is needed on the deployment server. Game source changes must be exported again before committing; Docker recompiles server changes automatically.

## References

- [Godot web export](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html)
- [Godot Android export](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html)
- [Official pinned release](https://godotengine.org/download/archive/4.6.3-stable/)
- [Coolify Compose](https://coolify.io/docs/applications/builds/docker-compose)
