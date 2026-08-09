# Step 1: GameSession Inventory Data Model and API

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Branch:** `weapon-armor-inventory-api`

**Goal:** Add `weapon_inventory: Array[String]`/`armor_inventory:
Array[String]` fields to every adventurer's `equipment` dict (everything
carried; always includes the active id). Replace `equip_item_from_bank`'s
swap-and-rebank behavior with add-and-activate, and add
`activate_carried_item`/`unequip_to_bank`. `adventurer.equipment.weapon`/
`.armor` keep their exact current meaning (the active item) — every
combat/effective-stat getter that reads them is untouched by this step.

**Files:**
- Modify: `scripts/autoload/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_full_trade_loop_integration.gd`

## Step 1: Write the failing tests

### New/changed tests in `tests/unit/test_game_session.gd`

Find `test_equip_item_from_bank_moves_the_item_from_the_bank_onto_the_unit_and_returns_the_old_one`
(search for that name) and replace it:

```gdscript
func test_equip_item_from_bank_adds_the_new_item_and_activates_it_without_evicting_the_old_one() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"dagger_steel": 1}

	var equipped: bool = GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")

	assert_true(equipped)
	var equipment: Dictionary = GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment
	assert_eq(equipment.weapon, "dagger_steel", "The newly-equipped item becomes active")
	assert_eq(
		equipment.weapon_inventory, ["longsword_iron", "dagger_steel"],
		"The starting Iron Longsword stays carried, not evicted to the bank"
	)
	assert_eq(GameSession.banked_gear.dagger_steel, 0, "The new item leaves the bank")
	assert_eq(
		GameSession.banked_gear.get("longsword_iron", 0), 0,
		"The previously-active Iron Longsword must NOT reappear in the bank"
	)


func test_equipping_an_already_carried_item_reactivates_it_without_touching_the_bank() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"dagger_steel": 2}
	GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")
	# A second Steel Dagger sits in the bank; the unit already carries one.
	assert_eq(GameSession.banked_gear.dagger_steel, 1)
	# Switch back to the Iron Longsword (now inactive but still carried) via
	# activate_carried_item, not equip_item_from_bank -- the Iron Longsword
	# was never itself in the bank, so equip_item_from_bank would correctly
	# reject it here (see the "Requires item_id to currently be in
	# banked_gear" precondition below).
	GameSession.activate_carried_item(GameSession.WARRIOR_ID, "weapon", "longsword_iron")

	var equipped: bool = GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")

	assert_true(equipped)
	var equipment: Dictionary = GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment
	assert_eq(equipment.weapon, "dagger_steel", "Re-equipping re-activates the already-carried copy")
	assert_eq(
		equipment.weapon_inventory, ["longsword_iron", "dagger_steel"],
		"No duplicate entry — the unit already carried this exact item"
	)
	assert_eq(GameSession.banked_gear.dagger_steel, 1, "The spare bank copy is untouched, not consumed again")
```

`test_equip_item_from_bank_rejects_an_item_not_in_stock_or_an_unknown_adventurer`
needs no changes — its two rejection cases (nothing in stock, unknown
adventurer) behave identically under the new logic.

Add new tests for the two new methods, right after the `equip_item_from_bank`
tests:

