# 0.19.0 — Japa Interview

Twelve KC checkpoints follow Generator Wars: read the fictional Open Window brief, prepare contribution/source/scope notes, answer a three-question portfolio board, take the written interview, record limited review permission, select a portfolio piece, retain honest credits, keep a follow-up opportunity and speak with the family. The board supports a first checked presentation, free practice and a later callback. Both the permitted solo-MC excerpt and consenting practice piece retain the same follow-up option. KC gains two mastery once, bringing the main route to 6/6/6. No StreetCoins or new wedding clue is awarded.

## Portfolio and recovery

`campaign_portfolio` accepts the current stage and one listed input. The server stores selected contribution/source/scope answers, review count, readiness, recovery requirement and presentation route in the existing atomic character/receipt transaction. Incorrect or incomplete presentations retain selections and offer practice/callback. A recovery path must be selected before edits resume. Guided answers still require a review, with identical opportunity and mastery. A ready presentation cannot accumulate extra attempts or change its route. Reading, retries, closed time and the interview do not consume the previously saved phone battery.

The answer board updates existing controls and the illustrated laptop in place. Opening the journal removes the controls and blocks portfolio input. Pausing, reload, durable retries and save-code recovery retain the task. First/practice/callback variations appear in the call dialogue. Written prompts and untimed buttons keep the objective independent of sound or rapid input.

## Sources, permission and opportunity

The original is kept privately for comparison; the MC's permission applies only to his solo introduction and this private review. It does not extend to Nneka, guests, the helping action or later public posts. The permitted excerpt is labelled with its limits; the practice piece is identified honestly. A portfolio explanation never silently resolves the earlier family disclosure choice. Wedding evidence, custody and pact remain unchanged.

After completion, the journal adds **Open Window follow-up** as a creative opportunity note, separately from its four wedding source cards. Accepting the follow-up or asking for time both keep the later decision about leaving available. First-attempt perfection and use of wedding footage are not prerequisites for that option. No external interview, upload, fellowship application or travel process is integrated.

Campaign JSON version 7 adds nullable `portfolio`. Versions 1–6 retain their earlier chapter, choices, phone and road state. Root character version 1 and SQL migration 3 remain unchanged. Canonical `japa-interview.json` and `portfolio-task.json` are copied from server to game at build time. The admin review queue contains 153 units, including all question/options, correction/recovery messages, route labels, contextual responses and the opportunity note. Actual cultural approval remains pending.

## Verification and release work

289 new game checks cover all eight answer combinations; first/practice/callback and both pieces; save normalization/recovery; invalid/forged readiness; once-only rewards; actual answer controls and in-place selected states; pause/resume; journal isolation; callback dialogue and the separate opportunity note. Total numbered game checks: 1,459 plus existing HUD/grounding/gait checks. Thirty-six backend tests include shared SQLite/embedded PostgreSQL/CI PostgreSQL 17 contracts, one full prior-chapter route plus legacy-generator fixtures, six presentation/piece paths, exact concurrent answer/completion retries, recovery/restart and canonical review coverage.

Browser/native exports succeeded. Browser payload is approximately 21.77 MiB; exact hashes/bytes are in `web/dist/build-info.json`. Android metadata confirms 0.19.0/code 21, API 24 minimum/API 36 target and ARM64/x86_64, with a verified debug signature.

Desktop 1280×720 and phone 390×844 browser review started from a version-6 Generator Wars hub. It covered the public-case opening, all preparation records, in-place wrong-answer selection, failed-review recovery across reload, callback selection with Tab/Enter, guided answers followed by keyboard review, callback-specific call text, limited permission, practice-piece choice, ask-for-time follow-up, completion at 6/6/6 and the separate opportunity note. The wrong-answer scenario deliberately used two failed reviews before the third passed; all remained recoverable without battery/source loss. The journal retained the prior unresolved disclosure, joint custody and public-case pact. Recovery feedback now appears beside review actions, and focus moves to the enabled practice control after rejection. Browser warnings/errors were empty. Screenshots are in `docs/screenshots/milestone19-*`.

Continue Danfo Chase, the remaining full campaign and release gates in [PRODUCTION_PLAN.md](PRODUCTION_PLAN.md). Full directional/cast animation, richer staging, accessibility, actual cultural sign-off, live deployment, physical Android performance/HTTPS, production signing and off-host restore remain required before production readiness.
