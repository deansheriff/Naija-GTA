# Deploy Naija Street Life with Coolify and Cloudflare

The recommended deployment is **Docker Compose**: the root `Dockerfile` builds one browser/API image, and `compose.yaml` adds a private PostgreSQL database with persistent storage. It serves the website, `/play/` and `/api/` on one domain, avoiding cross-origin configuration or credentials embedded in the game.

## Coolify settings

1. Create a Git-based Application using `https://github.com/deansheriff/Naija-GTA`, branch `main`.
2. Choose **Docker Compose**, Base Directory `/`, Compose Location `/compose.yaml`. Use the normal Coolify-managed deployment, not Raw mode.
3. Set the required secret `POSTGRES_PASSWORD` to the database's existing password, or a long random value for a new database. Never commit the real password. For example, generate a new one locally with `openssl rand -hex 32`. Compose passes the password separately as `PGPASSWORD`; no URL encoding is needed. Enter the raw value without surrounding quotes in Coolify's Normal view. If it contains `$`, select Literal interpolation so Coolify preserves it.
4. In **Domains**, select service **app**, and enter `https://game.your-domain.example:8787`. Replace the hostname with your actual game domain. The `:8787` suffix selects the internal container port; visitors still use ordinary HTTPS, without a port suffix.
5. Deploy and check the build/runtime logs. `/api/health` should return `ok: true`; `/` is the landing page and `/play/` opens the game.

No Godot editor, Java, Android SDK, Node or PostgreSQL installation is required on the Coolify host. The repository includes the tested browser export under `web/dist`; Docker compiles the TypeScript backend during the image build. APKs are local/downloadable release artifacts, not required to run the cloud stack.

Alternatively choose **Dockerfile**, Base Directory `/`, Dockerfile `/Dockerfile`, exposed port `8787`, and set `PGHOST`, `PGPORT` (default `5432`), `PGUSER`, `PGDATABASE` and raw `PGPASSWORD` for an existing private PostgreSQL database. Its hostname must be reachable from the app container; the Compose hostname `postgres` applies only to the bundled Compose stack. `DATABASE_URL` remains supported when `PGHOST` is absent; percent-encode credentials in that URL. The Dockerfile alone does not create a database. Production startup refuses to fall back to SQLite.

## Fix an `ERR_INVALID_URL` startup failure

This happens before a database connection is made: the PostgreSQL driver cannot parse `DATABASE_URL`. A password containing URL separators, surrounding quotes, or an incorrectly assembled variable can cause it. It is not a Cloudflare routing error.

For the repository's Compose stack:

1. Redeploy the latest `main` with build pack **Docker Compose** and `/compose.yaml`. The app now receives separate PostgreSQL fields instead of assembling a URL from a raw password.
2. Keep `POSTGRES_PASSWORD` equal to the password used when your database was first initialized. Remove any manually added `DATABASE_URL` override; the new Compose fields take precedence if an old URL remains.
3. Save the environment settings and redeploy. Check the app runtime logs and `https://YOUR-GAME-DOMAIN/api/health` for `ok: true`.

For a Dockerfile deployment, supply the separate fields listed above for your existing database, then redeploy. Do not delete the database volume or generate a replacement password to fix URL parsing. Changing an environment variable does not rotate an initialized PostgreSQL role's password. Do not share full connection URLs or passwords in troubleshooting logs.

## Your existing Cloudflare setup

Exposing the Coolify dashboard does not automatically expose this game. Add a separate game hostname and route it to Coolify's application proxy, preserving the requested hostname.

- If using Cloudflare Tunnel with `cloudflared` on the host: the published application's HTTP service can point to the Coolify proxy on `http://localhost:80`, provided that is where your proxy actually listens.
- If `cloudflared` is in Docker: `localhost` refers to the tunnel container. Use the reachable Coolify proxy service/host on a shared network instead; verify its actual name and address in your setup.
- If using ordinary proxied DNS rather than Tunnel: point the game hostname at the server and configure valid HTTPS at the origin. Use Full (strict) TLS when applicable.

