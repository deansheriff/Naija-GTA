# Naija Street Life API

TypeScript/Fastify service serving the browser game and authoritative progress under one origin. Production uses PostgreSQL; local development uses SQLite. The Godot browser/native adapter sends intents, never client balances.

## Run and verify

```powershell
npm ci
npm run check
npm test
npm run build
npm run dev
```

The local server binds `127.0.0.1:8787`, serves `../web/dist`, and stores SQLite files in ignored `data/`. Set `DATABASE_URL` to use PostgreSQL. Production startup requires it and listens on `0.0.0.0`; root Dockerfile/Compose handle deployment. Set `STATIC_ROOT`, `HOST`, `PORT` only if needed. See [Coolify setup](../docs/COOLIFY.md).

## Routes

| Request | Behavior |
|---|---|
| `GET /api/health` | Application identity, mode and database readiness. |
| `POST /api/v1/guests` with `{}` | New character, 30-day session and one save access code. |
| `POST /api/v1/sessions` with `recoveryCode` | New session for the character belonging to that access code. |
| `GET /api/v1/me` | Session owner's state/revision and server time. |
| `POST /api/v1/intents` | Validate/mutate state transactionally; return next revision. |
| `DELETE /api/v1/session` | Revoke this session without deleting progress. |

Authenticated routes use `Authorization: Bearer <token>`. Intent commands require a 16–80-character `Idempotency-Key`, the last observed `revision`, and a supported `kind`. Body limit 8 KiB. All API responses send `Cache-Control: no-store`. Same-origin web delivery needs no wildcard CORS. Reverse-proxy headers are not trusted by default for IP identity; shared database rate limits key the resolved peer, which may be shared behind the Coolify proxy. Use Cloudflare edge rate limits for per-user/IP policies and evaluate proxy trust before larger deployments.

```json
{"revision":0,"kind":"begin","action":"learn"}
```

Kinds: `sync`, `greet`, `begin` (learn/gig/eat/communitymeal/rest/wash/study/fan/inverter/lantern), `decorate` (sage/clay/ocean), `profile` (name/bio), `post` (title/budget), `cancel` (jobId), `poll` (listed practice choice), `neighbor` (authored choice), `buy` (item), `furnish` (item plus place/store choice), `errand` (authored lantern choice). Drafts and polls are private to the character; they are not shared listings or actual ballots. No client coin, skill, reward, completion timestamp or local save import is accepted.

Server time owns activity deadlines. `sync` completes an existing activity once, bounds offline decay to 20 minutes and starts no new work. Wallet changes append ledger entries in the same transaction. Triggers reject ledger UPDATE/DELETE. An identical repeated command/key returns its original response; a changed body/key collision or stale revision returns 409. Rejected commands roll back. PostgreSQL locks the character row before checking receipts, so concurrent retries and writes serialize.

## Save access codes

Tokens and recovery codes contain 256 random bits; only SHA256 hashes are stored. No passwords/emails or external identity account are required yet. A save code grants ongoing access to the character and can renew expired sessions. Devices retain their credentials privately; the UI hides the code by default. Keep it safe. Players can replace a code while still signed in; lost-code recovery and managed accounts are not implemented. Do not log bearer tokens, code bodies or full database URLs.

## Persistence / tests

Migration v1 runs once transactionally under a PostgreSQL advisory lock, tracked by `schema_versions`. The adapter and migration are tested locally against embedded PostgreSQL (PGlite), plus SQLite HTTP/process-restart tests. Set `TEST_DATABASE_URL` to run the same PostgreSQL integration scenario against a real multi-connection server; GitHub Actions supplies PostgreSQL 17 and builds/starts the Docker image. Embedded serial execution validates SQL but is not proof of real row-lock concurrency; the CI service provides that check.

Tests cover ownership, strict body validation, timers, skill gates, repeated payouts, stale/concurrent writes, drafts/refunds, durable command receipts, append-only ledger, recovery-code sessions, session revocation/expiry, persistence and bounded absence. A local cache never awards a cloud activity. Native HTTPS/device interaction remains to be tested on the deployed domain.

This stack is an early self-hosted game service. Before a larger public launch, add managed identity/recovery, actual off-host backups/restores, external metrics/alerts and the remaining product systems. The Compose volume is persistent storage, not a backup. Jev/news/payment/reward integrations remain absent.

The `neighbor` command accepts `choice`: `yemi_hello`, `park_welcome`, `park_space`, `favor_accept`, `favor_deliver` or `favor_finish`. It enforces quest order; the final choice pays 30 SC once.

