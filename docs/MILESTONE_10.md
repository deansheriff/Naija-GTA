# 0.11.0 — Playable starter radio repair

New starter radio jobs use a six-channel signal-matching task rather than paying solely when a timer expires. Turn each dial clockwise until its direction matches the marked target. Targets are labelled in words; matched channels show text and colour, and lock in the UI. Touch, mouse and keyboard operate the same controls. There is no failure timer, purchase or penalty for correcting a dial.

The test takes at least 10 seconds. After the minimum time and all six matches, Yemi's one-time reward remains 90 fictional StreetCoins, +1 Repair and a 12-energy cost. Regular fan/inverter career work and the lantern errand retain their existing rules. Close the dialog and reopen **Open radio signal test** from the activity panel to resume; the board persists across a reload or device recovery.

## Authority and compatibility

The server generates six target/initial directions with `node:crypto`. Each channel starts unmatched. `repair_move` accepts one integer tile index (0–5); it rotates that channel once. The server recomputes the match and owns eligibility, deadlines, revision, reward and ledger writes. A client-supplied solved flag, target array or balance is rejected. This validates game state; it does not establish that a human rather than a bot supplied legal moves.

Durable command receipts keep a repeated dial request from turning twice. Concurrent final-move retries return the same single payment. Solving before the deadline waits; reaching the deadline while unsolved never pays. The issued board and progress survive snapshots, recovery and process restart. Cloud caches preserve the board and cannot pay locally. The local prototype mirrors the rules without becoming an online save import path.

A pre-0.11 active radio without a puzzle keeps its original timer and pays once. Completed starter history is retained. New radio jobs require the updated browser/client; use the new APK on Android. JSON save version remains 1 and SQL remains migration 2. Back up before deployment and keep the existing volume/password. Rollback needs compatible code and its matching snapshot for activities newer than the old backend.

## Verification and scope

The game adds 20 radio model/scene checks, bringing the numbered checks to 269 plus actual-scene HUD/modal/grounding/gait checks. The shared radio HTTP contract runs on SQLite, embedded PostgreSQL and CI PostgreSQL 17. The 15 backend tests include malformed/forged moves, deadline boundaries, exact retry, stale revisions, concurrent payment, recovery, restart and pre-puzzle timer compatibility. Existing career/errand contracts solve the new radio through public moves.

Browser and Android exports are version 0.11.0/code 12. The development APK is signed/verified; production signing, physical-phone HTTPS/input/performance and the full campaign remain release gates. Visual proof is stored under `docs/screenshots/milestone10-*`.

The owner has authorised continuous work toward the full game. [PRODUCTION_PLAN.md](PRODUCTION_PLAN.md) tracks that scope and external verification needs. The next work is the full campaign production specification and separately saved campaign/checkpoint foundation, without another milestone handoff.