```gdscript
func test_activate_carried_item_switches_the_active_weapon_without_touching_the_bank() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"dagger_steel": 1}
	GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")

	var activated: bool = GameSession.activate_carried_item(GameSession.WARRIOR_ID, "weapon", "longsword_iron")

	assert_true(activated)
	var equipment: Dictionary = GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment
	assert_eq(equipment.weapon, "longsword_iron")
	assert_eq(
		equipment.weapon_inventory, ["longsword_iron", "dagger_steel"],
		"Activating a carried item must not change what's carried"
	)
	assert_eq(GameSession.banked_gear.get("dagger_steel", 0), 0, "No bank interaction")


func test_activate_carried_item_rejects_an_uncarried_item_an_unknown_slot_or_adventurer() -> void:
	GameSession.reset()

	assert_false(
		GameSession.activate_carried_item(GameSession.WARRIOR_ID, "weapon", "dagger_steel"),
		"Not carried"
	)
	assert_false(
		GameSession.activate_carried_item(GameSession.WARRIOR_ID, "shield", "longsword_iron"),
		"Unknown slot"
	)
	assert_false(
		GameSession.activate_carried_item("no_such_id", "weapon", "longsword_iron"),
		"Unknown adventurer"
	)
	assert_eq(
		GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.weapon, "longsword_iron",
		"Every rejected call must leave the active weapon untouched"
	)


func test_unequip_to_bank_removes_a_non_active_carried_item_and_banks_it() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"dagger_steel": 1}
	GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")
	# longsword_iron is now carried but inactive.

	var unequipped: bool = GameSession.unequip_to_bank(GameSession.WARRIOR_ID, "weapon", "longsword_iron")

	assert_true(unequipped)
	var equipment: Dictionary = GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment
	assert_eq(equipment.weapon_inventory, ["dagger_steel"])
	assert_eq(equipment.weapon, "dagger_steel", "The active item is unaffected")
	assert_eq(GameSession.banked_gear.longsword_iron, 1)


func test_unequip_to_bank_rejects_the_active_item_an_uncarried_item_or_an_unknown_adventurer() -> void:
	GameSession.reset()

	assert_false(
		GameSession.unequip_to_bank(GameSession.WARRIOR_ID, "weapon", "longsword_iron"),
		"Cannot unequip the only (and therefore active) carried weapon"
	)
	assert_false(
		GameSession.unequip_to_bank(GameSession.WARRIOR_ID, "weapon", "dagger_steel"),
		"Not carried"
	)
	assert_false(
		GameSession.unequip_to_bank("no_such_id", "weapon", "longsword_iron"),
		"Unknown adventurer"
	)
	assert_eq(
		GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.weapon_inventory, ["longsword_iron"],
		"Every rejected call must leave the inventory untouched"
	)
	assert_eq(GameSession.banked_gear, {}, "Nothing rejected should ever reach the bank")
```

## Step 2: Run the tests to verify they fail

```
godot --headless -s addons/gut/gut_cmdln.gd -gunit_test_name=test_equip_item_from_bank -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gunit_test_name=test_activate_carried_item -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gunit_test_name=test_unequip_to_bank -gexit
```

Expected: every new/changed test FAILS — `activate_carried_item`/
`unequip_to_bank` don't exist yet, `equip_item_from_bank` still swaps, and
`weapon_inventory`/`armor_inventory` aren't real dict keys yet
(`equipment.weapon_inventory` reads as `null`, so the array-equality
assertions fail).

## Step 3: Add the inventory fields to every adventurer template

