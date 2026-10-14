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

Authenticated routes use `Authorization: Bearer <token>`. Intent commands require a 16–80-character `Idempotency-Key`, the last observed `revision`, and a supported `kind`. Body limit 8 KiB. All API responses send `Cache-Control: no-store`. Same-origin web delivery needs no wildcard CORS. Reverse-proxy headers are not trusted for IP identity; process-local rate limits key the real socket peer, which may be shared behind the Coolify proxy. Use Cloudflare edge rate limits for per-user/IP policies and evaluate proxy trust before larger deployments.

```json
{"revision":0,"kind":"begin","action":"learn"}
```

Kinds: `sync`, `greet`, `begin` (learn/gig/eat/rest/wash/study), `decorate` (sage/clay/ocean), `profile` (name/bio), `post` (title/budget), `cancel` (jobId), `poll` (listed practice choice). Drafts and polls are private to the character; they are not shared listings or actual ballots. No client coin, skill, reward, completion timestamp or local save import is accepted.

Server time owns activity deadlines. `sync` completes an existing activity once, bounds offline decay to 20 minutes and starts no new work. Wallet changes append ledger entries in the same transaction. Triggers reject ledger UPDATE/DELETE. An identical repeated command/key returns its original response; a changed body/key collision or stale revision returns 409. Rejected commands roll back. PostgreSQL locks the character row before checking receipts, so concurrent retries and writes serialize.

## Save access codes

Tokens and recovery codes contain 256 random bits; only SHA256 hashes are stored. No passwords/emails or external identity account are required yet. A save code grants ongoing access to the character and can renew expired sessions. Devices retain their credentials privately; the UI hides the code by default. Keep it safe. Lost-code recovery and code rotation/managed accounts are not implemented. Do not log bearer tokens, code bodies or full database URLs.

## Persistence / tests

Migration v1 runs once transactionally under a PostgreSQL advisory lock, tracked by `schema_versions`. The adapter and migration are tested locally against embedded PostgreSQL (PGlite), plus SQLite HTTP/process-restart tests. Set `TEST_DATABASE_URL` to run the same PostgreSQL integration scenario against a real multi-connection server; GitHub Actions supplies PostgreSQL 17 and builds/starts the Docker image. Embedded serial execution validates SQL but is not proof of real row-lock concurrency; the CI service provides that check.

Tests cover ownership, strict body validation, timers, skill gates, repeated payouts, stale/concurrent writes, drafts/refunds, durable command receipts, append-only ledger, recovery-code sessions, session revocation/expiry, persistence and bounded absence. A local cache never awards a cloud activity. Native HTTPS/device interaction remains to be tested on the deployed domain.

This stack is an early self-hosted game service. Before a larger public launch, add managed identity/code rotation, tested off-host backups/restores, receipt/session retention, metrics, shared rate limiting and the remaining product systems. The Compose volume is persistent storage, not a backup. Jev/news/payment/reward integrations remain absent.

The `neighbor` command accepts `choice`: `yemi_hello`, `park_welcome`, `park_space`, `favor_accept`, `favor_deliver` or `favor_finish`. It enforces quest order; the final choice pays 30 SC once.

The 0.7 additive JSON save fields are `neighbors` (Amaka/Yemi/park familiarity plus park boundary choice) and `favor` (available/carrying/delivered/complete). Both storage adapters supply defaults for older characters without replacing existing progress. The SQL/save schema remains version 1. Read normalization is persisted on the next successful command. Schedules, movement and proximity are client presentation; these HTTP intents enforce quest order and rewards, not authoritative location. Shared-world location validation is future work.


## Owner operations — 0.8

See [OWNER_PANEL.md](../docs/OWNER_PANEL.md) for setup and complete behavior. `/api/owner/*` is disabled without explicit owner username/password-verifier/origin configuration. Owner cookies never authorize player intents, and player bearer tokens never authorize owner APIs. Mutations use origin/CSRF checks and audit reasons. `/api/v1/world` exposes validated public settings; `POST /api/v1/save-code` takes the current revision and replaces the authenticated player's access code while retaining its session and revoking other sessions. No raw credential is persisted in a receipt. Maintenance returns 423 for new progress actions; sync remains available.

PostgreSQL migration 2 adds operations/audit/rate tables and command timestamps. Save JSON remains schema 1, adding per-character `world_seed` (older saves default to 260713). Rate buckets are atomic/shared; trusted proxy IP/CIDR configuration is explicit. `npm run owner:password` generates a salted verifier from a hidden prompt. `node dist/maintenance.js` prunes expired sessions/rate buckets and up to 2,000 known-age command receipts older than 90 days; ledger/audit/character history and legacy undated receipts are retained. CI verifies PostgreSQL 17 dump/restore and restored append-only triggers. No external backup scheduler is installed by this code.
