# Task 4: Full-party fielding and enemy count

## Objective

Field one `Unit` per party member and one per encounter enemy count,
instead of always exactly one warrior versus one enemy (design.md §2
"Fielding", "Starting positions", "Enemy count data"). This is the task
that touches the most existing tests: every test that instantiates
`BattlefieldScene` and reads a unit at a hardcoded `Vector2i(1, 1)` /
`Vector2i(4, 4)` needs its position updated, and the two tests that assumed
exactly one enemy need rewriting to assert the documented count instead.

## Files

- Modify: `scripts/autoload/game_session.gd`, `tests/unit/test_game_session.gd`
- Modify: `scripts/battle/battle_controller.gd`,
  `tests/unit/test_battle_controller.gd`
- Modify: `tests/unit/test_battlefield.gd`
- Modify: `tests/unit/test_debug_scenarios.gd` (only if it references
  `WARRIOR_START`/`GOBLIN_START` — grep first; as of this plan it does not)

## Steps

### Enemy count data

1. Add failing tests to `test_game_session.gd`:
   `test_get_expedition_includes_the_enemy_count_for_the_goblin_camp` (
   `record.enemy.count == 2`) and
   `test_get_expedition_includes_the_enemy_count_for_the_orc_outpost` (
   `record.enemy.count == 3`).
2. Implement: in `game_session.gd`'s `EXPEDITIONS`, add `"count": 2,` to
   `goblin_camp.enemy` and `"count": 3,` to `orc_outpost.enemy`. Rerun
   `test_game_session` green.

### Fielding

3. Add a failing test to `test_battle_controller.gd`:
   `test_ready_spawns_one_unit_per_party_member_in_party_order` — create a
   party, assign the seeded Warrior, `GameSession.recruit_adventurer()` and
   assign the recruit too, instantiate `BattlefieldScene`, and assert
   exactly 2 `Side.PLAYER` units exist, the first at
   `BattleControllerScript.PLAYER_START_POSITIONS[0]` with
   `adventurer_id == GameSession.WARRIOR_ID`, the second at
   `PLAYER_START_POSITIONS[1]` with the recruit's id.
4. Replace `test_ready_spawns_the_documented_warrior_and_goblin` with
   `test_ready_spawns_the_full_party_and_the_encounters_full_enemy_count`:
   with no party selected (the existing single-Warrior fallback), the
   default (fallback-to-Goblin-Camp) battlefield spawns `3` total units —
   one Warrior at `PLAYER_START_POSITIONS[0]` with the documented warrior
   stats, and two goblins at `ENEMY_START_POSITIONS[0]`/`[1]` each with the
   documented goblin stats (`max_health 3`, `attack_damage 1`,
   `hit_chance 0.3`, `attack_name == tr("battle.enemy.goblin.attack")`).
5. Replace `test_ready_builds_the_orc_outpost_enemy_when_orc_outpost_is_selected`
   with `test_ready_builds_three_orcs_when_the_orc_outpost_is_selected`:
   `GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)`, then assert
   exactly 3 `Side.ENEMY` units exist, each with orc stats
   (`max_health 5`, `attack_damage 2`, `hit_chance 0.5`,
   `attack_name == tr("battle.enemy.orc.attack")`), one at each of
   `ENEMY_START_POSITIONS[0..2]`.
6. Replace `test_ready_builds_the_goblin_camp_enemy_when_goblin_camp_is_selected`
   with the explicit-selection counterpart of step 4's fallback case:
   `test_ready_builds_two_goblins_when_the_goblin_camp_is_selected` — same
   assertions as step 4's enemy half, but after an explicit
   `GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)`.
7. In the four remaining single-player-stat tests
   (`test_ready_builds_the_player_unit_from_the_first_partys_effective_stats`,
   `test_ready_builds_the_player_unit_with_a_ninety_five_percent_hit_chance_when_raw_attack_reaches_one_hundred`,
   `test_ready_builds_the_player_unit_with_one_extra_move_tile_after_choosing_bonus_move`,
   `test_ready_falls_back_to_the_default_warrior_when_no_party_is_selected`),
   replace every `controller.get_unit_at(Vector2i(1, 1))` /
   `battlefield.grid.get_unit_at(Vector2i(1, 1))` with
   `...get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])`.
