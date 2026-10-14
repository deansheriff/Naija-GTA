# Owner tools and live operations — 0.8.0

The game now has an opt-in browser owner console at **`/owner/`**. It matches the neighborhood's cream/green visual style and works at desktop and portrait widths. No owner account or production password is enabled by default. See [owner setup and operations](OWNER_PANEL.md) for the three Coolify variables and private password-hash tool.

## Delivered

- Owner sign-in, eight-hour hashed sessions, HttpOnly/SameSite cookies, HTTPS Secure cookies, exact-origin and CSRF checks, sign-out and credential-change invalidation. Player bearer tokens cannot authorize owner requests. The panel uses external same-origin CSS/JS and a strict content policy.
- Overview of database counts, published content/status, process uptime and request/error/rate-limit counters. Paginated player saves, direct UUID inspection, recent currency ledger, suspension/resume and device-session revocation. Progress is preserved; balances cannot be edited.
- Reviewed/revision-checked publication of a street announcement, optional Amaka/Yemi introductions, new-character world seed, new-favor availability and maintenance status. Changes take an audit reason. The game consumes these controls; existing characters retain their world seed and consequential dialogue stays authored.
- Append-only owner audit for sign-ins/failures, inspections, publications, access actions, player code replacement and retention. Passwords, raw tokens and save access codes are excluded.
- Player self-service save-code replacement, revocation of other devices, preserved current session and progress. The new code is kept in private device storage when available. Lost responses can be resolved from the retained current session; no plaintext code is saved in SQL receipts.
- Shared atomic database rate buckets and explicit trusted proxy IP/CIDR configuration. Forwarded headers are ignored until actual proxies are configured. Expired-session/rate-bucket cleanup and 90-day receipt retention have an explicit CLI command; ledger/audit/history are retained.
- PostgreSQL migration 2, custom-format backup and separate-database restore scripts, and a CI restore check comparing persistent records plus restored append-only protections. Existing game save JSON stays version 1 and world layout stays version 2.

## Verification

173 Godot checks plus the existing actual-scene layout/grounding/gait review pass, including 10 new checks for old-save/new-seed preservation, generated doorway routes and edited introductions without quest-dialogue overrides. Browser and native ARM64/x86_64 debug exports are 0.8.0/code 9. Browser payload remains about 20.62 MiB; expanded engine about 35.95 MiB. Physical-phone/native HTTPS/thermal measurements remain pending.

Twelve backend tests pass locally, with shared owner/rotation/content contracts against SQLite and embedded PostgreSQL. They cover disabled access, player/owner isolation, origins/CSRF (including malformed non-ASCII headers), settings conflicts, suspension/recovery blocking, preserved favor completion, old-code invalidation, other-device revocation, retained balances, shared rate counters, spoofed forwarding headers, trusted proxy behavior, expiry, retention and append-only audit. CI repeats PostgreSQL tests against PostgreSQL 17 and exercises Docker, Compose and dump/restore.

Browser review uses disposable local credentials and fictional test saves. It covers sign-in, reviewed publication, inspection, suspend/resume with preserved state, session persistence after reload, audit, desktop/portrait layouts, sign-out and the owner announcement displayed inside the game. Production owner credentials and live player data were not used.

Screenshots: [desktop console](screenshots/milestone7-owner-desktop.png), [portrait console](screenshots/milestone7-owner-mobile.png), [published game notice](screenshots/milestone7-game-notice.png).

## Limits and next step

This is one owner role with a validated set of controls. Arbitrary quest graph editing, staff roles/MFA, verified accounts/email recovery, historical monitoring/alerts and production off-host backup scheduling/restore proof remain operational extensions. The CI restore is a disposable same-service test, not proof that the owner's host is backed up. No external scheduler, backup destination or third-party identity provider has been configured.

The next gameplay milestone is **0.9 repeatable careers and home inventory**: a repair-career loop with server-controlled eligibility/cooldowns/rewards, clearer progression and persistent home items. The Up NEPA! story bible remains ready for narrative review; campaign saves and scripts are separate future work.
