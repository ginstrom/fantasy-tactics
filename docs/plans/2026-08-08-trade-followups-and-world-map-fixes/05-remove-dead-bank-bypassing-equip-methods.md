# Task 05: Remove dead bank-bypassing equip methods

## Objective

`GameSession.set_adventurer_weapon()`/`set_adventurer_armor()` are a
second equip path that Phase C of the trade plan never adopted — every
screen equips through `equip_item_from_bank()` instead, which correctly
consumes from and returns to `banked_gear`. These two methods overwrite
the slot directly without touching `banked_gear` at all, so calling either
one silently destroys the displaced item rather than banking it. They have
zero production callers (only their own two tests reference them) — remove
them before someone wires a UI to the wrong one.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Test: `tests/unit/test_game_session.gd`

## Depends on

None.

## Produces

`GameSession.set_adventurer_weapon()` and `set_adventurer_armor()` no
longer exist.

## Steps

1. **Confirm there really are no other callers** before deleting anything:

   ```bash
   grep -rn "set_adventurer_weapon\|set_adventurer_armor" scripts tests
   ```

   Expected: only `scripts/autoload/game_session.gd`'s own two function
   definitions and `tests/unit/test_game_session.gd`'s two tests for them.
   If this grep turns up anything else, stop and report it instead of
   deleting — the removal in this task assumes it's genuinely dead.

2. **Delete the two methods.** In `scripts/autoload/game_session.gd`,
   remove this block in full (currently around lines 1309-1330, including
   the doc comment):

   ```gdscript
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

3. **Delete their tests.** In `tests/unit/test_game_session.gd`, remove
   both test functions in full (currently around lines 2184-2200):

   ```gdscript
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

4. **Run the full suite.**

   ```bash
   make test
   ```

   Expected: `---- All tests passed! ----`, exit code 0, with two fewer
   tests than before this task.

5. **Commit** only this task's files:

   ```bash
   git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd
   git commit -m "refactor: remove dead bank-bypassing equip methods"
   ```

## Milestone

`equip_item_from_bank()` is the only way to change an adventurer's
equipment in the codebase — there is no longer a second path that silently
destroys the displaced item.
