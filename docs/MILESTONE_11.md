# 0.12.0 — Up NEPA! wedding introduction

The first campaign slice is **Owambe, Owambe**, reached through **Up NEPA! · Story mode** in the desktop venue list or mobile Explore menu. It stages Tunde, Ngozi and KC with original painted character art, independent wedding scenery and 14 text-first checkpoints: entrance/invitation, clear aisle, prop-token tray, food-ticket matching, filming consent/context, original footage, blackout and title. Choices use touch/mouse/keyboard buttons with free retry hints and no rapid input. **Read summary** shortens scene text without bypassing a required task. Blackout is a static dim scene without flashing.

After the wedding, Family Meeting selects any lead and shows saved mastery/evidence. Act 1 is the next build and is labelled accordingly. This is a playable scripted introduction, not a finished open-world campaign, directional hero walk set or player-controlled driving system. Character art is posed; no static pose is presented as a walk animation.

## Persistence and isolation

Campaign version 1 is an additive `campaign` section in existing version-1 character JSON; SQL stays migration 2. Old street saves gain an unstarted campaign without losing money, jobs, favours, furniture or errands. Each successful objective writes a checkpoint. Online choices carry the expected stage and a known choice ID; the server owns perspective order, completion, one-time mastery and evidence. Forged arrays/rewards/success flags cannot update state. Existing atomic revisions and durable receipts protect concurrent/repeated steps.

The story gives no sandbox currency. While active, campaign commands and sync freeze street needs and shift existing activity/cooldown deadlines to retain their remaining time. **Pause · return to the street** saves the story and resumes ordinary street activity. Cloud outages retain the last confirmed stage and pending request; there is no offline cloud award. Local campaigns use the same rules and remain separate from online progress. Newer campaign versions are preserved and cannot be downgraded by this client.

`server/src/prologue.json` is the canonical content; the build copies it to `game/story/prologue.json`. The backend imports/copies it through TypeScript's JSON module support, including Docker. A source-equivalence check prevents a stale browser task list. The owner console's existing save inspector can read campaign progress; quest authoring is a later extension.

## Content and verification

The [mission list](CAMPAIGN_MISSIONS.md), [progression spec](CAMPAIGN_PROGRESSION.md), [opening scripts](CAMPAIGN_SCRIPTS_ACT1.md), [dialogue bank](CAMPAIGN_DIALOGUE.md) and [integration contract](CAMPAIGN_INTEGRATION.md) are drafted in the brief's order. Nneka has an explicit, corroboratable role and agency. The council contest is fictional; the receipt investigation replaces the money-evasion seed. Native-speaker/cultural review is requested and pending.

The game adds 66 campaign model/scene checks, bringing numbered checks to 335 plus actual-scene HUD/modal/grounding/gait checks. Scene tests run with an explicit `--test` user argument: normal save loading/writing and cloud configuration are bypassed, so campaign recovery tests cannot contaminate another suite or use a developer's real session. The 17 backend tests include shared SQLite/embedded PostgreSQL/CI PostgreSQL 17 campaign contracts: all perspectives/tasks, correct and wrong choices, stage skipping, duplicate requests, stale revisions, recovery, process restart, legacy/future saves and sandbox isolation. Browser/Android export and visual proof are required before pushing this milestone.

Original asset provenance and prompt are in [ART_DIRECTION.md](ART_DIRECTION.md). Browser/Android version is 0.12.0, Android code 13. Production signing, actual phones/HTTPS/thermal performance, full accessibility, later campaign acts/replay, cultural review and remote operational gates remain open under [PRODUCTION_PLAN.md](PRODUCTION_PLAN.md). The owner requested review through the admin panel; build a version-specific dialogue/cultural queue with notes and audit next, then continue Act 1 without another handoff. Providing a queue does not itself complete a real review.

Browser walkthrough verified all 14 tasks, a wrong-choice hint, scene summaries, a mid-queue reload, completion and saved Family Meeting selection on portrait/desktop. Screenshots: `docs/screenshots/milestone11-ngozi-mobile.png`, `milestone11-blackout-mobile.png`, `milestone11-family-mobile.png` and `milestone11-family-desktop.png`. Final exports passed all 335 checks and APK signature verification. Browser delivery is about 21.66 MiB; physical-device runtime performance remains unmeasured.

The latest public `/build-info.json` check returned HTTP 200 and version 0.8.0. The tunnel is reachable, but this milestone is not verified deployed on the Coolify server.
