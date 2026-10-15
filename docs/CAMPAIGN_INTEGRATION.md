# Up NEPA! — systems and checkpoint integration

Fifth narrative deliverable, after mission list, progression, Prologue/Act 1 scripts and dialogue bank. This specifies the full target; shipped subsets must be identified separately. Through 0.17, the campaign uses JSON version 5, root character version 1 and SQL migration 3, with earlier wedding/road/record/phone progress retained. The wedding and Act 1 main checkpoint route are implemented; full animation, later acts, side activities, replay and release validation still follow.

## Authority and saves

Store `campaign` with its own `version`, `chapter`, `stage`, `lead`, completed mission IDs, mastery, meters, evidence/source facts, relationships/choices, seen incidents, ending record and checkpoint. Missing field upgrades to an unstarted campaign. Server snapshots and local save loaders validate known IDs, bounds and content version. Unknown future campaign versions are preserved and blocked from downgrade writes rather than silently reset. Online clients never upload a local campaign to replace a server save.

Use intent commands inside the existing atomic character transaction and durable receipt mechanism. A start command creates a run; task commands name the expected mission/stage and an allowed choice; switch commands only work at declared boundaries. The server reads the canonical content, validates the current task and prerequisites, changes progress, then commits one revision. No `success`, reward, evidence array or meter value from the client is authoritative. A repeated key returns the exact prior snapshot; a changed body or stale revision conflicts. Serialize UI requests and refresh on conflict. Maintenance/suspension policies apply to story commands too.

Stage checkpoint is written after each accepted objective, before showing its acknowledgement. Restart/recovery loads that stage, current puzzle and confirmed choices. Text scenes can be skipped to an authored summary, preserving their scripted effects; gameplay tasks remain required. During cloud outage, show the last confirmed state, keep the existing pending request for retry and do not advance locally. Local play mirrors rules but remains explicitly separate.

Campaign actions must not age sandbox needs or settle unrelated activities: update its paused clock reference without awarding sandbox rewards, and prevent concurrent sandbox mutation while a campaign scene is active. Returning to the street resumes the ordinary sandbox loop. Likewise an idle campaign does not drain meters while the sandbox is being played. Do not conflate the sandbox's `poll` with a story council contest.

The initial prologue uses one content file read by server and game to prevent task/choice drift. Build checks validate unique/stable IDs, links, known leads, at least one reachable solution, valid reward bounds and summary presence. Later acts extend the same content/version contract. Keep story branches explicit and inspectable rather than embedding untestable strings throughout UI callbacks.

## Scene/input contract

Use in-engine painted staging under the existing elevated side camera. Prologue establishes invitation/dress code, food-ticket matching, prop spraying and consenting filming with three recognisable leads. Task controls have text labels, touch targets, keyboard focus, readable feedback and untimed alternatives. Wrong answers return a useful hint and do not deduct currency. Cutscenes have pause, next, summary and resume. Reduced motion replaces blackout with a static “Power out” state and never flashes. Low retains all cues. Readable HTML accessibility companions and native screen-reader work are release gates; canvas keyboard support alone is insufficient.

Original hero atlas, portable modular hall/canteen/props, bus and charging locations are game assets, not a screenshot pretending to be a world. Full directional walk cycles must be verified in motion before free movement uses a new hero. Use static posed staging honestly during the first scripted slice; do not stretch/relabel the old sandbox hero as three people.

## Shared systems

| System | Integration / boundary |
|---|---|
| Gigs and careers | Campaign side jobs use protagonist mastery and one-time unlock receipts. Existing sandbox career balances remain independent. Practice variants give no farmable rewards. |
| Transport | Reuse bounded streamed roads/elevated camera; scripted routes introduce player lane/turn decisions, safe crossings, pause and recovery. Mission location is checkpoint state. Do not claim guided transport already constitutes player-controlled chase gameplay. |
| NPCs | Named voices and consequential testimony are authored. Cosmetic routines cannot award evidence, revoke consent or change a mission outcome. |
| Council contest | Local fictional support/credibility flags and authored debate, never real votes, real candidate identities or the sandbox private poll. |
| Jev AI | Optional ambient-only future adapter after provider/key/budget choice. Timeout/failure falls back to authored bank. Critical clues and objectives remain deterministic. |
| News | Optional licensed ambient radio with source/time labels and an offline fictional fallback. Never insert real allegations into fictional missions or require a live API to finish. |
| Reward games | Later reuse task controls as non-monetary practice. Real airtime, payments and redemption need a separately specified product; no silent linkage. |
| Art/audio | Original painterly atlas and code-native scenery, provenance manifest. Commissioned/licensed music/voice only; textual scene direction is not a music licence. Optional HD assets need measured budgets. |
| Owner console | Existing save inspection can inspect campaign JSON; later authoring requires validated versioned content, preview and audit. Do not expose token/save-code fields in story telemetry. |

## Ending/replay contract and quality gates

Before A33, show all ending requirements and the A32 recovery paths. Ending command validates those conditions, records an immutable original outcome and protagonist epilogues once. Chapter replay uses isolated state with no persistent reward/relationship writes; other endings can be previewed without erasing the original. Never implement destructive restart as the only replay.

Automate all paths: fresh/legacy/future saves, wrong/out-of-order choices, duplicate requests and concurrent completion, restart/recovery, all four endings, consent alternatives, zero-meter recovery, task/summary skip equivalence, offline/pending conflicts, sandbox isolation and non-farmable chapter replay. Review desktop/portrait keyboard/touch and animation; test actual mobile memory/frame times/thermal/input/HTTPS. Production requires full content, cultural review, accessibility, secure identity/recovery, deployment/load/backup/restore/monitoring and production Android signing/distribution. Passing a prologue slice is progress toward those gates, not the full release.
