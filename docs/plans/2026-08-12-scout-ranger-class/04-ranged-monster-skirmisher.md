# Step 4: Ranged Monster Skirmisher & AI Ranged Attack Loop

> **Branch:** `feat/scout-ranger-class` (or step-specific branch off `main`)

## Goal
Add the `goblin_archer` ranged enemy template to [`GameSession`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/game_session.gd), update AI tactical decisions in [`BattleController`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battle_controller.gd) for ranged combatants, and update encounter compositions.

---

## Technical Design

1. **Ranged Enemy Template (`scripts/autoload/game_session.gd`)**:
   Add `goblin_archer` to monster data tables:
   ```gdscript
   "goblin_archer": {
       "id": "goblin_archer",
       "name": "tr:monster.goblin_archer",
       "tier": 2,
       "max_health": 10,
       "might": 0,
       "accuracy": 40,
       "guard": 0,
       "resistance": 0,
       "mobility": 3,
       "min_range": 1,
       "max_range": 3,
       "attack_damage_min": 1,
       "attack_damage_max": 4,
       "kill_xp": 6,
       "role": "ranged_skirmisher"
   }
   ```

2. **Encounter Compositions (`STAR_ENEMY_COMPOSITIONS`)**:
   Include `goblin_archer` in multi-enemy compositions (e.g., 2-star encounter: 1 Goblin + 1 Goblin Archer; 3-star encounter: 1 Orc + 1 Goblin Archer).

3. **AI Ranged Decision Loop (`scripts/battle/battle_controller.gd`)**:
   Extend `_take_enemy_unit_actions()`:
   - Check if enemy unit has `max_range > 1`.
   - If player target is within `[min_range, max_range]` and has Line of Sight, attack directly (3 AP).
   - If out of range or blocked, path toward a tile that grants range + LoS to the nearest player unit before attacking.

---

## TDD Milestones

### Red Phase (Failing Tests First)
Create `tests/unit/test_ranged_enemy_ai.gd`:
- `test_goblin_archer_template_loaded()`: `goblin_archer` monster template exists with `max_range=3`.
- `test_ai_ranged_unit_attacks_stationary_target_at_range()`: AI Goblin Archer 3 tiles away from player unit attacks without closing into melee range.
- `test_ai_ranged_unit_repositions_around_obstacle_for_los()`: AI Goblin Archer moves to clear LoS around an obstacle tile before firing.
- `test_battle_bot_handles_ranged_enemies()`: `BattleBot` and `battle_sim.gd` successfully navigate and win/lose battles featuring `goblin_archer`.

### Green Phase (Implementation)
1. Add `goblin_archer` definition and update `STAR_ENEMY_COMPOSITIONS` in `scripts/autoload/game_session.gd`.
2. Update AI unit turn logic in `scripts/battle/battle_controller.gd` to handle `max_range > 1`.
3. Update `scripts/tools/battle_bot.gd` if necessary to ensure automated battle simulation handles ranged enemies cleanly.

---

## Verification & Milestone

- **Automated Tests**: All unit tests in `test_ranged_enemy_ai.gd` pass.
- **Headless Simulation**: Run `make simulate` to ensure `BattleBot` completes 50 headless battles against mixed melee/ranged encounters without hanging or crashing.
- **Verification Command**:
  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ranged_enemy_ai.gd
  make simulate
  ```
- **Local Merge**: Commit changes, merge branch back to `main` after user signoff.