The 0.7 additive JSON save fields are `neighbors` (Amaka/Yemi/park familiarity plus park boundary choice) and `favor` (available/carrying/delivered/complete). Both storage adapters supply defaults for older characters without replacing existing progress. These additions retained save JSON version 1; current SQL schema is version 2. Read normalization is persisted on the next successful command. Schedules, movement and proximity are client presentation; these HTTP intents enforce quest order and rewards, not authoritative location. Shared-world location validation is future work.


## Owner operations — 0.8

See [OWNER_PANEL.md](../docs/OWNER_PANEL.md) for setup and complete behavior. `/api/owner/*` is disabled without explicit owner username/password-verifier/origin configuration. Owner cookies never authorize player intents, and player bearer tokens never authorize owner APIs. Mutations use origin/CSRF checks and audit reasons. `/api/v1/world` exposes validated public settings; `POST /api/v1/save-code` takes the current revision and replaces the authenticated player's access code while retaining its session and revoking other sessions. No raw credential is persisted in a receipt. Maintenance returns 423 for new progress actions; sync remains available.

PostgreSQL migration 2 adds operations/audit/rate tables and command timestamps. Save JSON remains schema 1, adding per-character `world_seed` (older saves default to 260713). Rate buckets are atomic/shared; trusted proxy IP/CIDR configuration is explicit. `npm run owner:password` generates a salted verifier from a hidden prompt. `node dist/maintenance.js` prunes expired sessions/rate buckets and up to 2,000 known-age command receipts older than 90 days; ledger/audit/character history and legacy undated receipts are retained. CI verifies PostgreSQL 17 dump/restore and restored append-only triggers. No external backup scheduler is installed by this code.

## Careers and inventory — 0.9

Additive JSON fields: `career: {completed, readyAt}` (absolute server milliseconds) and `inventory: {owned, equipped}`. Defaults are zero/empty for old saves; SQL remains at migration 2. No data reset or new SQL migration is needed. Do not roll back to a backend that does not understand an active `fan`/`inverter` activity: back up before deployment and restore compatible code plus data for rollback.

`begin` with `fan` requires the completed starter radio, Repair 2, energy >=23, food >=20 and no active job/cooldown. It spends 18 energy/8 food up front and pays 45 SC after 20 seconds. `inverter` requires Repair 4 and three completed career jobs, energy >=31 and food >=20; it spends 26 energy/12 food and pays 75 SC after 30 seconds. Each completion adds one Repair and one career job; both share a 45-second cooldown measured from the scheduled completion deadline. Offline settlement finishes one active job and never starts another. Meals/rest remain available during cooldown. Eligibility/deadlines/prices/rewards come exclusively from server rules.

`buy` accepts `rug` (90 SC), `plant` (60 SC) or `radio` (180 SC); it charges once and owns/places the item atomically. `furnish` accepts an owned item and `choice: place|store`, without a coin change. These cosmetic items have no stat bonuses or resale. Client rendering uses fixed desk/floor slots; location remains presentation, so HTTP intents do not enforce travel/proximity.

The shared career HTTP contract covers both storage adapters, real PostgreSQL concurrency in CI, progression gates, upfront needs, deadlines, shared cooldowns, stale/concurrent commands, exact receipt replay, one-time purchase charges, nonnegative balances and recovery. SQLite additionally tests restart persistence and legacy-state upgrade; client checks cover offline settlement, server timestamp conversion, untrusted-save filtering and furnishings/doorway access.

`communitymeal` is a free 12-second recovery activity adding 25 food, available only when food <20 and coins <25. It grants no currency or skill. Both adapters test the empty-wallet recovery path and reject repeat claims after the player is fed.

## Neighbourhood errand — 0.10

Additive `errand: {stage, spot}` defaults to `{stage: available, spot: ''}` for existing saves; JSON stays version 1, SQL stays migration 2. `errand` choices are `accept` (requires greeting Amaka and starter radio completion), `collect`, `install_board|install_bench`, and `finish`. Stage order is available → collect → repair → ready → installed → complete. `begin` with `lantern` is allowed only at repair with Repair >=1 and energy >=15; 10 seconds later it advances to ready and consumes 8 energy. It awards no skill, career-job credit or coins.

Installation records one immutable board/bench choice; returning to Amaka awards 40 SC once with ledger reason `square_lantern_errand`, +1 Social and bounded relationship updates. A request for park space is retained. Lunch favour, paid repair jobs, inventory and wall choices stay independent. No expiry or repeatable payout is added. Existing maintenance/suspension, revisions and exact durable receipts apply. Proximity/travel and lighting remain client presentation; these intents validate quest order, not authoritative location.

