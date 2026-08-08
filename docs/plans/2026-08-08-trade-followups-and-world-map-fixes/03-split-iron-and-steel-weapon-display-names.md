# Task 03: Split Iron and Steel weapon display names

## Objective

Every weapon in `GameSession.WEAPONS` currently shares one `name_key`
between its Iron and Steel tier (e.g. `dagger_iron` and `dagger_steel`
both use `"item.dagger"`). This was harmless in Phase A of the trade plan
(one warrior, one weapon, the name only fed a battle-side field nothing
displayed), but Phase C's Trading Post and Stores screens list the whole
catalog — all 8 weapons currently render as four visually-identical pairs,
distinguishable only by price. Give each of the 8 weapon entries its own
`name_key` and translation.

## Files

- Modify: `scripts/autoload/game_session.gd`, `translations/en.tres`
- Test: `tests/unit/test_game_session.gd`, `tests/unit/test_stores.gd`

## Depends on

None.

## Produces

`GameSession.WEAPONS`'s 8 entries each get a unique `name_key`
(`item.dagger_iron`, `item.dagger_steel`, `item.shortsword_iron`,
`item.shortsword_steel`, `item.longsword_iron`, `item.longsword_steel`,
`item.two_handed_sword_iron`, `item.two_handed_sword_steel`), each with its
own translation.

## Steps

1. **Update the failing tests first.** In `tests/unit/test_game_session.gd`,
   find `test_weapons_catalog_has_the_documented_iron_and_steel_damage_and_price`
   (around line 2133) and change each `name_key` to match the entry's own
   id:

   ```gdscript
   func test_weapons_catalog_has_the_documented_iron_and_steel_damage_and_price() -> void:
   	assert_eq(GameSessionScript.WEAPONS.dagger_iron, {"name_key": "item.dagger_iron", "slot": "weapon", "damage_min": 1, "damage_max": 4, "price": 10})
   	assert_eq(GameSessionScript.WEAPONS.dagger_steel, {"name_key": "item.dagger_steel", "slot": "weapon", "damage_min": 2, "damage_max": 5, "price": 30})
   	assert_eq(GameSessionScript.WEAPONS.shortsword_iron, {"name_key": "item.shortsword_iron", "slot": "weapon", "damage_min": 1, "damage_max": 6, "price": 20})
   	assert_eq(GameSessionScript.WEAPONS.shortsword_steel, {"name_key": "item.shortsword_steel", "slot": "weapon", "damage_min": 2, "damage_max": 7, "price": 60})
   	assert_eq(GameSessionScript.WEAPONS.longsword_iron, {"name_key": "item.longsword_iron", "slot": "weapon", "damage_min": 1, "damage_max": 8, "price": 30})
   	assert_eq(GameSessionScript.WEAPONS.longsword_steel, {"name_key": "item.longsword_steel", "slot": "weapon", "damage_min": 2, "damage_max": 9, "price": 90})
   	assert_eq(GameSessionScript.WEAPONS.two_handed_sword_iron, {"name_key": "item.two_handed_sword_iron", "slot": "weapon", "damage_min": 1, "damage_max": 10, "price": 35})
   	assert_eq(GameSessionScript.WEAPONS.two_handed_sword_steel, {"name_key": "item.two_handed_sword_steel", "slot": "weapon", "damage_min": 2, "damage_max": 11, "price": 105})
   ```

   And `test_effective_weapon_damage_range_and_name_come_from_the_equipped_weapon`
   (around line 2167), which reads the Warrior's default Iron Longsword's
   name — update the expected string:

   ```gdscript
   func test_effective_weapon_damage_range_and_name_come_from_the_equipped_weapon() -> void:
   	assert_eq(GameSession.get_effective_weapon_damage_range(GameSession.WARRIOR_ID), Vector2i(1, 8))
   	assert_eq(GameSession.get_effective_weapon_name(GameSession.WARRIOR_ID), "Iron Longsword")
   ```

   In `tests/unit/test_stores.gd`, `test_table_shows_a_gear_row_and_a_mana_crystal_row`
   (around line 49) and `test_selecting_a_gear_row_shows_its_detail_and_both_actions`
   (around line 67) assert the literal rendered name `"Shortsword"` for a
   banked `shortsword_iron` — update both to `"Iron Shortsword"`:

   ```gdscript
   	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Iron Shortsword", "Mana Crystal (Tier 1)"])
   ```

   ```gdscript
   		tr("stores.selected") % ["Iron Shortsword", 3, 10]
   ```

