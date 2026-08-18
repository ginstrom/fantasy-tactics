# Step 1: Unit Facing Model, Orientation Updates, and Board Visuals

**Date:** 2026-08-18
**Status:** proposed
**Branch:** `feat/combat-unit-facing`
**Part of:** [`docs/plans/2026-08-18-critical-hits-and-flanking/index.md`](index.md)

## Summary

Implement the foundational **Unit Facing** system. Every unit on the tactical battlefield has a cardinal facing (`LEFT`, `RIGHT`, `UP`, `DOWN`). Moving updates a unit's facing along its direction of travel. Attacking causes the attacker to face its target. The battlefield renderer displays visual directional indicators on each unit so facing is immediately obvious to players and testers. The unit inspection panel reflects unit orientation.

---

## Technical Design

### 1. Facing Model on `Unit` (`scripts/battle/unit.gd`)
- Add property `var facing: Vector2i = Vector2i.RIGHT`.
- Valid facings are the 4 cardinal unit vectors: `Vector2i.RIGHT` (`(1, 0)`), `Vector2i.LEFT` (`(-1, 0)`), `Vector2i.UP` (`(0, -1)`), `Vector2i.DOWN` (`(0, 1)`).
- Provide a helper `func set_facing(direction: Vector2i) -> void` that normalizes non-zero vectors to the primary cardinal direction.

### 2. Initial Battle Setup (`scripts/battle/battle_controller.gd`)
- Player units initialize facing `Vector2i.RIGHT` (facing eastward toward enemy spawn points).
- Enemy units initialize facing `Vector2i.LEFT` (facing westward toward player spawn points).

### 3. Facing Updates on Movement
- `try_step_selected_unit(direction: Vector2i)`: Sets `selected_unit.facing = direction`.
- `try_move_selected_unit(target: Vector2i)`: When a multi-tile move occurs, sets facing to the direction of the final step taken along the path to `target`.
- Move-and-attack path in `try_attack_selected_unit()`: Updates unit facing to the direction moved to reach the attack tile before striking.

### 4. Facing Updates on Attack
- When executing an attack in `try_attack_selected_unit(target_pos)`: The attacker turns to face the defender.
- If the attack is diagonal or at range (e.g. Scout bow attack), calculate `delta = target_pos - attacker.grid_position`:
  - If `abs(delta.x) >= abs(delta.y)`: Primary facing is `Vector2i(sign(delta.x), 0)`.
  - Else: Primary facing is `Vector2i(0, sign(delta.y))`.

### 5. Board Rendering & Visual Indicator (`scripts/battle/battle_controller.gd`)
- In `_draw_units()`: On top of each unit's solid color square, render a distinct directional indicator (such as an arrow, notch, or triangular pointer) pointing in the direction of `unit.facing`.
- The indicator uses high-contrast coloring (e.g. `Color(1, 1, 1, 0.85)` or a dark outline) so it is clearly discernible across all player and enemy unit colors.

### 6. Unit Info Panel (`scripts/battle/unit_info_panel.gd`)
- Show unit facing in the selected/hovered unit inspection panel (e.g., `Facing: East`, `Facing: North`, `Facing: West`, `Facing: South`).
- Add localized strings in `translations/en.tres` (`battle.facing.east`, `battle.facing.west`, `battle.facing.north`, `battle.facing.south`).

---

## Setup

```bash
git checkout main && git pull
git checkout -b feat/combat-unit-facing
make check   # confirm clean baseline before changes
```

---

## TDD Task List (Red → Green)

Write failing tests first in each test file, verify failure, implement, and run `make check`.

1. **Unit Facing Model ([`tests/unit/test_battle_controller.gd`](../../../tests/unit/test_battle_controller.gd) & [`scripts/battle/unit.gd`](../../../scripts/battle/unit.gd)):**
   - Test default `Unit.facing` is `Vector2i.RIGHT`.
   - Test `Unit.set_facing()` sets cardinal directions and resolves diagonals/vectors to primary cardinal direction.

2. **BattleController Initial Facings ([`tests/unit/test_battle_controller.gd`](../../../tests/unit/test_battle_controller.gd) & [`scripts/battle/battle_controller.gd`](../../../scripts/battle/battle_controller.gd)):**
   - In `_ready()`, assert all spawned player units have `facing == Vector2i.RIGHT`.
   - Assert all spawned enemy units have `facing == Vector2i.LEFT`.