The shared HTTP contract tests both branches on SQLite/embedded PostgreSQL and real PostgreSQL 17 in CI, including illegal stages, forged state, the repair deadline, active-job exclusion, intermediate save recovery, concurrent payment retry, duplicate payouts, stale revisions and final recovery. SQLite also tests restart/legacy-state normalization; PostgreSQL checks the one-entry reward ledger and old-save defaults. Back up before deployment; older backends do not understand an active lantern repair, so rollback needs compatible code and its matching database snapshot.

## Radio puzzle — 0.11

New `begin/gig` activities include `active.puzzle: {turns, target, solved}`, with six integer directions (0–3). `repair_move` with `tile` (0–5) rotates one dial; the server recomputes solved status and validates the minimum 10-second test time before the existing 90 SC/Repair reward. No client board/result fields are accepted. Exact receipts protect moves and payment. Unsolved boards persist indefinitely; there is no deadline failure or silent offline completion. Pre-0.11 activities without a puzzle retain their old timer semantics. The client/cache loader validates the board and preserves it without awarding cloud work locally. The server's solved flag is derived, not a client assertion. This is state validation, not bot detection.

## Wedding campaign — 0.12

`campaign` is an additive versioned section, upgraded to unstarted for existing saves. `campaign_start`, `campaign_choose` (`stage`, `choice`), `campaign_pause`, `campaign_resume` and `campaign_switch` (`choice` lead ID) share the normal revision/receipt transaction. Canonical `src/prologue.json` defines 14 wedding checkpoints. Correct choices advance one stage, wrong choices return a retry hint without committing, and perspective order is enforced. Completion grants one mastery per lead plus original-wedding evidence, without sandbox currency. Free switching opens at the completed prologue hub; later acts are not shipped yet.

Campaign activity freezes sandbox needs and shifts any active street job/cooldown deadline across the paused interval; no unrelated work settles during story sync. Returning to the street saves/pauses the campaign, then ordinary rules resume. Cloud clients cannot upload campaign state, evidence or rewards. Legacy saves retain all prior fields; newer campaign versions are preserved and blocked from downgrade commands. SQL stays migration 2. Shared SQLite/PostgreSQL contracts cover task order, all leads, hints, duplicates/concurrency, recovery/restart, compatibility and sandbox isolation.

## Admin content review — 0.13

Authenticated owner routes: `GET /api/owner/content`, `GET /api/owner/content/:id/history?before=...`, and `POST /api/owner/content/review`. POST accepts only `unitId`, current `contentHash`, current review `revision`, status (`approved`, `changes_requested`, `pending`) and 5–2000-character `notes`. It records the configured owner identity. Reject unknown IDs, stale text, stale revisions, unauthenticated/player requests, wrong origin/CSRF and malformed fields. Notes are data, not executable/live dialogue.

`content_reviews` and its owner audit write share a transaction. PostgreSQL migration 3 adds the append-only table/trigger; SQLite has equivalent protections. A per-unit transaction lock serializes initial concurrent PostgreSQL reviews. Changed current text invalidates an old approval in the queue while retaining its history. The generated street catalogue carries normalized source/generator hashes; canonical prologue scenes provide campaign units. CI backup/restore includes reviews/protection. Actual human review remains a release requirement.

## Tunde mission/driving — 0.14

Campaign JSON version 2 adds `mission`, `choices` and `drive`. Version-1 wedding saves migrate additively to P00. `campaign_continue` moves a completed hub into the next available authored mission (A11); it cannot skip into unbuilt content. `campaign_drive` accepts the current stage and one control as `choice`: accelerate, brake, coast, upper, lower, assist. The server integrates pace/distance with its own clock capped to one second; sync alone does not drive. A lower-lane stop unlocks the route choice. Late braking offers a free loop, and guided approach has identical rewards. No client distance/speed/ready fields are accepted.

A11 awards +2 Tunde mastery and bag evidence once, without StreetCoins. Choices and road checkpoints survive recovery/restart; pause/resume resets the input clock to avoid closed-task catch-up. Future campaign versions/unknown mission IDs remain preserved/read-only on older clients. SQL remains migration 3. The mission registry also feeds the owner review queue (86 current units). Bounded HTTP driving, NAT/shared-IP request budgets and broader scale/performance need production load validation.

## Ajo Day (0.15)

Campaign version 3 adds A12 from canonical `src/ngozi-intro.json`; prior version-1 wedding and version-2 Tunde/road saves upgrade without replay. Eleven stage/choice intents validate the fictional contribution records, either agreed negotiation approach, private follow-up and invoice preservation. Completion grants campaign mastery/evidence once with no StreetCoins. Record-card headings and lines are hashed in the owner review catalogue (97 current units). SQL remains migration 3. Four Percent and later chapters remain in production.

## Four Percent (0.16)

