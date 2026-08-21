# Stage 1 — Campaign Spine and Safe Failure States

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Source contract:** [`docs/implementation-roadmap.md`](../../implementation-roadmap.md#stage-1--campaign-spine-and-safe-failure-states) and the canonical [`docs/designs/campaign-loop.md`](../../designs/campaign-loop.md).

**Goal:** Close the remaining Stage 1 route and prove that a fresh Borderlands campaign remains recoverable, save-safe, and deterministic through its first authored objective.

**Architecture:** `GameSession` remains the sole owner of durable campaign and aftermath state; `GameManager` only selects scenes/routes; World Map and Battlefield controls express player intent. The existing objective graph, authored expeditions, snapshot contract, permadeath transaction, recovery economy, and campaign simulator are the baseline—not parallel systems to rebuild. The only audited missing contract is pre-battle **Withdraw**: encounter arrival currently enters battle directly.

**Tech stack:** Godot 4.7/GDScript, GUT 9.7, `CampaignSnapshot`, `ScenarioContract`/`BattleStateFactory`, headless campaign simulation.

---

## Live-checkout audit (2026-08-21)

Already present and therefore protected by this plan:

- `GameSession` owns the 12-node authored graph, progression fields, victory/free-play flags, and save/export/import (`scripts/autoload/game_session.gd`).
- The World Map and Encampment show `CampaignObjectiveBanner`; authored objectives render outside repeatable vacancy state.
- Battle Retreat, battle death cleanup, atomic recovered-item transfer, wipe forfeiture, zero-party World Map turns, and recruitment/economy recovery are implemented.
- `CampaignSnapshot` v2 validates campaign progress; `make campaign-sim` uses the documented representative seeds, while `make campaign-sim-sweep` is explicitly only a sample.

Missing: `scripts/world/world_map.gd` routes `encounter_activated` straight to `GameManager.enter_battle()`. No arrival dialog or pre-battle **Withdraw** behavior exists, despite the Stage 1 and World Map contracts.

## Sequence

| Step | Document | Objective | Branch | Depends on |
|---|---|---|---|---|
| 1 | [01-pre-battle-withdraw.md](01-pre-battle-withdraw.md) | Add the explicit encounter-arrival choice and safe, deterministic Withdraw transaction. | `feat/stage-1-pre-battle-withdraw` | `main` baseline |
| 2 | [02-withdraw-save-and-recovery-regressions.md](02-withdraw-save-and-recovery-regressions.md) | Prove withdrawal state survives save/load and cannot bypass the existing recovery and authored-objective invariants. | `test/stage-1-withdraw-regressions` | Step 1 merged |
| 3 | [03-stage-1-exit-gate.md](03-stage-1-exit-gate.md) | Add an executable Stage 1 journey test and collect deterministic/manual exit evidence. | `test/stage-1-campaign-spine-exit-gate` | Step 2 merged |

Steps are serial: their shared route and state contract makes parallel changes unsafe.

## Non-negotiable invariants

- Do not rename the persisted authored IDs or create a second campaign/encounter catalog.
- **Withdraw** is pre-battle only: it does not create battle loot, cannot kill, leaves the encounter available, and applies one independent 90% no-loss / 10% ceil(10%-of-max-HP) loss roll to each survivor.
- After either Withdraw or Battle Retreat, survivors stay at the encounter tile with a committed route to the Encampment; only Battle Retreat may cause death or discard unbanked rewards.
- The recovery route must work with zero gold and no deployable party. `GameSession`, not UI routing, owns all durable health/route/economy mutations.
- Keep actual battle construction and campaign proof on `ScenarioContract` and `BattleStateFactory`; do not make a special simulator-only model.
- Existing user-facing text is localized in `translations/en.tres` and all new controls use real `.tscn` signal wiring in tests.

## Common setup and final checks

Each step starts only after its predecessor is locally merged and the user has given manual signoff:

```bash
git checkout main && git pull
git checkout -b <step-branch>
make check
```

Every step uses red/green TDD, runs its focused GUT command, then `make check`, `godot --headless --path . --editor --quit`, and `git diff --check`. Do not push or open a PR. After the step's documented manual check, commit only the listed files, merge locally to `main`, and delete the feature branch.

## Exit evidence

Stage 1 is complete only when Step 3 records all of these as passing:

1. A fresh game names and displays its first authored objective.
2. The first objective can be entered and completed; the next objective unlocks deterministically.
3. Pre-battle Withdraw and in-battle Battle Retreat remain distinct and preserve their respective consequences.
4. A wipe, zero gold, and no party still permit World Map turns, recovery income, recruitment, and re-forming a legal party.
5. A save/load round trip preserves campaign progress and recovery state without silently banking/lossing rewards.
6. `make campaign-sim` succeeds on its documented representative seeds, and a user verifies the full route in `make play`.

## Out of scope

Stage 2 class/readiness work, general Intelligence System expansion, multi-party play, new monsters, balance retuning, broad free-play content, and presentation/audio iteration remain outside this plan.