In `scripts/autoload/game_session.gd`, there are exactly four places that
construct an adventurer's `"equipment"` dict — `get_default_warrior()` and
the three entries of `RECRUITMENT_CANDIDATE_TEMPLATES` (search for
`"equipment":` to find all four; they're currently identical one-liners).
Change each from:

```gdscript
		"equipment": {"weapon": DEFAULT_WEAPON_ID, "armor": DEFAULT_ARMOR_ID},
```

to:

```gdscript
		"equipment": {
			"weapon": DEFAULT_WEAPON_ID, "weapon_inventory": [DEFAULT_WEAPON_ID],
			"armor": DEFAULT_ARMOR_ID, "armor_inventory": [DEFAULT_ARMOR_ID],
		},
```

(`RECRUITMENT_CANDIDATE_TEMPLATES` is a `const Array[Dictionary]` — array
literals with nested dictionaries are fine as const initializers in
GDScript, so this is a mechanical find-and-replace at all four sites, not
a structural change.)

## Step 4: Rewrite `equip_item_from_bank` and add the two new methods

Find `func equip_item_from_bank` (search for it) and replace the whole
function, plus add the two new ones right after it:

```gdscript
## Requires item_id to currently be in banked_gear (an item a screen no
## longer lists, because its bank count already hit zero, is never
## reachable here). Makes item_id the active item for its slot. If the
## unit doesn't already carry item_id, one unit is taken from the bank and
## added to that slot's inventory array. If the unit already carries that
## exact item (e.g. a second copy sits in the bank while the first is
## already equipped), the bank is left untouched and this call just
## re-activates the already-carried copy. Rejects (mutates nothing) for an
## unknown item id or an unknown adventurer. Equipment is no longer a
## swap: nothing the unit already carries is ever evicted to the bank by
## equipping something new — see activate_carried_item()/unequip_to_bank()
## for the other two equipment actions.
func equip_item_from_bank(adventurer_id: String, item_id: String) -> bool:
	if banked_gear.get(item_id, 0) <= 0:
		return false
	var item := get_item_definition(item_id)
	if item.is_empty():
		return false
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false

	var slot: String = item.slot
	var inventory: Array = adventurers[adventurer_index].equipment["%s_inventory" % slot]
	if not inventory.has(item_id):
		banked_gear[item_id] -= 1
		inventory.append(item_id)
	adventurers[adventurer_index].equipment[slot] = item_id
	return true


## Switches the active item for `slot` ("weapon" or "armor") to item_id,
## which must already be in that slot's inventory array. No bank
## interaction. Rejects an item not carried in that slot, an unknown slot,
## or an unknown adventurer, mutating nothing.
func activate_carried_item(adventurer_id: String, slot: String, item_id: String) -> bool:
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false
	var equipment: Dictionary = adventurers[adventurer_index].equipment
	var inventory_key := "%s_inventory" % slot
	if not equipment.has(inventory_key):
		return false
	var inventory: Array = equipment[inventory_key]
	if not inventory.has(item_id):
		return false
	adventurers[adventurer_index].equipment[slot] = item_id
	return true


## Removes item_id from slot's inventory array and returns one unit to
## banked_gear. Rejects (mutates nothing) if item_id is currently that
## slot's active item — a unit can never end up with an empty active slot,
## so the player must activate something else first — if item_id isn't
## carried in that slot at all, for an unknown slot, or for an unknown
## adventurer.
func unequip_to_bank(adventurer_id: String, slot: String, item_id: String) -> bool:
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false
	var equipment: Dictionary = adventurers[adventurer_index].equipment
	var inventory_key := "%s_inventory" % slot
	if not equipment.has(inventory_key):
		return false
	var inventory: Array = equipment[inventory_key]
	if not inventory.has(item_id) or equipment.get(slot, "") == item_id:
		return false
	inventory.erase(item_id)
	banked_gear[item_id] = banked_gear.get(item_id, 0) + 1
	return true
```

## Step 5: Run the tests to verify they pass

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit
```

Expected: `N/N passed.`

## Step 6: Fix the now-stale integration test assertion

`tests/unit/test_full_trade_loop_integration.gd`'s
`test_full_trade_loop_buy_assign_and_fight_with_new_equipment` asserts the
old swap behavior after equipping the Steel Dagger:

```gdscript
	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.weapon, "dagger_steel")
	assert_eq(
		GameSession.banked_gear.get("longsword_iron", 0), 1,
		"the displaced default Iron Longsword returns to the bank"
	)
	assert_eq(GameSession.banked_gear.get("dagger_steel", 0), 0, "the assigned dagger leaves the bank")
```

Change the two `longsword_iron`/`dagger_steel` assertions to match the new
add-and-activate behavior:

```gdscript
	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.weapon, "dagger_steel")
	assert_eq(
		GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.weapon_inventory,
		["longsword_iron", "dagger_steel"],
		"the starting Iron Longsword stays carried, not evicted to the bank"
	)
	assert_eq(
		GameSession.banked_gear.get("longsword_iron", 0), 0,
		"the starting Iron Longsword was never in the bank to begin with"
	)
	assert_eq(GameSession.banked_gear.get("dagger_steel", 0), 0, "the assigned dagger leaves the bank")
```

Run:

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_full_trade_loop_integration.gd -gexit
```

Expected: `N/N passed.`

## Full local verification

```
make check
```

Expected: `N/N passed.` and `---- All tests passed! ----`, exit 0.

## Manual verification

```
make play
```

1. Press **FN+F9**, choose **Stocked Trading Post + Stores** (staffed
   party, Trading Post owned, a banked Iron Shortsword).
2. Trade → Trading Post → buy a second weapon (e.g. a Steel Dagger).
3. Trade → Stores → select the Steel Dagger row → View → Equip.
4. Units → Roster → the Warrior → Unit Details: confirm the Equipment
   line now shows the Steel Dagger's stats (this step doesn't add the new
   inventory list UI yet — that's Step 2 — so there's no visible carried
   list to check here; this step is really only exercisable through
   `make check`'s test coverage and the Equipment summary line updating to
   the newly-active weapon).

## Commit

```bash
git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd \
  tests/unit/test_full_trade_loop_integration.gd
git commit -m "feat: equip adds and activates instead of swapping, with a real weapon/armor inventory"
```

## Merge back to main

After user signoff on manual verification:

```bash
git checkout main
git merge weapon-armor-inventory-api
git branch -d weapon-armor-inventory-api
```
