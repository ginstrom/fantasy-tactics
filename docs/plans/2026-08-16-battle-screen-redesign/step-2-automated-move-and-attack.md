# Step 2: Automated Pathfinding Move-to-Range-and-Attack Logic

## Objective

Implement automated move-and-attack behavior: when the player targets an enemy that is outside immediate weapon range, the selected unit automatically pathfinds to the closest valid tile within attack range/line-of-sight, moves there, and executes the attack if Action Points (AP) suffice.

## Setup

```bash
git checkout main && git pull
git checkout -b feat/battle-auto-move-and-attack
```

Read:
- `docs/battle-screen.md`
- `scripts/battle/battle_controller.gd`
- `tests/unit/test_battle_controller.gd`

## Red / Green Work

1. In `tests/unit/test_battle_controller.gd`, add failing tests:
   - `find_best_move_and_attack_tile(attacker, target)` returns the candidate tile requiring the lowest move cost that has line-of-sight and valid weapon range to the target.
   - `get_reachable_attack_targets(unit)` returns all enemies that can be attacked either from current position or by moving to a reachable green-range tile.
   - Targeting an enemy 2 tiles away with a melee weapon (1 tile range) when having 6 AP: unit moves 1 tile (spends 1 AP) and attacks target (spends 3 AP), leaving 2 AP.
   - Targeting an enemy 4 tiles away with 6 AP (requires 3 move + 3 attack = 6 AP): unit moves 3 tiles to adjacent square and attacks target, leaving 0 AP.
   - Targeting an enemy 5 tiles away with 6 AP (requires 4 move + 3 attack = 7 AP > 6 AP): attack is rejected with the exact reason `insufficient_ap`; unit position, AP, `last_attack_result`, and target health are unchanged.
   - Ranged unit whose current line is blocked by a living unit: automatically steps to the nearest reachable tile with clear line-of-sight and attacks. Do not add terrain obstacles: no terrain-obstacle model exists in this slice.
   - A target with no in-range board tile is rejected as `out_of_range`; an affordable in-range position whose every line is blocked by living units is rejected as `line_of_sight_blocked` without movement or AP spend.
   - If an enemy is already in range, `try_attack_selected_unit(target_pos)` executes immediate attack without moving.
2. Run focused tests:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gexit
   ```
   Confirm new tests fail.
3. In `scripts/battle/battle_controller.gd`:
   - Implement `find_best_move_and_attack_tile(attacker, target)`:
     - Iterates over `_move_distances(attacker)` destinations where `move_cost <= attacker.action_points_remaining - BASIC_ATTACK_ACTION_POINT_COST`; the origin is evaluated separately for direct attacks and is not a movement candidate.
     - Validates line-of-sight and distance constraints (`attack_min_range <= distance <= attack_max_range`) from candidate tile to target.
     - Picks candidate with smallest `move_cost`, tie-breaking by reading order.
   - Implement `get_reachable_attack_targets(attacker) -> Array`:
     - Returns enemies attackable immediately or reachable via move-and-attack.
   - Update `try_attack_selected_unit(target_pos: Vector2i) -> bool`:
     - If target is already in legal attack range: execute direct attack.
     - Else, if valid candidate move tile exists: move unit to candidate tile (deduct movement AP), then execute attack (deduct attack AP).
     - Else: populate `last_targeting_failure` using the index contract's deterministic precedence. Do all candidate/failure classification before mutating the attacker, so rejected targeting is atomic.
4. Rerun focused tests and `make check`.

## Milestone and Manual Check

- `make check` passes completely.
- Manual check using `make play`: Enter battle at Goblin Camp. Select a party member stationed 2-3 tiles away from a goblin. Click on the goblin directly; verify the party member automatically steps forward into melee range, strikes the goblin, deducts 1 move AP + 3 attack AP, and logs the hit/miss.

## Handoff

After user sign-off:
1. Run `godot --headless --path . --editor --quit` and `git diff --check`.
2. Commit `feat: automate pathfinding move-and-attack targeting`.
3. Merge `feat/battle-auto-move-and-attack` locally into `main` and delete the branch. Do not push.