3. **Movement Updates Facing ([`tests/unit/test_battle_controller.gd`](../../../tests/unit/test_battle_controller.gd) & [`scripts/battle/battle_controller.gd`](../../../scripts/battle/battle_controller.gd)):**
   - Test `try_step_selected_unit(Vector2i.DOWN)` sets `selected_unit.facing` to `Vector2i.DOWN`.
   - Test `try_step_selected_unit(Vector2i.UP)` sets `selected_unit.facing` to `Vector2i.UP`.
   - Test `try_move_selected_unit(target)` updates `selected_unit.facing` to the direction of the final tile stepped onto.

4. **Attack Updates Attacker Facing ([`tests/unit/test_battle_controller.gd`](../../../tests/unit/test_battle_controller.gd) & [`scripts/battle/battle_controller.gd`](../../../scripts/battle/battle_controller.gd)):**
   - Attacker at `(1, 1)` attacking defender at `(1, 2)` (below) turns to `Vector2i.DOWN`.
   - Attacker at `(2, 2)` attacking defender at `(1, 2)` (left) turns to `Vector2i.LEFT`.
   - Attacker at `(1, 1)` with bow attacking defender at `(4, 2)` (mostly right) turns to `Vector2i.RIGHT`.

5. **Visual Facing Indicator ([`tests/unit/test_battle_controller.gd`](../../../tests/unit/test_battle_controller.gd) & [`scripts/battle/battle_controller.gd`](../../../scripts/battle/battle_controller.gd)):**
   - In `_draw_units()`, assert unit nodes have child facing visual indicators attached and positioned according to `unit.facing`.

6. **Unit Inspection Panel ([`tests/unit/test_unit_info_panel.gd`](../../../tests/unit/test_unit_info_panel.gd) & [`scripts/battle/unit_info_panel.gd`](../../../scripts/battle/unit_info_panel.gd)):**
   - Assert `unit_info_panel` renders the unit's facing direction.
   - Add translation keys `battle.facing.*` to `translations/en.tres` and add assertion in [`tests/unit/test_localization.gd`](../../../tests/unit/test_localization.gd).

7. **Enemy AI & BattleBot Facing Consistency ([`tests/unit/test_battle_controller.gd`](../../../tests/unit/test_battle_controller.gd) & [`tests/unit/test_battle_bot.gd`](../../../tests/unit/test_battle_bot.gd)):**
   - Verify enemy units update facing when taking move and attack steps in `run_enemy_turn()`.
   - Verify BattleBot units update facing when taking move and attack steps in `take_player_turn()`.

---

## Verification

Run the full validation suite:

```bash
make check
```

Expected output: All unit tests pass with zero errors, zero orphans, and zero warnings.

---

## Manual Verification (User Sign-off)

1. Run `make play`.
2. Press **FN+F9** to open the Debug Scenario Menu, select **Goblin Camp Battle**.
3. **Inspect Initial Facings:**
   - Confirm player units have visible facing pointers aimed **Right** (East).
   - Confirm enemy units have visible facing pointers aimed **Left** (West).
4. **Move Actions:**
   - Select a player unit. Move 1 tile **Down** (using `S` key or click). Confirm the unit's facing pointer immediately points **Down** (South).
   - Move 1 tile **Up** (using `W` key or click). Confirm facing pointer rotates to **Up** (North).
5. **Attack Actions:**
   - Move adjacent to a goblin and attack it. Confirm the attacking unit rotates to face directly toward the attacked goblin.
6. **Unit Info Panel:**
   - Click a unit to inspect it. Confirm the info panel on the right displays the correct facing direction (`Facing: South`, etc.).
7. **Enemy Turn:**
   - Press **End Turn**. Observe enemy goblins move toward player units. Confirm goblins update their facing pointers in the direction of their movement and attacks.

---

## Commit and Merge

```bash
git add -A && git status
git commit -m "feat(combat): implement unit facing model, movement/attack orientation, and board visuals"

# After user sign-off:
git checkout main
git merge feat/combat-unit-facing
git branch -d feat/combat-unit-facing
```

---

## Milestone (Concretely Verifiable)

- `unit.facing` property exists, defaults correctly, and is maintained across all movement, attacks, and AI turns.
- Visual facing indicator is rendered on every living unit on the battlefield grid.
- `make check` passes 100% green.
- Manual inspection in `make play` confirms facing indicators update dynamically during combat.
