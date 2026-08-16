# Step 3: Tactical Combat & Custom Battlefield Setup

## Overview

Currently, [`scripts/battle/battle_controller.gd`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battle_controller.gd) constructs battle encounters exclusively by looking up standard templates via `GameSession.get_expedition(GameSession.selected_encounter)` and spawning fixed counts of generic enemies at predefined enemy start positions.

This step extends `GameSession` and `BattleController` to support declarative battlefield scenarios specified in JSON:
- Pinned roll overrides (`enemy_composition_roll`, `enemy_count_roll`) for standard encounter templates.
- Explicit custom enemy squads with bespoke statistics (max health, damage ranges, hit chance, defense, resistance, movement range, attack min/max ranges), custom battle grid positions, and custom equipment (e.g. weapons, bows, armors, rune effects).
- Custom player spawn positions on the tactical battlefield grid.
- Proper cleanup: debug battle overrides are ephemeral and do not leak into subsequent battles or game sessions.

---

## Setup Instructions

1. Check out `main` and pull the latest changes:
   ```bash
   git checkout main && git pull
   ```
2. Create and check out the feature branch:
   ```bash
   git checkout -b feat/debug-battlefield-custom-enemies
   ```

---

## Test-Driven Development (TDD) Plan

### 1. Write Failing Tests (Red Phase)

Add unit tests in [`tests/unit/test_battle_controller.gd`](file:///home/ryan/play/fantasy-tactics/tests/unit/test_battle_controller.gd) and [`tests/unit/test_debug_scenarios.gd`](file:///home/ryan/play/fantasy-tactics/tests/unit/test_debug_scenarios.gd):

- **Test Pinned Rolls in Battle Scenarios**:
  - Apply `ruined_fortress` scenario and assert `BattleController` spawns exactly 8 Kobolds without composition randomness.
  - Apply `orc_outpost` scenario and assert `BattleController` spawns exactly 2 Orcs.
- **Test Custom Enemy Squad Specification**:
  - Define scenario with custom enemy list: 1 Hobgoblin at `(4, 4)` and 2 Goblin Archers at `(5, 3)` and `(5, 5)` equipped with `shortbow_iron` (range 1–3).
  - Apply scenario, instantiate `Battlefield`, and verify:
    - 3 enemy units are fielded at the exact specified grid coordinates.
    - Goblin Archers have `attack_max_range = 3`, `attack_min_range = 1`, and correct bow attack stats.
    - Hobgoblin has 30 HP and melee stats.
- **Test Custom Enemy Equipment and Runes**:
  - Define scenario with an enemy wearing Thorn-runed armor and holding a steel longsword.
  - Verify enemy unit receives the defense/resistance bonuses, rune ID, and weapon damage parameters.
- **Test Custom Player Start Positions**:
  - Define scenario with player units positioned at `(1, 1)` and `(2, 2)`.
  - Verify player units spawn at the specified coordinates instead of default row 0.
- **Test Isolation and No-Leak Guarantee**:
  - Verify that running a custom battle scenario followed by a standard battle cleans up all debug overrides without polluting subsequent encounters.

Run tests to confirm failure:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd,test_debug_scenarios.gd -gexit
```

---

### 2. Implementation (Green Phase)

1. **Update [`scripts/autoload/game_session.gd`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/game_session.gd)**:
   - Add field `var debug_battle_override: Dictionary = {}`.
   - In `GameSession.reset()`, ensure `debug_battle_override = {}` and `reset_injectable_rolls()` are called.
2. **Update [`scripts/debug/debug_scenarios.gd`](file:///home/ryan/play/fantasy-tactics/scripts/debug/debug_scenarios.gd)**:
   - Implement `static func _apply_battle_state(battle_config: Dictionary) -> void`:
     - If `battle_config` is empty, returns immediately.
     - If `battle_config.has("encounter_id")`:
       - Sets `GameSession.selected_encounter = battle_config.encounter_id`.
     - If `battle_config.has("pinned_rolls")`:
       - Sets `GameSession.enemy_composition_roll` and `GameSession.enemy_count_roll` to fixed return Callables matching the config.
     - If `battle_config.has("enemies")` or `battle_config.has("player_start_positions")`:
       - Stores `GameSession.debug_battle_override = battle_config.duplicate(true)`.
3. **Update [`scripts/battle/battle_controller.gd`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battle_controller.gd)**:
   - In `_ready()`:
     - Check if `GameSession.debug_battle_override` contains `player_start_positions`:
       - Use custom positions if present, otherwise default `PLAYER_START_POSITIONS`.
     - Check if `GameSession.debug_battle_override` contains `enemies`:
       - If present, instantiate `UnitScript` for each custom enemy in `GameSession.debug_battle_override.enemies`:
         - Set `grid_position`, `health`, `max_health`, `damage_min`, `damage_max`, `hit_chance`, `defense`, `resistance`, `move_range`, `attack_min_range`, `attack_max_range`, `display_name`, `enemy_type_name`, `rune_id`, `kill_xp`, `loot_id`.
       - If not present, fall back to standard `_get_enemy_stats()` spawning logic.
     - Consume/clear `GameSession.debug_battle_override` after instantiation to preserve encapsulation.

---

## Concrete Verifiable Milestone

Run the test suite:
```bash
make check
```
All GUT unit tests pass cleanly with 0 errors.

---

## Manual Verification

1. Add a test scenario `goblin_archers_skirmish` to `config/debug_scenarios.json` with 2 Goblin Archers and 1 Warrior.
2. Run `make play`.
3. Open debug menu (F9) -> select `goblin_archers_skirmish`.
4. Verify battlefield opens with Goblin Archers at specified tiles, displaying their bows and ranged attack capabilities.

---

## Local Branch Merge

After user sign-off:
```bash
git checkout main
git merge feat/debug-battlefield-custom-enemies
git branch -d feat/debug-battlefield-custom-enemies
```
