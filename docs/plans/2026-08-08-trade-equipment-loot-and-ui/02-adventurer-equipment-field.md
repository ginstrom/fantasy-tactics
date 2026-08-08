# Task 02: Adventurer `equipment` field and effective-equipment getters/setters

## Objective

Give every adventurer record a real `equipment` slot (replacing the unused
free-text `weapon` field) and the derived getters/setters the rest of this
plan reads and writes through — `BattleController` (Task 04) and the Trade
screens (Phase C) never touch `adventurer.equipment` directly.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Test: `tests/unit/test_game_session.gd`

## Depends on

Task 01 (`GameSession.WEAPONS`, `GameSession.ARMORS`, `get_item_definition()`).

## Produces

Adventurer records gain an `"equipment": {"weapon": String, "armor":
String}` field. `GameSession.get_effective_weapon_damage_range(adventurer_id:
String) -> Vector2i`, `GameSession.get_effective_weapon_name(adventurer_id:
String) -> String`, `GameSession.get_effective_defense(adventurer_id: String)
-> int`, `GameSession.get_effective_resistance(adventurer_id: String) ->
int`, `GameSession.set_adventurer_weapon(adventurer_id: String, weapon_id:
String) -> bool`, `GameSession.set_adventurer_armor(adventurer_id: String,
armor_id: String) -> bool`.

## Steps

1. **Write the failing tests.** Add to `tests/unit/test_game_session.gd`:

   ```gdscript
   func test_default_warrior_starts_with_an_iron_longsword_and_leather_armor() -> void:
   	var warrior: Dictionary = GameSession.get_default_warrior()

   	assert_eq(warrior.equipment, {"weapon": "longsword_iron", "armor": "leather_armor"})


   func test_effective_weapon_damage_range_and_name_come_from_the_equipped_weapon() -> void:
   	assert_eq(GameSession.get_effective_weapon_damage_range(GameSession.WARRIOR_ID), Vector2i(1, 8))
   	assert_eq(GameSession.get_effective_weapon_name(GameSession.WARRIOR_ID), "Longsword")


   func test_effective_defense_and_resistance_come_from_the_equipped_armor() -> void:
   	assert_eq(GameSession.get_effective_defense(GameSession.WARRIOR_ID), 10)
   	assert_eq(GameSession.get_effective_resistance(GameSession.WARRIOR_ID), 10)


   func test_effective_equipment_getters_return_zero_for_an_unknown_adventurer() -> void:
   	assert_eq(GameSession.get_effective_weapon_damage_range("no_such_id"), Vector2i.ZERO)
   	assert_eq(GameSession.get_effective_weapon_name("no_such_id"), "")
   	assert_eq(GameSession.get_effective_defense("no_such_id"), 0)
   	assert_eq(GameSession.get_effective_resistance("no_such_id"), 0)


   func test_set_adventurer_weapon_changes_the_equipped_weapon_and_rejects_an_unknown_item_or_adventurer() -> void:
   	var changed: bool = GameSession.set_adventurer_weapon(GameSession.WARRIOR_ID, "dagger_steel")
   	assert_true(changed)
   	assert_eq(GameSession.get_effective_weapon_damage_range(GameSession.WARRIOR_ID), Vector2i(2, 5))

   	assert_false(GameSession.set_adventurer_weapon(GameSession.WARRIOR_ID, "leather_armor"), "An armor id is not a valid weapon")
   	assert_false(GameSession.set_adventurer_weapon("no_such_id", "dagger_iron"), "An unknown adventurer cannot be equipped")


   func test_set_adventurer_armor_changes_the_equipped_armor_and_rejects_an_unknown_item_or_adventurer() -> void:
   	var changed: bool = GameSession.set_adventurer_armor(GameSession.WARRIOR_ID, "platemail_armor")
   	assert_true(changed)
   	assert_eq(GameSession.get_effective_defense(GameSession.WARRIOR_ID), 15)
   	assert_eq(GameSession.get_effective_resistance(GameSession.WARRIOR_ID), 30)

   	assert_false(GameSession.set_adventurer_armor(GameSession.WARRIOR_ID, "dagger_iron"), "A weapon id is not a valid armor")
   	assert_false(GameSession.set_adventurer_armor("no_such_id", "leather_armor"), "An unknown adventurer cannot be equipped")
   ```

