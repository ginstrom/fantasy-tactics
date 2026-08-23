# Stage 4 — Engagement, Pacing, and Presentation Iteration

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Source contract:** [`docs/implementation-roadmap.md`](../../implementation-roadmap.md#stage-4--engagement-pacing-and-presentation-iteration), [`docs/designs/campaign-loop.md`](../../designs/campaign-loop.md), [`docs/designs/combat-system.md`](../../designs/combat-system.md), and [`docs/designs/world-map-and-encounters.md`](../../designs/world-map-and-encounters.md).

**Goal:** Make the proven Borderlands campaign easier to understand, enjoyable to complete, and demonstrably replayable through measured, player-observed pacing and presentation iterations.

**Architecture:** Treat the complete Stage 3 campaign and its `CampaignSim` report as the baseline, not a second design source. `GameSession` remains the durable campaign/rules owner, `GameManager` remains routing-only, and scenes render state and feedback without creating it. Each iteration follows one loop: record a complete human run with the agreed protocol, identify one root cause, make the smallest approved change, and compare the result against the fixed deterministic and manual evidence.

**Tech stack:** Godot 4.7/GDScript, GUT 9.7, `GameConfig`, `CampaignSim`, `ScenarioContract`/`BattleStateFactory`, real `.tscn` UI tests, `SpriteCatalog`, `AudioManager`, and local `make play` evidence.

---

## Live-checkout audit (2026-08-23)

Already available for Stage 4:

- The Stage 3 implementation and focused exit test prove a full New Game-to-Ogre path, transactional save/load checkpoints, objective ordering, a single Victory screen, and objective-neutral free play.
- `make campaign-sim` runs the named representative seed set (`4, 9, 10, 12, 14`) and emits per-objective world-turn, recovery, gold, upgrade, party-composition, level, loss, and outcome telemetry. Generated JSON reports are local evidence and are not committed.
- Current contracts lock the campaign’s permanent rules: one active party; authored objectives are guaranteed-discoverable and clear once; Withdraw and Battle Retreat remain separate; the Stage 3 seed set must stay 5/5 unless the user explicitly approves a change.
- Presentation seams already exist: `SpriteCatalog` isolates texture lookup from game logic; World Map and Battlefield retain orthogonal 64px logical grids; `AudioManager` uses the required `Music` and `SFX` buses, backed by `default_bus_layout.tres` and structural tests.

What is intentionally unresolved:

1. The Stage 4 player-session protocol, baseline target bands, accessibility checklist, and presentation acceptance standard (D9) are not yet approved. Do not invent them while tuning.
2. No specific balance number, UI problem, asset pack, or audio replacement is pre-authorized. Implement only findings recorded by the agreed protocol and explicitly accepted in the decision log.

## Sequence

| Step | Document | Objective | Branch | Depends on |
|---|---|---|---|---|
| 1 | [01-stage-4-evidence-and-presentation-contract.md](01-stage-4-evidence-and-presentation-contract.md) | Define the decision log, reproducible play-session protocol, evidence ledger, D9 presentation/accessibility standard, and approval gates. | `docs/stage-4-evidence-contract` | clean `main` with Stage 3 complete |
| 2 | [02-baseline-campaign-study.md](02-baseline-campaign-study.md) | Capture the initial deterministic comparison and multiple complete manual-campaign records without changing runtime behavior. | `test/stage-4-baseline-study` | Step 1 merged and user accepts the protocol |
| 3 | [03-pacing-and-counterplay-iteration.md](03-pacing-and-counterplay-iteration.md) | Repair only approved, evidence-backed pacing or dominant-strategy findings through config/authored-content changes. | `feat/stage-4-pacing-iteration` | Step 2 findings prioritized and approved |
| 4 | [04-onboarding-feedback-and-accessibility.md](04-onboarding-feedback-and-accessibility.md) | Repair the highest-priority player-comprehension, feedback, and accessibility findings with real-scene regression tests. | `feat/stage-4-clarity-feedback` | Step 2 findings prioritized and approved |
| 5 | [05-world-map-battle-presentation-and-audio.md](05-world-map-battle-presentation-and-audio.md) | Meet the approved 3/4-view, targeting, hit/heal/retreat, wound, and Music/SFX evidence standard without changing logical grid or rules ownership. | `feat/stage-4-presentation` | Step 4 merged; licensed asset/provenance decision approved if assets change |
| 6 | [06-stage-4-exit-gate.md](06-stage-4-exit-gate.md) | Re-run the fixed evidence set and obtain user signoff that the campaign experience is clear and has no unaddressed repeated finding. | `test/stage-4-exit-gate` | Steps 3–5 merged |

Steps are serial. Step 1 is an explicit product-decision gate. Steps 3–5 may contain more than one small commit only when each commit resolves a separately logged finding; re-run Step 6 after the final merged iteration.

## Non-negotiable invariants

- Keep the Stage 3 campaign boundary intact: no optional Intelligence/Watchtowers/quests, multi-party dispatch, Mage/Rogue/specializations, advanced combat primitives, or broad free-play expansion.
- Do not change `CampaignSim` into a model of human play. It is deterministic regression/comparison evidence; manual sessions establish comprehension, atmosphere, and enjoyment.
- Preserve stable `obj_*` IDs, the representative seed list, objective-order/free-play invariants, snapshot transactional import, and the `ScenarioContract`/`BattleStateFactory` construction path.
- Put tunable campaign values in `GameConfig`/`config/game_config.json`; do not spread new balance literals through UI, `CampaignSim`, or tests. A new key requires a fallback/schema test.
- Preserve the 64px orthogonal logical grids and interaction hitboxes. 3/4-view sprites are bottom-anchored visual replacements only; they may not introduce isometric geometry or alter selection/facing/pathfinding semantics.
- Preserve button-only action-mode switching. WASD keeps its existing movement meaning (`A` is move-left), and free facing remains right-click-only with no AP cost.
- Use only assets whose individual source and license are recorded. Do not commit downloaded archives, player saves, generated reports, or screenshots unless the user explicitly approves an evidence/art direction path.

## Common setup and final checks

Each runtime step begins only after its predecessor is locally merged and its documented manual check has user signoff:

```bash
git checkout main && git pull
git checkout -b <step-branch>
make check
```

Use red/green TDD: add the focused failing test, record the expected failure, implement the smallest repair, and rerun green. Finish every runtime step with its focused GUT command(s), `make campaign-sim`, `make check`, `godot --headless --path . --editor --quit`, and `git diff --check`. Run `make campaign-sim-sweep` only as labelled exploratory evidence, never as a completion claim. Store session records, raw reports, screenshots, and audio notes outside Git unless a later user decision approves a durable evidence location. Do not push or open a PR.

After each documented manual check and user signoff, stage only that step’s listed files, commit, merge locally to `main`, and delete the step branch. The supervisor records the decision-log row, evidence path, merged commit, and any deferred findings before starting the next serial step.

## Exit evidence

Stage 4 is complete only when Step 6 records all of these:

1. At least the user-approved number of complete fresh manual campaigns (never fewer than three) has a reproducible session record plus the required deterministic baseline/comparison report.
2. Every repeated confusion, pacing, accessibility, atmosphere, or dominant-strategy finding is either fixed and rechecked or explicitly accepted as a deferred Stage 5 item with its evidence and rationale.
3. The fixed representative seed set remains 5/5 victories, its Stage 3 safety/budget assertions hold, and new tests cover every shipped behavior change.
4. A fresh human playthrough can identify the current objective and next unlock, understand threat/recovery/retreat consequences, read target/mode/wound feedback, distinguish victory from free play, and hear the expected music/SFX transitions under the approved accessibility settings.
5. The user signs off that the first-campaign experience is sufficiently appealing to enter Stage 5, or explicitly directs another bounded Stage 4 iteration.

## Out of scope

This plan does not implement Stage 5 expansion systems, redesign the campaign loop, promise a universal win rate, replace all art/audio, collect personal data or analytics, or change balance solely to improve an automated bot result.