Configure the matching hostname in Coolify. If you set an explicit origin HTTP Host Header in Cloudflare, set it to the game hostname, not the Coolify dashboard hostname. Keep `/api/*` out of any Cloudflare Cache Everything rule; the API sends `Cache-Control: no-store`. Disable Rocket Loader for the game hostname so it does not rewrite the engine loading sequence. No WebSocket configuration is needed for the current HTTP save system.

## What persists

PostgreSQL's Compose volume holds character progress, session hashes, save-code hashes, activity deadlines, private drafts/poll choice, command receipts, ledger and schema version. The browser/Android device holds its session/access code, local graphics settings and a pending command receipt. Local cached balances never become authoritative cloud balances.

The `postgres` service has no published host port or domain. Keep it private. Do not delete the `postgres_data` volume to fix a failed deployment. Changing a password variable after PostgreSQL has initialized does not change the stored database-role password; rotate it deliberately in PostgreSQL and update the application together.

Use Coolify's database backup capability if available for your resource, or schedule `pg_dump` through your own backup tooling. Store copies off this server and test a restore before relying on cloud saves. The Compose volume survives app redeployments but is **not a backup**. Rate limits now use atomic PostgreSQL buckets shared across app instances. Configure only actual proxy IPs/CIDRs before relying on client-IP limits behind Coolify/Cloudflare. Migrations 1–2 run transactionally under a PostgreSQL advisory lock on startup. See [owner setup, retention and restore tooling](OWNER_PANEL.md).

## Owner console

Back up PostgreSQL before upgrading an existing app to 0.8. Migration 2 requires a compatible 0.8 backend; an older image alone is not a schema rollback. Keep the existing volume/password and follow the upgrade/restore guidance in [OWNER_PANEL.md](OWNER_PANEL.md).

Version 0.8 adds `/owner/`. Enable it with `OWNER_USERNAME`, `OWNER_PASSWORD_HASH` generated by `npm run owner:password`, and your exact HTTPS `PUBLIC_ORIGIN`. Owner APIs stay disabled without explicit configuration. Follow [OWNER_PANEL.md](OWNER_PANEL.md) for setup, proxy trust, access moderation, retention and backup/restore procedures.

## Players and Android

The web game discovers its same-origin API and creates/connects a cloud character automatically. In **Settings → Cloud save**, save the access code privately. In another browser, open the deployed game domain and enter that code there; the browser connects only to its own server, avoiding cross-origin credentials. Android lets you enter both the game domain and code. Anyone holding the code can access that character; email/password accounts and lost-code recovery are not implemented yet. An expired 30-day session can be renewed with the access code. A connected player can now replace the code and sign out other devices from Cloud save; the current device keeps its session.

For the native APK, enter your HTTPS game domain under Cloud save. Internet permission is included. There is no hard-coded hostname, API secret or Cloudflare service token in the APK. Browser and native use the same server command protocol. Native HTTPS/cloud interaction and physical-device performance still need verification on your actual deployed domain and phones.

If requests fail during an activity, the client keeps its command/key for retry, without awarding coins locally. If another device changed the revision, it refreshes progress and asks the player to choose the action again. Graphics settings remain per-device. Shared marketplace, multiplayer, real elections, payments and reward redemption remain future milestones.

## Rebuild the browser game

After changing `game/`, run `scripts/build.ps1 -Target web` and commit the updated `web/dist`. The export manifest lists file hashes. After Node source changes, Docker recompiles the server automatically; a Godot source change alone does not regenerate its browser export in Docker.

## Sources

- [Coolify Docker Compose deployment](https://coolify.io/docs/applications/builds/docker-compose)
- [Coolify Dockerfile deployment](https://coolify.io/docs/applications/builds/dockerfile)
- [Coolify environment variables](https://coolify.io/docs/applications/configuration/environment-variables)
- [node-postgres connection configuration](https://node-postgres.com/features/connecting)
- [Cloudflare Tunnel published applications](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/routing-to-tunnel/)