2. **Run the tests to verify they fail.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gunit_test_name=weapons_catalog -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_stores.gd -gexit
   ```

   Expected: FAIL — the catalog test fails on the still-shared `name_key`
   values, and the Stores tests fail because `tr("item.shortsword")` still
   resolves to `"Shortsword"`, not `"Iron Shortsword"`.

3. **Update `GameSession.WEAPONS`.** In `scripts/autoload/game_session.gd`,
   replace the `WEAPONS` const (currently lines 85-94):

   ```gdscript
   const WEAPONS: Dictionary = {
   	"dagger_iron": {"name_key": "item.dagger", "slot": "weapon", "damage_min": 1, "damage_max": 4, "price": 10},
   	"dagger_steel": {"name_key": "item.dagger", "slot": "weapon", "damage_min": 2, "damage_max": 5, "price": 30},
   	"shortsword_iron": {"name_key": "item.shortsword", "slot": "weapon", "damage_min": 1, "damage_max": 6, "price": 20},
   	"shortsword_steel": {"name_key": "item.shortsword", "slot": "weapon", "damage_min": 2, "damage_max": 7, "price": 60},
   	"longsword_iron": {"name_key": "item.longsword", "slot": "weapon", "damage_min": 1, "damage_max": 8, "price": 30},
   	"longsword_steel": {"name_key": "item.longsword", "slot": "weapon", "damage_min": 2, "damage_max": 9, "price": 90},
   	"two_handed_sword_iron": {"name_key": "item.two_handed_sword", "slot": "weapon", "damage_min": 1, "damage_max": 10, "price": 35},
   	"two_handed_sword_steel": {"name_key": "item.two_handed_sword", "slot": "weapon", "damage_min": 2, "damage_max": 11, "price": 105},
   }
   ```

   with:

   ```gdscript
   const WEAPONS: Dictionary = {
   	"dagger_iron": {"name_key": "item.dagger_iron", "slot": "weapon", "damage_min": 1, "damage_max": 4, "price": 10},
   	"dagger_steel": {"name_key": "item.dagger_steel", "slot": "weapon", "damage_min": 2, "damage_max": 5, "price": 30},
   	"shortsword_iron": {"name_key": "item.shortsword_iron", "slot": "weapon", "damage_min": 1, "damage_max": 6, "price": 20},
   	"shortsword_steel": {"name_key": "item.shortsword_steel", "slot": "weapon", "damage_min": 2, "damage_max": 7, "price": 60},
   	"longsword_iron": {"name_key": "item.longsword_iron", "slot": "weapon", "damage_min": 1, "damage_max": 8, "price": 30},
   	"longsword_steel": {"name_key": "item.longsword_steel", "slot": "weapon", "damage_min": 2, "damage_max": 9, "price": 90},
   	"two_handed_sword_iron": {"name_key": "item.two_handed_sword_iron", "slot": "weapon", "damage_min": 1, "damage_max": 10, "price": 35},
   	"two_handed_sword_steel": {"name_key": "item.two_handed_sword_steel", "slot": "weapon", "damage_min": 2, "damage_max": 11, "price": 105},
   }
   ```

4. **Update `translations/en.tres`.** Replace the four shared weapon keys
   (currently lines 34-37):

   ```
   "item.dagger": "Dagger",
   "item.shortsword": "Shortsword",
   "item.longsword": "Longsword",
   "item.two_handed_sword": "Two-Handed Sword",
   ```

   with eight tier-specific keys:

   ```
   "item.dagger_iron": "Iron Dagger",
   "item.dagger_steel": "Steel Dagger",
   "item.shortsword_iron": "Iron Shortsword",
   "item.shortsword_steel": "Steel Shortsword",
   "item.longsword_iron": "Iron Longsword",
   "item.longsword_steel": "Steel Longsword",
   "item.two_handed_sword_iron": "Iron Two-Handed Sword",
   "item.two_handed_sword_steel": "Steel Two-Handed Sword",
   ```

5. **Run the tests to verify they pass.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_stores.gd -gexit
   ```

   Expected: PASS.

6. **Run the full suite.**

   ```bash
   make test
   ```

   Expected: `---- All tests passed! ----`, exit code 0. (No other file
   asserts the old shared weapon names — `tests/unit/test_unit.gd` and
   `tests/unit/test_battle_controller.gd` pass `"Longsword"`/`"Dagger"` as
   arbitrary `attack_name` constructor arguments to `Unit.new()` directly,
   unrelated to `GameSession.WEAPONS`, and are untouched by this task.)

7. **Commit** only this task's files:

   ```bash
   git add scripts/autoload/game_session.gd translations/en.tres tests/unit/test_game_session.gd tests/unit/test_stores.gd
   git commit -m "fix: give every weapon tier its own display name"
   ```

## Milestone

Trading Post and Stores each render all 8 weapons as 8 distinguishable
names (e.g. "Iron Dagger" vs. "Steel Dagger"), not four indistinguishable
pairs; `make test` is green.
