# Task 01: Weapon and armor catalogs on `GameSession`

## Objective

Add the weapon and armor content tables — item id → stats — that every
later task in this plan reads from, plus a single lookup helper that finds
an id in either table.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Test: `tests/unit/test_game_session.gd`

## Produces

`GameSession.WEAPONS: Dictionary` (item id `String` → `{name_key: String,
slot: "weapon", damage_min: int, damage_max: int, price: int}`),
`GameSession.ARMORS: Dictionary` (item id `String` → `{name_key: String,
slot: "armor", defense: int, resistance: int, price: int}`),
`GameSession.get_item_definition(item_id: String) -> Dictionary`.

## Steps

1. **Write the failing tests.** Add to `tests/unit/test_game_session.gd`:

   ```gdscript
   func test_weapons_catalog_has_the_documented_iron_and_steel_damage_and_price() -> void:
   	assert_eq(GameSessionScript.WEAPONS.dagger_iron, {"name_key": "item.dagger", "slot": "weapon", "damage_min": 1, "damage_max": 4, "price": 10})
   	assert_eq(GameSessionScript.WEAPONS.dagger_steel, {"name_key": "item.dagger", "slot": "weapon", "damage_min": 2, "damage_max": 5, "price": 30})
   	assert_eq(GameSessionScript.WEAPONS.shortsword_iron, {"name_key": "item.shortsword", "slot": "weapon", "damage_min": 1, "damage_max": 6, "price": 20})
   	assert_eq(GameSessionScript.WEAPONS.shortsword_steel, {"name_key": "item.shortsword", "slot": "weapon", "damage_min": 2, "damage_max": 7, "price": 60})
   	assert_eq(GameSessionScript.WEAPONS.longsword_iron, {"name_key": "item.longsword", "slot": "weapon", "damage_min": 1, "damage_max": 8, "price": 30})
   	assert_eq(GameSessionScript.WEAPONS.longsword_steel, {"name_key": "item.longsword", "slot": "weapon", "damage_min": 2, "damage_max": 9, "price": 90})
   	assert_eq(GameSessionScript.WEAPONS.two_handed_sword_iron, {"name_key": "item.two_handed_sword", "slot": "weapon", "damage_min": 1, "damage_max": 10, "price": 35})
   	assert_eq(GameSessionScript.WEAPONS.two_handed_sword_steel, {"name_key": "item.two_handed_sword", "slot": "weapon", "damage_min": 2, "damage_max": 11, "price": 105})


   func test_armors_catalog_has_the_documented_defense_resistance_and_price() -> void:
   	assert_eq(GameSessionScript.ARMORS.leather_armor, {"name_key": "item.leather_armor", "slot": "armor", "defense": 10, "resistance": 10, "price": 10})
   	assert_eq(GameSessionScript.ARMORS.chainmail_armor, {"name_key": "item.chainmail_armor", "slot": "armor", "defense": 15, "resistance": 20, "price": 30})
   	assert_eq(GameSessionScript.ARMORS.split_armor, {"name_key": "item.split_armor", "slot": "armor", "defense": 15, "resistance": 25, "price": 50})
   	assert_eq(GameSessionScript.ARMORS.platemail_armor, {"name_key": "item.platemail_armor", "slot": "armor", "defense": 15, "resistance": 30, "price": 200})
   	assert_eq(GameSessionScript.ARMORS.full_plate_armor, {"name_key": "item.full_plate_armor", "slot": "armor", "defense": 15, "resistance": 35, "price": 500})


   func test_get_item_definition_finds_a_weapon_then_an_armor_then_returns_empty() -> void:
   	var session: Node = GameSessionScript.new()
   	autofree(session)

   	assert_eq(session.get_item_definition("longsword_iron"), GameSessionScript.WEAPONS.longsword_iron)
   	assert_eq(session.get_item_definition("leather_armor"), GameSessionScript.ARMORS.leather_armor)
   	assert_eq(session.get_item_definition("no_such_item"), {})
   ```

2. **Run the tests to verify they fail.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gunit_test_name=weapons_catalog -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gunit_test_name=armors_catalog -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gunit_test_name=get_item_definition -gexit
   ```

   Expected: FAIL — `Invalid access to property or key 'WEAPONS'` (or
   `'ARMORS'`), or `Invalid call. Nonexistent function 'get_item_definition'`.

3. **Add the catalogs and lookup to `GameSession`.** In
   `scripts/autoload/game_session.gd`, add immediately after the
   `STAR_ENEMY_COMPOSITIONS` const block (after line 80):

   ```gdscript
   # Equipment catalog (docs/plans/trading-system.md "Equipment system"). Steel is
   # +1 damage over Iron on both ends of the range. Armor's defense reduces an
   # attacker's effective hit chance; resistance reduces incoming damage by that
   # percent, rounded to the nearest integer when applied (see BattleController).
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
   const ARMORS: Dictionary = {
   	"leather_armor": {"name_key": "item.leather_armor", "slot": "armor", "defense": 10, "resistance": 10, "price": 10},
   	"chainmail_armor": {"name_key": "item.chainmail_armor", "slot": "armor", "defense": 15, "resistance": 20, "price": 30},
   	"split_armor": {"name_key": "item.split_armor", "slot": "armor", "defense": 15, "resistance": 25, "price": 50},
   	"platemail_armor": {"name_key": "item.platemail_armor", "slot": "armor", "defense": 15, "resistance": 30, "price": 200},
   	"full_plate_armor": {"name_key": "item.full_plate_armor", "slot": "armor", "defense": 15, "resistance": 35, "price": 500},
   }
   const DEFAULT_WEAPON_ID := "longsword_iron"
   const DEFAULT_ARMOR_ID := "leather_armor"
   ```

   Add this method near `get_expedition()`:

   ```gdscript
   ## Looks up an item id in WEAPONS then ARMORS, returning a safe copy either
   ## way (an empty Dictionary for an unknown id, matching get_adventurer()'s
   ## and get_party()'s not-found convention).
   func get_item_definition(item_id: String) -> Dictionary:
   	if WEAPONS.has(item_id):
   		return WEAPONS[item_id].duplicate(true)
   	if ARMORS.has(item_id):
   		return ARMORS[item_id].duplicate(true)
   	return {}
   ```

4. **Run the tests to verify they pass.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit
   ```

   Expected: PASS (all `test_game_session.gd` tests, including the three new
   ones).

5. **Add translation keys.** In `translations/en.tres`, add after the
   `"buildings.guild_hall": "Guild Hall",` line:

   ```
   "item.dagger": "Dagger",
   "item.shortsword": "Shortsword",
   "item.longsword": "Longsword",
   "item.two_handed_sword": "Two-Handed Sword",
   "item.leather_armor": "Leather Armor",
   "item.chainmail_armor": "Chainmail Armor",
   "item.split_armor": "Split Armor",
   "item.platemail_armor": "Platemail Armor",
   "item.full_plate_armor": "Full Plate Armor",
   ```

6. **Commit** only this task's files:

   ```bash
   git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd translations/en.tres
   git commit -m "feat: add weapon and armor catalogs to GameSession"
   ```

## Milestone

`GameSession.WEAPONS`/`ARMORS` hold every item from the design doc's price
table with the exact documented stats, `get_item_definition()` resolves any
item id from either table, and `make test` is green — all before any other
system reads from these tables.