2. **Run the tests to verify they fail.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gunit_test_name=equipment -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gunit_test_name=effective_weapon -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gunit_test_name=effective_defense -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gunit_test_name=set_adventurer -gexit
   ```

   Expected: FAIL — `warrior.equipment` is an invalid key access (the field
   does not exist yet), and the new getter/setter calls are `Nonexistent
   function` errors.

3. **Implement.** In `scripts/autoload/game_session.gd`, in
   `get_default_warrior()` (currently lines 127-149), replace the
   `"weapon": "sword",` line with:

   ```gdscript
   			"equipment": {"weapon": DEFAULT_WEAPON_ID, "armor": DEFAULT_ARMOR_ID},
   ```

   In `RECRUITMENT_CANDIDATE_TEMPLATES` (currently lines 163-191), replace
   each of the three `"weapon": "sword",` lines with the same
   `"equipment": {"weapon": DEFAULT_WEAPON_ID, "armor": DEFAULT_ARMOR_ID},`
   line.

   Add these methods near `get_effective_move_range()` (the last method in
   the file):

   ```gdscript
   ## Returns (damage_min, damage_max) from the adventurer's equipped weapon, or
   ## Vector2i.ZERO for an unknown adventurer or an equipped weapon id that has
   ## fallen out of WEAPONS (should not happen outside of hand-edited state).
   func get_effective_weapon_damage_range(adventurer_id: String) -> Vector2i:
   	var adventurer := get_adventurer(adventurer_id)
   	if adventurer.is_empty():
   		return Vector2i.ZERO
   	var weapon: Dictionary = WEAPONS.get(adventurer.equipment.weapon, {})
   	if weapon.is_empty():
   		return Vector2i.ZERO
   	return Vector2i(weapon.damage_min, weapon.damage_max)


   func get_effective_weapon_name(adventurer_id: String) -> String:
   	var adventurer := get_adventurer(adventurer_id)
   	if adventurer.is_empty():
   		return ""
   	var weapon: Dictionary = WEAPONS.get(adventurer.equipment.weapon, {})
   	return "" if weapon.is_empty() else tr(weapon.name_key)


   func get_effective_defense(adventurer_id: String) -> int:
   	var adventurer := get_adventurer(adventurer_id)
   	if adventurer.is_empty():
   		return 0
   	var armor: Dictionary = ARMORS.get(adventurer.equipment.armor, {})
   	return 0 if armor.is_empty() else int(armor.defense)


   func get_effective_resistance(adventurer_id: String) -> int:
   	var adventurer := get_adventurer(adventurer_id)
   	if adventurer.is_empty():
   		return 0
   	var armor: Dictionary = ARMORS.get(adventurer.equipment.armor, {})
   	return 0 if armor.is_empty() else int(armor.resistance)


   ## Equips weapon_id into adventurer_id's weapon slot. Rejects an id that is not
   ## in WEAPONS (including a valid armor id) and an unknown adventurer, without
   ## mutating anything either way.
   func set_adventurer_weapon(adventurer_id: String, weapon_id: String) -> bool:
   	if not WEAPONS.has(weapon_id):
   		return false
   	var adventurer_index := _get_adventurer_index(adventurer_id)
   	if adventurer_index == -1:
   		return false
   	adventurers[adventurer_index].equipment.weapon = weapon_id
   	return true


   func set_adventurer_armor(adventurer_id: String, armor_id: String) -> bool:
   	if not ARMORS.has(armor_id):
   		return false
   	var adventurer_index := _get_adventurer_index(adventurer_id)
   	if adventurer_index == -1:
   		return false
   	adventurers[adventurer_index].equipment.armor = armor_id
   	return true
   ```

4. **Run the tests to verify they pass.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit
   ```

   Expected: PASS.

5. **Commit** only this task's files:

   ```bash
   git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd
   git commit -m "feat: give adventurers an equipment slot and effective-equipment getters"
   ```

## Milestone

Every adventurer (the starting Warrior and every recruitment candidate)
starts with an Iron Longsword and Leather Armor; `get_effective_*` getters
correctly derive damage range/defense/resistance from whatever is equipped,
and `set_adventurer_weapon`/`set_adventurer_armor` are the only path that
changes it, rejecting cross-slot and unknown-adventurer input.
