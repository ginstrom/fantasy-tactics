# Task 06: Loot-table data and injectable roll callables on `GameSession`

## Objective

Add the loot content table — enemy loot id → gold range/multiplier/mana
tier/gear drop — and the two injectable roll callables Task 07 uses to make
loot rolls deterministic in tests.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Test: `tests/unit/test_game_session.gd`

## Depends on

Task 01 (`GameSession.WEAPONS`, for the gear-drop item ids).

## Produces

`GameSession.ENEMY_LOOT_TABLES: Dictionary` (loot id `String` →
`{gold_min: int, gold_max: int, gold_multiplier: int, mana_crystal_tier:
int, gear_item_id: String}`), `GameSession.MANA_CRYSTAL_VALUES: Dictionary`
(`{1: 5, 2: 15}`), `GameSession.GEAR_DROP_CHANCE: float = 0.25`,
`GameSession.loot_gold_roll: Callable` (`func(min_value: int, max_value:
int) -> int`, default `randi_range`), `GameSession.loot_gear_roll: Callable`
(`func() -> float`, default `randf`). Also adds a `"loot_id": String` key to
the existing `GOBLIN_ENEMY_STATS`/`ORC_ENEMY_STATS` consts so `_roll_and_
queue_loot` (Task 07) can look up the right loot-table row from a resolved
encounter's `enemy` dict.

## Steps

1. **Write the failing tests.** Add to `tests/unit/test_game_session.gd`:

   ```gdscript
   func test_enemy_loot_tables_match_the_documented_gold_mana_crystal_tier_and_gear() -> void:
   	assert_eq(GameSessionScript.ENEMY_LOOT_TABLES.kobold, {"gold_min": 0, "gold_max": 5, "gold_multiplier": 1, "mana_crystal_tier": 1, "gear_item_id": "dagger_iron"})
   	assert_eq(GameSessionScript.ENEMY_LOOT_TABLES.goblin, {"gold_min": 1, "gold_max": 6, "gold_multiplier": 1, "mana_crystal_tier": 1, "gear_item_id": "shortsword_iron"})
   	assert_eq(GameSessionScript.ENEMY_LOOT_TABLES.orc, {"gold_min": 1, "gold_max": 5, "gold_multiplier": 2, "mana_crystal_tier": 2, "gear_item_id": "longsword_iron"})
   	assert_eq(GameSessionScript.ENEMY_LOOT_TABLES.hobgoblin, {"gold_min": 1, "gold_max": 4, "gold_multiplier": 3, "mana_crystal_tier": 2, "gear_item_id": "two_handed_sword_iron"})


   func test_mana_crystal_values_match_the_documented_tiers() -> void:
   	assert_eq(GameSessionScript.MANA_CRYSTAL_VALUES, {1: 5, 2: 15})


   func test_goblin_and_orc_enemy_stats_carry_their_loot_id() -> void:
   	assert_eq(GameSessionScript.GOBLIN_ENEMY_STATS.loot_id, "goblin")
   	assert_eq(GameSessionScript.ORC_ENEMY_STATS.loot_id, "orc")
   ```

2. **Run the tests to verify they fail.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gunit_test_name=enemy_loot_tables -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gunit_test_name=mana_crystal_values -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gunit_test_name=goblin_and_orc_enemy_stats -gexit
   ```

   Expected: FAIL — `Invalid access to property or key 'ENEMY_LOOT_TABLES'`
   (etc.).

3. **Implement.** In `scripts/autoload/game_session.gd`, add
   `"loot_id": "goblin",` as a new key inside `GOBLIN_ENEMY_STATS` (alongside
   `name_key`/`attack_name_key`/etc., currently lines 47-53) and
   `"loot_id": "orc",` inside `ORC_ENEMY_STATS` (currently lines 54-60).

   Add this block immediately after Task 01's `WEAPONS`/`ARMORS` block:

   ```gdscript
   # Loot tables (docs/plans/trading-system.md "Loot"). Gold per kill is
   # randi_range(gold_min, gold_max) * gold_multiplier. gear_item_id is always
   # the enemy's documented Iron-tier weapon (see WEAPONS above); it drops with
   # GEAR_DROP_CHANCE probability, independent of the (always-granted) mana
   # crystal. Kobold and hobgoblin are documented here to match the design doc
   # exactly, but neither currently appears in any active encounter (see
   # STAR_ENEMY_COMPOSITIONS) — their rows are unreachable until a future
   # content plan adds them as fightable enemies.
   const ENEMY_LOOT_TABLES: Dictionary = {
   	"kobold": {"gold_min": 0, "gold_max": 5, "gold_multiplier": 1, "mana_crystal_tier": 1, "gear_item_id": "dagger_iron"},
   	"goblin": {"gold_min": 1, "gold_max": 6, "gold_multiplier": 1, "mana_crystal_tier": 1, "gear_item_id": "shortsword_iron"},
   	"orc": {"gold_min": 1, "gold_max": 5, "gold_multiplier": 2, "mana_crystal_tier": 2, "gear_item_id": "longsword_iron"},
   	"hobgoblin": {"gold_min": 1, "gold_max": 4, "gold_multiplier": 3, "mana_crystal_tier": 2, "gear_item_id": "two_handed_sword_iron"},
   }
   const MANA_CRYSTAL_VALUES: Dictionary = {1: 5, 2: 15}
   const GEAR_DROP_CHANCE := 0.25
   ```

   Add these two vars next to `var enemy_composition_roll: Callable = ...`
   (currently around line 208):

   ```gdscript
   # Injectable so tests can force deterministic loot instead of depending on
   # real randomness (see enemy_composition_roll/hit_roll for the same
   # pattern). Never reset by reset() — a test sets these immediately before
   # its own complete_current_encounter() call, same as enemy_composition_roll.
   var loot_gold_roll: Callable = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
   var loot_gear_roll: Callable = func() -> float: return randf()
   ```

4. **Run the tests to verify they pass.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit
   ```

   Expected: PASS.

5. **Commit** only this task's files:

   ```bash
   git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd
   git commit -m "feat: add enemy loot tables and injectable loot roll callables"
   ```

## Milestone

`GameSession.ENEMY_LOOT_TABLES` holds all four design-doc rows with exact
gold/mana/gear values, `GOBLIN_ENEMY_STATS`/`ORC_ENEMY_STATS` each carry the
`loot_id` that will let Task 07 find their row, and `loot_gold_roll`/
`loot_gear_roll` exist as injection points before anything calls them yet.
