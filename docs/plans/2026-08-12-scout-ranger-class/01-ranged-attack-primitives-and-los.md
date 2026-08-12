# Step 1: Ranged Attack Primitives & Line of Sight (LoS)

> **Branch:** `feat/scout-ranger-class` (or step-specific branch off `main`)

## Goal
Implement grid-level distance calculations, Line of Sight (LoS) raycasting in [`GridScript`](file:///home/ryan/play/fantasy-tactics/scripts/battle/grid.gd), and ranged target validation in [`BattleController`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battle_controller.gd).

---

## Technical Design

1. **`GridScript` Geometry Helpers (`scripts/battle/grid.gd`)**:
   - `get_chebyshev_distance(from_pos: Vector2i, to_pos: Vector2i) -> int` or Manhattan distance for range check (Chebyshev distance `max(|dx|, |dy|)` or Manhattan `|dx| + |dy|`). Standard grid distance in this game is Manhattan distance (`abs(dx) + abs(dy)`).
   - `has_line_of_sight(start_tile: Vector2i, end_tile: Vector2i, blocking_tiles: Array[Vector2i]) -> bool`: Uses 2D grid raycasting (Bresenham line algorithm). Returns `false` if any intermediate tile between `start_tile` and `end_tile` is present in `blocking_tiles`.
   - `get_attackable_tiles(from_pos: Vector2i, min_range: int, max_range: int, blocking_tiles: Array[Vector2i] = []) -> Array[Vector2i]`: Returns array of grid positions within `[min_range, max_range]` that pass LoS.

2. **`BattleController` Ranged Attack Integration (`scripts/battle/battle_controller.gd`)**:
   - Determine active unit's effective weapon `min_range` (default 1) and `max_range` (default 1 for melee, >1 for ranged weapons).
   - Update `get_legal_attack_targets(unit: Unit) -> Array[Unit]`: Finds enemy units standing on tiles within `[min_range, max_range]` of `unit.grid_position` that pass `has_line_of_sight()`.
   - Ensure basic attacks deduct 3 AP regardless of whether the attack is melee or ranged.

---

## TDD Milestones

### Red Phase (Failing Tests First)
Create `tests/unit/test_ranged_combat_los.gd`:
- `test_grid_line_of_sight_unobstructed()`: LoS between (0,0) and (0,3) is `true` when no blocking tiles exist.
- `test_grid_line_of_sight_blocked_by_unit()`: LoS between (0,0) and (0,3) is `false` when a unit occupies (0,1) or (0,2).
- `test_attackable_tiles_in_range_and_los()`: Ranged weapon with min_range=1, max_range=3 returns all tiles in range 1..3 except those blocked by LoS.
- `test_battle_controller_ranged_attack_legal_target()`: `BattleController` allows targeting an enemy 3 tiles away with a bow, but rejects targeting 3 tiles away with a melee sword (max_range=1).
- `test_ranged_attack_spends_3_ap()`: Executing a ranged attack deducts 3 AP from the active unit.

### Green Phase (Implementation)
1. Add `has_line_of_sight` and `get_attackable_tiles` to `scripts/battle/grid.gd`.
2. Update `scripts/battle/battle_controller.gd` to read `min_range` and `max_range` from the attacker's weapon data.
3. Update `try_attack_selected_unit` to validate target range and LoS before resolving damage.

---

## Verification & Milestone

- **Automated Tests**: All unit tests in `tests/unit/test_ranged_combat_los.gd` and existing `tests/unit/test_battle_controller.gd` pass.
- **Verification Command**:
  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ranged_combat_los.gd
  make check
  ```
- **Local Merge**: Commit changes, merge branch back to `main` after user signoff.
