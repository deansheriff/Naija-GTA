# 0.18.1 — Story compatibility and kept choices

The world-settings response now advertises API/story version, authored missions and supported story commands. The client requires matching story version and all known missions/commands before sending story actions. A missing legacy response, malformed data, older/future version or incomplete support leaves story actions read-only with update/reconnect guidance. Local play and ordinary supported sandbox actions remain available. Campaign JSON version 6, root version 1 and SQL migration 3 are unchanged.

The check runs during normal world-settings loading, without an extra request on each successful story action. Metadata is connection-local and reloaded on reconnect/refresh. It contains no sessions, save codes or owner-only settings. An unavailable initial check gives reconnect guidance; a successful legacy/mismatched check gives update guidance. The hub has a visible connection notice even when it has no scene-feedback label. Journal, summary and return navigation retain their local behavior.

An unsupported fresh story action is blocked before creating a durable request. An already pending action retains its original key/body/revision and is not repeatedly transmitted to an incompatible server. A 400 story rejection after an earlier successful handshake rechecks support before discarding an action; a rollback or failed check retains it for reconnect. Once matching support returns, retry sends the original action. A previously blocked open paused scene can resume once after reconnect; this transition never automatically reverses a normal confirmed pause.

## Verification and limits

26 client checks cover local/legacy/malformed/older/future/missing-mission/missing-command metadata, no-transmission guards, kept exact retries, rollback/recovery, sandbox independence and actual hub/journal/reconnect/resume/pause behavior. Total game checks: 1,170 plus existing HUD/grounding/gait checks. Thirty-three backend tests include a public capability contract confirming actual current commands/missions, no-store response and no change to settings/characters.

Both exports succeeded. Android metadata confirms 0.18.1/code 20, API 24 minimum/API 36 target and ARM64/x86_64, with its debug signature verified by Godot. The browser payload remains approximately 21.75 MiB; actual hashes/bytes are in `web/dist/build-info.json`.

Desktop 1280×720 and phone 390×844 browser review used a disposable loopback fixture that deliberately omitted capability metadata from an otherwise working world response. The saved Family Meeting hub visibly explained the update requirement; story controls stayed disabled, all four sources/mastery remained intact and journal/return navigation worked. Removing that fixture condition let normal refresh discover matching support, resume the same paused hub once, enable Continue and save the transition into Generator Wars. Browser warning/error logs were empty. Screenshots are in `docs/screenshots/milestone18-*`.

This is a compatibility safeguard, not evidence that the live Coolify instance or a physical Android device has been updated/tested. New native clients connected to the older public 0.8.0 server require its update before story writes. Continue Japa Interview and all outstanding full-game/release work in [PRODUCTION_PLAN.md](PRODUCTION_PLAN.md).
