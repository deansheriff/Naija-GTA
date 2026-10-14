# Owner console and operational setup

Version 0.8.0 adds `/owner/`. Its public sign-in page contains no save data. Owner APIs return 404 until you explicitly configure owner access. The existing database password is unchanged.

## Enable in Coolify

Before upgrading an existing deployment, take a PostgreSQL backup and confirm its restore procedure. Migration 2 adds a command timestamp column; pre-0.8 backends use positional receipt inserts and are not compatible with that upgraded table. Deploy the matching 0.8 backend/browser together. Use a forward fix, or deliberately restore the matching pre-upgrade backup during a maintenance window if a downgrade is required; redeploying an older image alone does not downgrade the schema.

1. On your development machine, run `npm run owner:password` in `server/` (after `npm ci`). Enter and repeat a unique password of at least 16 characters at the hidden prompt. The tool prints a salted scrypt verifier; keep both the password and verifier private. Do not put a password in command arguments or paste it into chat. From an already deployed container you can instead run `node dist/owner-password.js` in an interactive terminal.
2. Set these app environment variables in Coolify, then redeploy the latest `main` using `/compose.yaml`:

| Variable | Value |
|---|---|
| `OWNER_USERNAME` | Your chosen owner username, 3–40 letters/numbers/underscore/hyphen |
| `OWNER_PASSWORD_HASH` | The complete `scrypt1:…` output from the tool, stored as a secret |
| `PUBLIC_ORIGIN` | `https://election.sherpackage.com` — exact origin, no trailing slash or `/play` |
| `TRUSTED_PROXY_CIDRS` | Optional comma-separated IPs/CIDRs of your actual trusted proxy chain |

3. Open `https://election.sherpackage.com/owner/` and sign in with your chosen username and the original password. The hash is configuration, not the sign-in password. Keep owner credentials separate from player save access codes.

Leave both owner fields blank to disable owner APIs. Partial/invalid configuration stops startup with a generic configuration error. Changing the username or password verifier invalidates all existing owner sessions. Owner sessions expire after eight hours and can be signed out. Production requires HTTPS; development allows a localhost HTTP origin. The repository has no production owner password or default enabled account.

## Available controls

- **Overview:** database-backed save/session/receipt/ledger counts, published content, activity/favor status, process uptime and request/error/rate-limit counters. Session totals include expired rows until cleanup. Counters are per app process; this is not a historical analytics or alerting service.
- **Player saves:** paginated character list and direct UUID lookup. Inspect the saved state, access status, unexpired-session count and 30 recent ledger entries. Suspend/resume a save or sign out its devices with an audit reason. Progress and currency remain intact. Revoking sessions does not replace a save access code; a holder of a valid code can reconnect unless suspended. The panel cannot edit balances or mint recovery codes.
- **Street settings:** announcement, optional Amaka/Yemi introductory lines, new-character world seed, pause new lunch favors, or pause new activities for maintenance. Publication requires a reason and the current settings revision. Conflicting edits require a reload. Accepted favors can finish while new acceptance is paused. Maintenance rejects new commands with 423 so clients clear the rejected action and keep syncing existing results.
- **Audit trail:** paginated append-only sign-ins/failures, inspections, settings changes, player access actions, code rotations and retention runs. It excludes passwords, bearer tokens and save codes. Ledger/audit triggers protect against ordinary update/delete operations; privileged database administrators remain able to change the database itself.

Players see the announcement and activity flags in **Settings → Street notice & activity status**. Opening lines affect general introductions; consequential favor dialogue remains authored. Server settings refresh during normal cloud sync. New seeds apply only to newly created cloud characters and are saved with that character; older saves retain the original seed. Local offline play uses the original defaults.

## Player save-code replacement

A connected player can open **Settings → Cloud save → Replace my access code & sign out other devices**. The game explains the change before submission. The old code is invalidated, other sessions are revoked, the requesting session remains, and a newly generated access code is shown in the existing masked code field. Save revision increases; progress does not reset. Private device storage keeps the replacement code when available.

