# Step 2: Deterministic Enemy Flanking Pathing

**Branch:** `feat/enemy-flanking-pathing`  
**Depends on:** Step 1 merged locally into `main`  
**Milestone:** An enemy retains nearest-target selection but spends its available move-and-attack budget to prefer rear, then side, then front attacks, deterministically.

## Files

- Modify: `scripts/battle/battle_controller.gd`
- Modify: `tests/unit/test_battle_controller.gd`
- Modify: `tests/unit/test_scenario_runner.gd`
- Modify: `scenarios/battle/flanking-tactics.json` (extend the shipped deterministic fixture rather than creating a second competing fixture)

## Setup

```bash
git status --short --branch
git checkout main && git pull
git checkout -b feat/enemy-flanking-pathing
make check
```

Expected: Step 1 is on local `main` and baseline is green. Preserve `docs/designs/combat-system.md` if it remains an unrelated user edit.

## TDD tasks

### Task 1: Specify a pure affordable attack-position ranking

**Files:** Modify `tests/unit/test_battle_controller.gd`, then `scripts/battle/battle_controller.gd`.

1. Add failing unit tests for a pure controller helper (for example `_best_enemy_attack_position(unit, target)`) with this exact ordering:
   - include the unit’s origin as a zero-cost candidate only when it can legally attack the target;
   - include each `_move_distances(unit)` tile only when `move_cost + BASIC_ATTACK_ACTION_POINT_COST <= unit.action_points_remaining` and `_can_attack_target_from(unit, candidate, target)`;
   - with defender facing right, a legal rear candidate at `(target.x - 1, target.y)` beats an already-legal front candidate;
   - without a rear candidate, a legal side candidate beats front;
   - same flank grade picks lower movement cost, then `_reading_order_is_earlier`;
   - no affordable legal attack position returns no candidate and does not mutate unit position, AP, facing, RNG, or target health.
2. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gunit_test_name=enemy_attack_position -gexit
   ```

   Expected: FAIL because enemy movement only minimizes distance/cost today.
3. Implement the helper using `get_flank_type(candidate, target.grid_position, target.facing)` and a local numeric rank (`front = 0`, `side = 1`, `rear = 2`). It must read only state, not invoke an action method. Keep occupied living units as the existing blockers via `_move_distances()` and `_can_attack_target_from()`.
4. Re-run the focused tests. Expected: PASS.

### Task 2: Make enemy turns consume the selected flank route

**Files:** Modify `tests/unit/test_battle_controller.gd`, then `scripts/battle/battle_controller.gd: _take_enemy_unit_actions()`.

1. Add failing end-to-end enemy-turn tests with deterministic rolls:
   - a six-AP goblin with a direct front attack and reachable rear tile first emits one move, then one attack; the attack result has `flank == "rear"` and the expected `6 - move_cost - 3` AP;
   - block the rear with a living unit and prove a reachable side tile is selected;
   - make every affordable attack tile unavailable and assert the exact existing `_best_move_toward()` fallback destination and no attack;
   - preserve nearest-player selection and existing reading-order target ties even if a farther player offers a better flank;
   - an already rear/side-positioned enemy attacks in place rather than taking a same-or-worse movement route.
2. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gunit_test_name=run_enemy_turn -gexit
   ```

   Expected: at least the rear/side preference tests FAIL under current direct-attack-first behavior.
3. Refactor the enemy loop in this order each iteration:
   1. find the existing nearest living player target;
   2. ask the pure helper for the best affordable attack position;
   3. if it is a different tile, call `try_move_selected_unit()` and append the existing move-step shape, then loop so the normal public attack path resolves it;
   4. if the selected position is the origin, call `try_attack_selected_unit()` and append `last_attack_result`;
   5. if there is no affordable attack position, call the existing `_best_enemy_move()` / `_best_move_toward()` fallback unchanged.

   Never mutate `grid_position`, AP, or facing directly in the planner, and do not make `BattleBot` flank: the requested policy is enemy-only.
4. Re-run focused enemy tests and the full controller test file. Expected: PASS.

### Task 3: Prove scenario determinism on the real enemy-policy adapter

**Files:** Modify `scenarios/battle/flanking-tactics.json`, `tests/unit/test_scenario_runner.gd`.

1. Add a failing runner test that loads the existing fixture, gives the player an explicit facing that permits an enemy rear approach, runs it twice with its pinned seed, and asserts equal records plus no `"error"` outcome. It must not claim that an enemy wins more often or deals more damage.
2. Update the fixture’s explicit positions/facings and labels so its first enemy opportunity contains a reachable rear or side choice without relying on unordered unit-array placement. Keep `current_enemy_policy`, which already delegates to `run_enemy_turn()`.
3. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_scenario_runner.gd -gexit
   make scenario SCENARIO=scenarios/battle/flanking-tactics.json SEED=20260818 ITERATIONS=20
   ```

   Expected: tests pass; the scenario command exits 0 and creates deterministic JSONL output (use a temporary explicit `OUTPUT_DIR` if preserving artifacts is desired).
4. Re-run twice with the same temporary output directories and compare the generated files with `cmp`; expected: byte-identical output. Remove only those explicitly created temporary directories after inspection.

### Task 4: Full regression and manual sign-off

1. Run:

   ```bash
   make check
   make simulate RUNS=20
   git diff --check
   ```

   Expected: all checks exit 0. Treat simulator output as a smoke result, not a balance claim.
2. Manual verification:
   - Run `make play`, open **FN+F9 → Goblin Camp Battle**.
   - Place a player unit facing away from a goblin while leaving a side/rear approach within three movement tiles; end the turn and confirm the goblin moves to the best available rear (or side if rear is blocked) and its combat log/result reflects the flank.
   - Repeat with all flank tiles occupied or unreachable; confirm the goblin follows the previous closest-approach behavior instead of stalling or moving through a unit.
   - Confirm a nearby player remains the target over a farther, more flankable player.
3. Ask the user for manual sign-off before merging.

## Commit and local merge (only after sign-off)

```bash
git status --short
git add scripts/battle/battle_controller.gd tests/unit/test_battle_controller.gd tests/unit/test_scenario_runner.gd scenarios/battle/flanking-tactics.json
git diff --cached --check
git commit -m "feat(combat): make enemies seek flank attacks"
git checkout main
git merge feat/enemy-flanking-pathing
git branch -d feat/enemy-flanking-pathing
```

Do not push or open a PR.