Campaign version 4 adds A13 and nullable phone state; version-1 wedding, version-2 road and version-3 Ajo progress upgrade without replay. `campaign_phone` submits expected stage plus one known control; authoritative frame/battery/take/recovery state lives in the atomic character receipt transaction. Eleven checkpoints cover two manual/guided composition tasks, three charging responses, source/crop comparison and explicit admit/defer disclosure. Only save attempts cost the displayed one battery point; reading/time closed/panning do not drain it. Empty battery has free recovery and never deletes evidence. Completion grants KC mastery/original-source evidence once without StreetCoins. The current owner queue contains 108 units, including route variations and subject labels. SQL remains migration 3; use the updated browser/native build.

## Family Meeting (0.17)

Campaign JSON version 5 adds A14 and the earned-source journal. Earlier versions retain progress, phone and choices; SQL remains migration 3. Twelve checkpoints validate source requirements, disclosure, custody and either investigation pact. Completion grants one mastery per lead once, with no new source or StreetCoins. `campaign_review` restores only catalogue sources whose originating chapters are completed, through the same atomic revision/idempotency path. It cannot grant future testimony, advance a stage or farm mastery. The owner review queue now contains 126 units, including journal scope/status and contextual responses. Updated clients retain local journal/summary/return navigation while saves wait offline. Deploy matching static and server code before using these commands from native clients.

## Generator Wars (0.18)

Campaign JSON version 6 adds A21 while preserving earlier checkpoint/phone/meeting state; SQL remains migration 3. Thirteen stages share Ngozi/Tunde, with three existing `campaign_drive` legs, stopped junction choices, recorded permission/site/session agreements and contextual pact/custody/schedule responses. Completion grants two mastery to each of Tunde/Ngozi once, without currency or a new wedding source. Both shared schedules are valid; incorrect site/route choices retain the checkpoint. The review queue contains 139 units. All writes retain revision/idempotency validation and existing ledger isolation. Use matching updated native/browser clients.

## Client compatibility (0.18.1)

`GET /api/v1/world` adds public `capabilities`: API version, current campaign version, authored mission IDs and supported campaign commands. It retains the same public settings and no-store policy. Updated clients gate story writes until matching metadata arrives; this does not replace authoritative command validation. Kept story requests retain their key/body/revision through a mismatch, and a rollback's schema rejection triggers a support recheck before a pending story action is cleared. Reconnect after deploying matching static/API/native versions. Schema and campaign version stay unchanged in this patch.

## Japa Interview (0.19)

Campaign version 7 adds A22 and nullable portfolio state. Prior versions upgrade additively, preserving phone/road/meeting choices; SQL remains migration 3. `campaign_portfolio` validates the expected stage and listed answer/review/recovery input. Selected answers, review count, readiness and first/practice/callback route share the ordinary atomic revision/receipt transaction. Both portfolio pieces and opportunity replies complete with the same two KC mastery once, no currency and no new wedding source. The journal adds a separate completed-chapter opportunity note. Canonical task messages/options and all response variants join the 153-unit review queue. Deploy matching clients/server to advertise the new story command.

## Danfo Chase (0.20)

Campaign version 8 adds A23 while preserving version-7 portfolio, phone and family progress; root character version 1 and SQL migration 3 remain unchanged. Three driving stages have canonical crossing/queue gates. `campaign_drive` accepts `yield` only at a gated road stage; it requires the stopped lower-lane waiting bay. Guided driving reaches that bay but does not clear it. After explicit clearance, a new pace selection continues to the final safe bay. Overshooting loops freely. Final readiness and clearance are both required before story advancement. Both road-turn options and both copy choices award the source-labelled SR-18 and three Tunde mastery once, without currency. The shared SQLite/PostgreSQL contract covers all eight combinations, duplicate waits/completion, recovery and preserved earlier state. The review queue contains 167 units, including all chase controls, route responses and the new journal source. Deploy matching browser/API/native builds.

## Aso-Ebi Infiltration (0.21)

Campaign version 9 adds A24 with seventeen staged Ngozi/KC checkpoints. Version-8 gated road and portfolio/phone/family progress upgrade intact; root character version 1/SQL migration 3 stay unchanged. Existing `campaign_choose` validates the expected checkpoint, supported invitation/access/source choice and required earned evidence. `campaign_review` restores only completed sources. Private-only and redacted-text-for-later-review choices are saved in the atomic revision/receipt transaction and displayed in the journal. Both award the attributed account and two mastery each once, without currency, diary or public witness approval. The journal separates the account, folder lead and exact saved permission boundary. SQLite/PostgreSQL shared contracts cover both scopes/custodies, recovery, concurrent exact completion/permission retries and missing-source repair. The admin queue contains 187 units, including both acknowledgements and journal scope text. Matching browser/API/native deployment remains required.
