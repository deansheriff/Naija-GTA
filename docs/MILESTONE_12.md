# 0.13.0 — Admin dialogue and cultural review

The owner requested cultural/native-speaker review through the control panel. `/owner/` now has **Dialogue review**: search current dialogue, filter by status/channel, select a unit, read its scene context, dialogue, choices and retry hints, then approve it, request changes with suggested wording, or return it to pending. Review notes are required. The current catalogue contains 77 units: 14 wedding scenes plus 63 distinct park, named-neighbour, lantern and nearby-exchange variations.

This is a review workflow. Suggested changes are stored as notes and incorporated into a future game build; the panel does not execute text, edit server rules or silently publish a new story. Reviews of art, staging, additional UI and future chapters still need coverage before release. No real cultural sign-off has been completed by the development agent. Browser proof uses a disposable local account and a note explicitly marked as QA.

## Versioning, persistence and access

Each decision is tied to the current unit's SHA-256 content version, with reviewer identity, timestamp and notes. A changed context/text/choice/hint invalidates an old approval: the queue shows pending and retains the history. Old text cannot be reviewed against a stale hash. Optimistic review revisions and a PostgreSQL transaction lock prevent concurrent tabs from silently overwriting each other. Records and matching owner-audit entries are committed together; reviews are append-only, including reset-to-pending decisions.

The feature uses existing opt-in owner authentication, same-origin checks, CSRF protection, bounded input and shared rate limits. Player sessions cannot review content. Review text/notes render through DOM text nodes, not HTML. Signing out clears review content/drafts; stale responses cannot repopulate it after a session change. Saved decisions survive restart. The owner name is the reviewer recorded by this deployment; delegated staff accounts/MFA remain future hardening.

PostgreSQL migration **3** adds `content_reviews` and mutation-prevention triggers. SQLite adds equivalent tables/triggers. Existing characters, currency ledger and campaign state are retained. CI dump/restore proof now includes reviews and their append-only protection. Keep the existing database volume/password and take a backup before deploying; no reset or new production credentials are required. `/api/health` reports schema 3.

`scripts/export_review_catalogue.gd` produces `server/src/street-review.json` from actual street dialogue branches, removing repeated text and including source/generator hashes. The build refreshes it; CI verifies it against current source with normalized line endings. Wedding units come directly from canonical prologue content. Future chapters must register their units before release.

## Verification

All 335 game checks still pass. Nineteen backend tests include shared SQLite/embedded PostgreSQL/CI PostgreSQL 17 contracts for review access, CSRF/origin rejection, malformed submissions, stale content, exact retry conflicts, concurrent decisions, changed-text approval invalidation, history/audit, restart and append-only protection. Existing operations contracts also confirm that maintenance allows a player to pause/leave a campaign while other story actions remain paused.

Browser QA verified sign-in, review selection, search, empty filters, a saved request for changes, updated counts/history, mobile form fit and sign-out. Desktop and 390×844 screenshots are in `docs/screenshots/milestone12-review-*`; no browser warnings/errors were recorded. Browser/native version is 0.13.0, Android code 14. The development APK is signed/verified; production signing and physical phones remain pending.

The [production plan](PRODUCTION_PLAN.md) remains active. Continue directly into Act 1, then later acts/endings and operational/device/content release gates. Shipping this review mechanism does not itself complete cultural review or make the full game production ready.
