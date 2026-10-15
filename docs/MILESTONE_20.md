# 0.20.0 — Danfo Chase

Twelve Tunde checkpoints follow Japa Interview. Three marked public-road legs add crossings, a vehicle queue and lower-lane waiting bays; both public-road turn choices rejoin, and both source-copy choices retain the same clue. The following car supplies story pressure without timed clue loss. Completion awards three Tunde mastery once (9/6/6 on the main route) and service slip SR-18, with no StreetCoins. Phone, portfolio opportunity, family disclosure, pact and bag custody persist.

## Driving and recovery

Canonical road stages specify a gate distance and crossing/queue type. Manual driving must brake before the gate. Guided approach reaches the waiting bay and stops, but cannot clear it. The explicit Wait until the marked route clears action requires a stopped lower-lane bus within the bay. Select a fresh pace control after clearance, then reach the final safe bay. Both clearance and final readiness are required for story progression. Missing a bay gives a free correction loop. Elapsed input is bounded to one second; absence cannot drive the bus through the route.

`campaign_drive` uses the existing expected-stage, revision and durable receipt transaction. A client cannot supply clearance or readiness fields. Unsupported waits on earlier road stages are rejected. Pause, reload, save-code recovery and durable exact retries preserve waiting/cleared state. Journal navigation stops automatic driving and cannot confirm a wait; returning requires an explicit pace selection.

The above-side view reuses original painted traffic and walking atlases. A grounded following car, moving crossing pedestrians and departing queued cars accompany bounded modular scenery. Pedestrians recycle off-scene without reversing. Cosmetic prediction cannot pass an uncleared crossing. Optional ambience respects its setting; essential markings and the wait action remain available. Waiting advances an untimed authored encounter rather than simulating general traffic collision AI. Full directional cast art and deeper chase staging remain separate production work.

## Source and compatibility

Sikiru offers his retained service-desk copy at a parked public stop. SR-18 records a 21:14 assistance request for Bisi at the caterers' room; it does not settle bag ownership or the complete sequence. Private and redacted source-labelled copies both work. Permission for this record does not grant public use of a later witness interview. The service source appears in the journal only after A23 completion, alongside the retained Open Window opportunity. Missing earned copies can be restored without another reward; unearned copies cannot.

Campaign version 8 adds A23 and optional gate clearance within existing driving state. Version-7 interview checkpoints preserve portfolio answers/recovery/readiness and older phone/road/family choices. Root character version 1 and SQL migration 3 remain unchanged. Canonical chase, drive-message and journal JSON are copied into the game at build time. All twelve checkpoints, contextual responses, instructions, recovery messages and new source are in the 167-unit admin review queue. Actual cultural approval remains pending. Deploy matching static/API/native versions.

## Verification

526 new game checks cover both route turns and copy choices (eight combinations), manual overshoot/free recovery, mandatory guided stops, explicit clearance, reload/pause, once-only rewards, preservation of earlier state, earned-only restoration, actual scene controls, journal isolation, selected route responses and optional ambient animation. Total numbered game checks: 1,985 plus existing HUD/grounding/gait checks. All 39 backend tests passed, including SQLite and embedded PostgreSQL contracts, exact concurrent wait/completion retries, recovery/restart, elapsed-time bounds, forged input rejection and canonical review coverage. CI additionally verifies PostgreSQL 17, Docker/Compose startup and backup/restore.

Browser and native debug exports succeeded. Exact browser hashes/bytes are in `web/dist/build-info.json`; compressed payload is approximately 21.8 MiB. Android is 0.20.0/code 22, minimum API 24/target API 36, ARM64/x86_64, with a verified debug signature. A real Android device, native HTTPS/input/frame-time/memory/thermal checks and production signing remain unverified.

Desktop 1280×720 and phone 390×844 browser review used a disposable version-7 completed-interview fixture. It covered manual missed-crossing recovery, guided waiting, reload at the first waiting bay, explicit clearance and fresh pace selection, both comic detours, queue clearance, final crossing, source cards, redacted copy and completion/journal retention. Screenshots are in `docs/screenshots/milestone20-*`. A phone-sized browser view is not physical-touch/device evidence.

Continue Aso-Ebi Infiltration, the rest of Spread, fictional Election Day/all four endings and the release gates in [PRODUCTION_PLAN.md](PRODUCTION_PLAN.md). This milestone does not establish full-game production readiness or an updated Coolify deployment.
