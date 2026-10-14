# Up NEPA! — abilities and progression

Second deliverable after [mission list](CAMPAIGN_MISSIONS.md). Values are initial tuning targets, not measured balance. Scripted campaign state is independent of sandbox food, energy, skills and currency. No upgrades are purchased with real money or StreetCoins.

## Common rules

Each lead starts at mastery 0, gains the mission awards in the list once, and unlocks three authored options at mastery 1/3/6. Milestone rewards are recorded by mission ID; replay never gives more mastery. The main route always has a baseline solution, regardless of skill, trust or optional side work. Trust and credibility are explicit flags with explanation and repair routes, not hidden morality scores. The journal shows why an ability or ending choice is locked.

Meters use 0–100 integers and change only during an active task or explicit choice. Closing or pausing preserves them. A depleted/overloaded meter redirects to free recovery without removing evidence or money. Reduced-effects and assisted controls preserve rewards and all endings. No timing task requires key mashing; an untimed labelled-choice alternative is always available.

| Lead | Meter / recovery | Abilities and unlocks |
|---|---|---|
| Tunde | Fictional **Stress**, presented in dialogue as “Blood Pressure”; starts 20. An impatient route choice adds 10, a courteous stop reduces 5. At 100, take a safe-bay breather to reset to 30. It has no medical interpretation. | Mastery 1: **Read the Road**, highlight legal route labels. Mastery 3: **Go-Slow Whisperer**, pause a route decision and explain landmarks; no speed advantage required. Mastery 6: **Conductor Combo**, ask a known passenger for an additional authored hint. Once per task; baseline text hints remain free. |
| Ngozi | **Aunty Aura**, confidence/standing; starts 50. Keeping a fair written agreement adds 5, public bluff costs 10. Below 15, a canteen break restores 50. Reputation comes from specific remembered agreements. | Mastery 1: **Read the Invoice**, compare two amounts/dates. Mastery 3: **The Stare**, a firm question that opens an authored clarification, never coerces arbitrary NPCs. Mastery 6: **Ajo Network**, ask an established ally for a route/witness lead. Refusal has an alternate records path. |
| KC | **Battery** starts at 100 except A13's staged 4; one recorded segment spends 1–10, with the cost shown first. At 0, borrow a charger, no footage loss. **Hype** starts 0; a headline can increase attention while a correction improves credibility. | Mastery 1: **Frame It**, labelled subject checklist. Mastery 3: **Go Live**, preview a fictional crowd response, broadcast only in-game. Mastery 6: **Gist Check**, compare a claim with a named source before repeating it. Recording does not establish truth by itself. |

## Switching and catch-up

P00 stages Tunde → Ngozi → KC, each with a visible handoff and checkpoint. A11–A13 introduce each lead with a mission lock; A14 unlocks free Family Meeting selection between tasks. During a task, show the reason for the lock and offer pause/resume or return to the task hub. Do not let a switch bypass a required perspective or apply its reward to another lead.

Off-character catch-up is drawn from a bounded authored bank once per completed mission, then recorded as seen. Example: Tunde's “tow” notice is a misplaced prop notice that can be clarified; Ngozi has an invoice dispute; KC's blooper has a correction prompt. They change a chat line or optional recovery objective, never spend money, remove evidence, alter ending eligibility or silently complete a critical mission. No wall-clock simulation while closed.

## Progression verification

Verify fresh saves, old sandbox saves with no campaign field, unfinished tasks after restart/recovery, duplicate completion/switch requests, out-of-order mission commands, chapter replay isolation, every free recovery path and all ending conditions. Cloud clients submit a current mission/stage/choice, never mastery, evidence arrays or a success flag. Online rewards and checkpoint transitions share the existing atomic character revision/command receipt transaction.
