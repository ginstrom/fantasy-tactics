# Step 2: Visual Attack Range and Target Highlighting

## Overview

Currently, selecting a unit only displays movement range tiles (`LEGAL_MOVE_COLOR` in green). There is no visual representation of the unit's attack range, nor are attackable enemies highlighted on the battlefield grid.

This step updates `BattleController._update_highlights()` to compute and render:
1. **Attack Range Tiles**: Red-tinted overlay on all reachable attack tiles (within `[attack_min_range, attack_max_range]` with clear Line of Sight) when the selected unit has at least 3 AP.
2. **Targetable Enemy Highlights**: Prominent red target overlay on enemy units that are currently valid attack targets (`get_legal_attack_targets(selected_unit)`).

---

## Setup Instructions

1. Check out `main` and pull the latest changes:
   ```bash
   git checkout main && git pull
   ```
2. Create and check out the feature branch:
   ```bash
   git checkout -b feat/attack-range-highlighting
   ```

---

## Test-Driven Development (TDD) Plan

### 1. Write Failing Tests (Red Phase)

Add unit tests in [`tests/unit/test_battle_controller.gd`](file:///home/ryan/play/fantasy-tactics/tests/unit/test_battle_controller.gd):

- **Test `get_attackable_tiles_for_unit(unit)`**:
  - For a melee unit (range 1), returns only adjacent, in-bounds tiles with clear LoS.
  - For a ranged unit (Scout, range 1–3), returns all tiles within Manhattan distance 1–3 with clear LoS.
  - Excludes tiles blocked by intermediate living units.
- **Test highlight rendering when selected unit has >= 3 AP**:
  - Highlights container contains legal move highlights, attack range tile highlights, and target enemy highlights.
  - Verifies attack highlights use distinct color constants (`ATTACK_RANGE_COLOR`, `TARGET_ATTACK_COLOR`).
- **Test highlight rendering when selected unit has < 3 AP**:
  - When remaining AP is less than `BASIC_ATTACK_ACTION_POINT_COST`, attack range and target enemy highlights are not drawn (only legal move highlights are shown).
- **Test highlight rendering when selected unit is paralyzed**:
  - No movement or attack highlights are drawn.

Run tests to confirm failure:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gexit
```

### 2. Implementation (Green Phase)

1. **Update [`scripts/battle/battle_controller.gd`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battle_controller.gd)**:
   - Add highlight color constants:
     - `const ATTACK_RANGE_COLOR := Color(0.9, 0.25, 0.25, 0.35)`
     - `const TARGET_ATTACK_COLOR := Color(1.0, 0.2, 0.2, 0.65)`
   - Add helper method:
     ```gdscript
     func get_attackable_tiles_for_unit(unit) -> Array[Vector2i]:
         if unit == null or not unit.is_alive():
             return []
         var blocking_tiles: Array[Vector2i] = []
         for candidate in units:
             if candidate != unit and candidate.is_alive():
                 blocking_tiles.append(candidate.grid_position)
         return grid.get_attackable_tiles(unit.grid_position, unit.attack_min_range, unit.attack_max_range, blocking_tiles)
     ```
   - In `_update_highlights()`:
     - Clear existing highlight nodes in `highlight_container`.
     - Draw selection ring for `selected_unit`.
     - Draw legal move highlights (`LEGAL_MOVE_COLOR`) for `get_legal_moves(selected_unit)`.
     - If `selected_unit.action_points_remaining >= BASIC_ATTACK_ACTION_POINT_COST` and not `has_status(selected_unit, PARALYZED_STATUS_ID)`:
       - Draw attack range tiles (`ATTACK_RANGE_COLOR`) for `get_attackable_tiles_for_unit(selected_unit)` (skipping occupied player tiles or current tile).
       - Draw target highlights (`TARGET_ATTACK_COLOR`) for `get_legal_attack_targets(selected_unit)` with a distinct visual margin/border so enemies stand out clearly as attackable.

---

## Concrete Verifiable Milestone

Run the full test suite:
```bash
make check
```
All GUT unit tests pass cleanly with 0 errors.

---

## Manual Verification

1. Run the game:
   ```bash
   make play
   ```
2. Open debug menu (F9) -> select `goblin_camp`.
3. Select a unit with 6 AP:
   - Verify green squares appear for legal movement tiles.
   - Verify red-tinted squares appear for tiles in attack range (range 1 for Warrior, range 1–3 for Scout).
   - If an enemy is within attack range, verify the enemy's tile has a prominent red target indicator.
4. Move the unit until remaining AP < 3:
   - Verify attack range highlights disappear, leaving only remaining movement tiles.

---

## Local Branch Merge

After user sign-off:
```bash
git checkout main
git merge feat/attack-range-highlighting
git branch -d feat/attack-range-highlighting
```