The replacement operation never saves a plaintext code or token in the database/receipt table. If its response is lost, the current session can reconnect and request another replacement; the latest successful replacement is the valid code. Code replacement waits until pending gameplay commands finish. This is self-service credential rotation, not email accounts, identity verification or recovery after losing both the code and session. Those remain future work; an owner cannot safely identify a lost-save claimant from a display name alone.

## Coolify and Cloudflare proxies

The API now uses PostgreSQL-backed atomic rate buckets shared across app instances. Defaults are 180 general API requests/minute per resolved IP, 10 guest creations/minute and 5 session recovery or owner sign-in attempts/minute. Rejections include `Retry-After`. These prototype limits can affect a busy shared IP.

Forwarded headers are ignored by default. Before wider access, identify the IP/CIDR of the Coolify proxy and any actual intermediary proxy addresses, then set only those in `TRUSTED_PROXY_CIDRS`. Do not guess container networks or trust all addresses/hop counts. All untrusted requests to a proxy otherwise share its IP limit. Keep the origin private to the intended proxy path and test legitimate client IP resolution. This follows [Fastify's IP/CIDR proxy configuration](https://fastify.dev/docs/latest/Reference/Server/#trustproxy); forwarding headers from arbitrary clients must not determine their rate-limit identity.

Keep `/api/*` and `/owner/*` outside Cloudflare cache rules and disable Rocket Loader for the game. Owner responses use no-store, owner pages use a strict same-origin script/style policy, and write requests require both the configured Origin and a session-derived CSRF token. Owner cookies are HttpOnly, SameSite=Strict and Secure under HTTPS. Session hashes, not raw cookies, are stored in the database. There is one owner role; MFA, delegated staff roles and external alerting remain later work.

## Retention

Run `docker compose exec -T app node dist/maintenance.js` from your deployed Compose project directory, or configure that command in your existing scheduled-job tooling. It removes expired player/owner sessions, expired rate buckets and up to 2,000 receipts older than 90 days per run. It records counts in the audit trail and never deletes character progress, ledger or audit history. Receipts created before migration 2 have unknown timestamps and are retained. Requests replayed after their receipt expires still cannot reuse their stale revision to apply an old action; they refresh instead of receiving an original response. Cleanup is explicit, not a secretly installed host scheduler.

## Backup and restore proof

From the deployed Compose project directory on the Linux server (use the actual running project name/file/environment through `COMPOSE_PROJECT_NAME`/`COMPOSE_FILE` when Coolify manages them; do not start a second stack):

```bash
mkdir -m 700 -p /secure/nsl-backups
bash scripts/backup-postgres.sh /secure/nsl-backups/your-new-backup.dump
bash scripts/restore-postgres-test.sh /secure/nsl-backups/your-new-backup.dump nsl_restore_testname
```

Choose your actual private directory; the example path is not created by the app. The backup script refuses to overwrite a file and creates a custom-format PostgreSQL dump under a private umask. The restore script requires a **new** `nsl_restore_…` database; it refuses an existing target and never cleans/replaces the live database. Failed restores can leave a partial disposable database for inspection. Copy completed backups to your encrypted off-host storage using your existing tooling, schedule regular backups, and verify restore/recovery on that separate host. A local volume is not a backup.

GitHub Actions records hashes/counts from its disposable PostgreSQL 17 test data, performs `pg_dump`/`pg_restore` into a second database, compares character state, sessions, receipts, ledger, settings, owner sessions, access controls and audit, then probes restored append-only triggers inside rolled-back transactions. This proves the tested database format can restore; it does not establish that your production host has an off-host backup schedule or a measured recovery objective. The workflow uses PostgreSQL's supported [custom archive backup](https://www.postgresql.org/docs/17/app-pgdump.html) and [restore utility](https://www.postgresql.org/docs/17/app-pgrestore.html).

SQL migration **2** adds operations tables and receipt timestamps transactionally under the existing advisory lock. Game save JSON remains **version 1**; world layout remains **version 2**. Do not delete the PostgreSQL volume to install this release.
