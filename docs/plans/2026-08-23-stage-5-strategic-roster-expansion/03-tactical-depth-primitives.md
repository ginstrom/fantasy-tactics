# Step 3 — Tactical Depth Primitives

**Branch:** `feat/stage-5-tactical-depth`

**Depends on:** Step 2 merged; approved terrain, visibility, dodge/parry, and opportunity-attack ordering/counterplay rows

**Milestone:** Battlefield visibility, cover, avoidance, parry, and reactions create readable decisions and counters in real encounters without breaking seeded combat reproduction.

## Files

- Modify: `scripts/battle/grid.gd`, `scripts/battle/unit.gd`, `scripts/battle/battle_controller.gd`, `scripts/battle/battlefield.gd`, `scenes/battle/battlefield.tscn`, `scripts/battle/unit_info_panel.gd`, and `translations/en.tres`.
- Modify when the approved terrain/content design requires it: `scripts/autoload/game_session.gd`, `scripts/tools/battle_scenarios/battle_state_factory.gd`, `scripts/tools/battle_scenarios/scenario_contract.gd`, `config/debug_scenarios.json`, and `config/game_config.json` plus `scripts/autoload/game_config.gd`.
- Modify/Create: `tests/unit/test_grid.gd`, `tests/unit/test_battle_controller.gd`, `tests/unit/test_battlefield.gd`, `tests/unit/test_battle_state_factory.gd`, `tests/unit/test_scenario_runner.gd`, `tests/unit/test_ranged_combat_los.gd`, and focused tactical scenario fixtures.

## Red/green tasks

1. Write failing geometry/unit tests for the approved visibility and terrain representation. Preserve existing range/line-of-sight behavior as a protected baseline; do not relabel its existing unit-blocker test as battlefield fog.
2. Run the focused grid/controller tests and record red output.
3. Implement a single authoritative visibility/cover query in the battle domain. Rendering must consume that query; it may not maintain independent fog or cover rules.
4. Add failing deterministic combat tests for the approved resolution order: cover applies only to missile guard, dodge only to eligible attacks, parry only to eligible melee attacks, off-balance/counter bonuses expire at the documented time, and an opportunity attack occurs exactly once when a legal adjacent departure triggers it.
5. Implement the minimal `Unit` state and `BattleController` resolution path. Use the factory's per-iteration seeded RNG for every new chance; include result metadata so logs/UI can distinguish blocked, dodged, parried, reaction, and cover outcomes without colour-only feedback.
6. Add one authored or repeatable encounter/terrain layout per primitive only after its player counter is approved. Update monster AI only to make that encounter solvable/readable; do not add pack AI, broad statuses, or penetration.
7. Add ScenarioContract fixtures that prove both sides of each choice and replay identically. Run the scenario runner with a fixed seed before and after an unrelated seed to prove no hidden global RNG coupling.
8. Run focused tests, `make campaign-sim`, and the common final checks.

## Manual check

In `make play`, identify visible versus stale space, cover, the valid reaction trigger, and the resulting log/feedback without consulting test data. Confirm Move/Attack remain button-only, right-click facing costs no AP, and a reaction neither duplicates nor bypasses normal battle aftermath.

## Commit and local merge

After signoff, commit only the approved primitive, its encounter/AI/config, UI feedback, scenarios, and tests as `feat(combat): add Stage 5 tactical primitives`; merge locally to `main`, then delete `feat/stage-5-tactical-depth`.
