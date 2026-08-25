# Step 1: Targeting contract and controller tests

**Branch:** `fix/missile-attack-targeting` from `main`.

**Files:**

- Modify: `tests/unit/test_battle_controller.gd`
- Modify: `tests/unit/test_ranged_combat_los.gd`
- Modify: `scripts/battle/battle_controller.gd`
- Modify: `scripts/battle/grid.gd`

## Red

Add focused tests proving a bow attack with an occupied intervening tile succeeds without moving, and a bow attack beyond its current range returns false without changing position, AP, or target health. Retain an explicit melee move-and-attack test.

Run the selected tests with GUT and confirm the new assertions fail under the current fallback behavior.

## Green

Classify missile attacks from their weapon range (`attack_max_range > 1`). They may attack only currently legal targets; do not invoke `find_best_move_and_attack_tile()` for them. Stop supplying living-unit positions as line-of-sight blockers for ordinary weapon legality. Preserve movement blocking and the existing melee fallback.

Re-run the focused tests and confirm they pass.

## Verification

Run `git diff --check` and the focused BattleController and ranged-combat tests. Do not commit or merge until the user has manually verified the battle screen.