8. Run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller
   -gexit`. Expected: fails — `PLAYER_START_POSITIONS`/`ENEMY_START_POSITIONS`
   don't exist yet, and fielding is still single-unit.
9. Implement in `battle_controller.gd`:
   - Replace `WARRIOR_START`/`WARRIOR_COLOR`/`GOBLIN_START`/`GOBLIN_COLOR`
     with:

     ```gdscript
     const PLAYER_START_POSITIONS: Array[Vector2i] = [
         Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 0),
     ]
     const PLAYER_COLORS: Array[Color] = [
         Color(0.3, 0.5, 0.9), Color(0.3, 0.8, 0.5), Color(0.85, 0.8, 0.3),
         Color(0.7, 0.4, 0.85), Color(0.9, 0.6, 0.3),
     ]
     const ENEMY_START_POSITIONS: Array[Vector2i] = [
         Vector2i(5, 5), Vector2i(4, 5), Vector2i(5, 4),
     ]
     const ENEMY_COLOR := Color(0.9, 0.4, 0.3)
     ```

     (positions and counts are exactly design.md §2's documented clusters;
     colors are new — pick any 5 visually distinct colors if adjusting).
   - Add `var _player_adventurer_ids: Array[String] = []` next to `units`.
   - Replace `_get_player_adventurer_id() -> String` with
     `_get_player_adventurer_ids() -> Array[String]`: returns
     `GameSession.get_selected_party().member_ids` when that party is
     non-empty, else `[GameSession.WARRIOR_ID]` (same single-Warrior
     fallback as today, just wrapped in an array).
   - Rewrite `_ready()`'s unit construction:

     ```gdscript
     func _ready() -> void:
         add_to_group(GROUP)
         grid = GridScript.new(GRID_WIDTH, GRID_HEIGHT)
         var enemy_stats := _get_enemy_stats()
         _player_adventurer_ids = _get_player_adventurer_ids()
         units = []
         for index in mini(_player_adventurer_ids.size(), PLAYER_START_POSITIONS.size()):
             var adventurer_id: String = _player_adventurer_ids[index]
             units.append(UnitScript.new(
                 PLAYER_START_POSITIONS[index], PLAYER_COLORS[index % PLAYER_COLORS.size()], Side.PLAYER,
                 GameSession.get_effective_move_range(adventurer_id),
                 GameSession.get_effective_max_health(adventurer_id),
                 WARRIOR_ATTACK_DAMAGE,
                 GameSession.get_effective_hit_chance(adventurer_id),
                 WARRIOR_ATTACK_NAME,
                 adventurer_id
             ))
         var enemy_count: int = enemy_stats.get("count", 1)
         for index in mini(enemy_count, ENEMY_START_POSITIONS.size()):
             units.append(UnitScript.new(
                 ENEMY_START_POSITIONS[index], ENEMY_COLOR, Side.ENEMY, UNIT_MOVE_RANGE,
                 enemy_stats.max_health, enemy_stats.attack_damage, enemy_stats.hit_chance,
                 tr(enemy_stats.attack_name_key)
             ))
         _draw_tiles()
         _draw_units()
         _update_highlights()
     ```

   - `_get_enemy_stats()` is unchanged (still returns the whole `enemy`
     dict, now including `count`).
10. Rerun `test_battle_controller` green, then run the full suite
    (`make check`) to find any other now-broken references to
    `WARRIOR_START`/`GOBLIN_START`/`Vector2i(1, 1)`/`Vector2i(4, 4)` outside
    this file — `test_battlefield.gd` will fail here (its portrait/HUD tests
    are out of scope until Tasks 5-6, but any test there referencing the old
    fixed positions needs the same `PLAYER_START_POSITIONS[0]`/
    `ENEMY_START_POSITIONS[0]` substitution now so the suite stays green at
    the end of this task):
    - Add `const BattleControllerScript :=
      preload("res://scripts/battle/battle_controller.gd")` to
      `test_battlefield.gd`.
    - In `test_describe_step_reports_a_hit_with_damage`,
      `test_describe_step_reports_a_miss`, `test_describe_step_reports_an_enemy_move`,
      replace `battlefield.grid.get_unit_at(Vector2i(4, 4))` with
      `...get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])`.
    - In `_stage_a_killing_blow()`, replace
      `battlefield.grid.get_unit_at(Vector2i(1, 1))` and
      `...get_unit_at(Vector2i(4, 4))` with the `PLAYER_START_POSITIONS[0]`/
      `ENEMY_START_POSITIONS[0]` equivalents.
    - `test_ready_shows_full_health_for_both_units` and
      `test_health_label_shows_defeated_after_a_unit_dies` will still fail
      after this substitution (they assert against the single `player_health`/
      `enemy_health` labels this task doesn't touch) — leave them red; Task 6
      rewrites them.
11. Commit:

    ```bash
    git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd \
      scripts/battle/battle_controller.gd tests/unit/test_battle_controller.gd \
      tests/unit/test_battlefield.gd
    git commit -m "feat: field the full party and every encounter's full enemy count"
    ```

## Milestone

A 2-member party now spawns two player Units in party order; the Goblin
Camp spawns two goblins and the Orc Outpost spawns three orcs — provable via
`test_battle_controller.gd` alone. `test_battlefield.gd`'s two HUD-label
tests are a known, intentionally-deferred red until Task 6.
