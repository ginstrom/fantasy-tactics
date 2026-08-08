# Task 09: `GameSession` trading-post and item buy/sell/equip rules

## Objective

Add every gameplay rule the Trade screens (Tasks 12-15) will call through
to — purchasing the Trading Post, its passive income, pricing an item for
sale, selling, buying, and equipping from the bank — keeping the
"GameSession owns rules, screens are thin views" split.

## Files

- Modify: `scripts/autoload/game_session.gd`, `scripts/autoload/game_config.gd`,
  `config/game_config.json`
- Test: `tests/unit/test_game_session.gd`

## Depends on

Task 01 (`WEAPONS`, `ARMORS`, `get_item_definition()`), Task 06
(`MANA_CRYSTAL_VALUES`), Task 07 (`banked_gear`, `mana_crystals`), Task 02
(the `equipment` field `equip_item_from_bank` writes into).

## Produces

`GameSession.has_trading_post: bool`, `GameSession.TRADING_POST_PURCHASE_
COST: int`, `GameSession.TRADING_POST_INCOME_PER_TURN: int`,
`GameSession.can_purchase_trading_post() -> bool`,
`GameSession.purchase_trading_post() -> bool`,
`GameSession.get_item_sale_price(item_id: String) -> int`,
`GameSession.sell_item(item_id: String, quantity: int = 1) -> bool`,
`GameSession.buy_item(item_id: String) -> bool`,
`GameSession.equip_item_from_bank(adventurer_id: String, item_id: String) ->
bool`.

## Steps

1. **Write the failing tests.** Add to `tests/unit/test_game_session.gd`:

   ```gdscript
   func test_new_session_has_no_trading_post() -> void:
   	assert_false(GameSession.has_trading_post)


   func test_can_purchase_trading_post_requires_enough_gold_and_not_already_owning_one() -> void:
   	assert_false(GameSession.can_purchase_trading_post(), "No gold, cannot afford it")

   	GameSession.gold = GameSession.TRADING_POST_PURCHASE_COST
   	assert_true(GameSession.can_purchase_trading_post())

   	GameSession.purchase_trading_post()
   	assert_false(GameSession.can_purchase_trading_post(), "Already owning one blocks a second purchase")


   func test_purchase_trading_post_deducts_gold_and_sets_the_flag_once() -> void:
   	GameSession.gold = GameSession.TRADING_POST_PURCHASE_COST

   	var purchased: bool = GameSession.purchase_trading_post()

   	assert_true(purchased)
   	assert_true(GameSession.has_trading_post)
   	assert_eq(GameSession.gold, 0)
   	assert_false(GameSession.purchase_trading_post(), "A second purchase must fail")


   func test_end_world_turn_adds_trading_post_income_only_once_purchased() -> void:
   	GameSession.create_party()
   	GameSession.end_world_turn()
   	assert_eq(GameSession.gold, 0, "No income without a Trading Post")

   	GameSession.gold = GameSession.TRADING_POST_PURCHASE_COST
   	GameSession.purchase_trading_post()
   	GameSession.end_world_turn()

   	assert_eq(GameSession.gold, GameSession.TRADING_POST_INCOME_PER_TURN)


   func test_get_item_sale_price_halves_gear_price_and_keeps_mana_crystal_value_full() -> void:
   	assert_eq(GameSession.get_item_sale_price("shortsword_iron"), 10, "Half of 20")
   	assert_eq(GameSession.get_item_sale_price("leather_armor"), 5, "Half of 10")
   	assert_eq(GameSession.get_item_sale_price("mana_crystal_1"), 5)
   	assert_eq(GameSession.get_item_sale_price("mana_crystal_2"), 15)
   	assert_eq(GameSession.get_item_sale_price("no_such_item"), 0)


   func test_sell_item_requires_a_trading_post_and_enough_stock() -> void:
   	GameSession.banked_gear = {"shortsword_iron": 1}

   	assert_false(GameSession.sell_item("shortsword_iron"), "No Trading Post yet")

   	GameSession.has_trading_post = true
   	assert_false(GameSession.sell_item("shortsword_iron", 2), "Only 1 in stock")

   	var sold: bool = GameSession.sell_item("shortsword_iron", 1)
   	assert_true(sold)
   	assert_eq(GameSession.banked_gear.shortsword_iron, 0)
   	assert_eq(GameSession.gold, 10)


   func test_sell_item_handles_mana_crystals() -> void:
   	GameSession.has_trading_post = true
   	GameSession.mana_crystals = {1: 2}

   	var sold: bool = GameSession.sell_item("mana_crystal_1", 2)

   	assert_true(sold)
   	assert_eq(GameSession.mana_crystals[1], 0)
   	assert_eq(GameSession.gold, 10)


   func test_buy_item_requires_a_trading_post_and_enough_gold_then_banks_the_item() -> void:
   	assert_false(GameSession.buy_item("dagger_iron"), "No Trading Post yet")

   	GameSession.has_trading_post = true
   	assert_false(GameSession.buy_item("dagger_iron"), "No gold yet")

   	GameSession.gold = 10
   	var bought: bool = GameSession.buy_item("dagger_iron")

   	assert_true(bought)
   	assert_eq(GameSession.gold, 0)
   	assert_eq(GameSession.banked_gear.dagger_iron, 1)


   func test_equip_item_from_bank_moves_the_item_from_the_bank_onto_the_unit_and_returns_the_old_one() -> void:
   	GameSession.banked_gear = {"dagger_steel": 1}

   	var equipped: bool = GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")

   	assert_true(equipped)
   	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.weapon, "dagger_steel")
   	assert_eq(GameSession.banked_gear.dagger_steel, 0)
   	assert_eq(GameSession.banked_gear.longsword_iron, 1, "The previously-equipped Iron Longsword returns to the bank")


   func test_equip_item_from_bank_rejects_an_item_not_in_stock_or_an_unknown_adventurer() -> void:
   	assert_false(GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel"), "Nothing in stock")

   	GameSession.banked_gear = {"dagger_steel": 1}
   	assert_false(GameSession.equip_item_from_bank("no_such_id", "dagger_steel"))
   	assert_eq(GameSession.banked_gear.dagger_steel, 1, "A rejected equip must not touch the bank")


   func test_reset_clears_the_trading_post() -> void:
   	GameSession.has_trading_post = true

   	GameSession.reset()

   	assert_false(GameSession.has_trading_post)
   ```

2. **Run the tests to verify they fail.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gunit_test_name=trading_post -gexit
   ```

   (and the other new test names: `sale_price`, `sell_item`, `buy_item`,
   `equip_item_from_bank`). Expected: FAIL — `Invalid access to property or
   key 'has_trading_post'` (etc.).

3. **Add the `GameConfig` section.** In `scripts/autoload/game_config.gd`'s
   `DEFAULTS`, add a new top-level section after `"population"`:

   ```gdscript
   	"trading_post": {
   		"purchase_cost": 50,
   		"income_per_turn": 1,
   	},
   ```

   In `config/game_config.json`, add the matching section after
   `"population"` (note: JSON has no trailing comma on the last section):

   ```json
   	"trading_post": {
   		"purchase_cost": 50,
   		"income_per_turn": 1
   	}
   ```

   (`tests/unit/test_game_config.gd`'s
   `test_defaults_mirror_the_shipped_config_file_exactly` already verifies
   these two stay in sync key-for-key — no test changes needed there.)

4. **Implement in `scripts/autoload/game_session.gd`.** Add next to
   `var GUILD_HALL_MAX_LEVEL: int = 2`:

   ```gdscript
   var TRADING_POST_PURCHASE_COST: int = 50
   var TRADING_POST_INCOME_PER_TURN: int = 1
   ```

   In `_load_balance_config()`, add:

   ```gdscript
   	TRADING_POST_PURCHASE_COST = GameConfig.get_int("trading_post", "purchase_cost", TRADING_POST_PURCHASE_COST)
   	TRADING_POST_INCOME_PER_TURN = GameConfig.get_int("trading_post", "income_per_turn", TRADING_POST_INCOME_PER_TURN)
   ```

   Add next to `var pending_gear: Array[String] = []` (Task 07):

   ```gdscript
   var has_trading_post: bool = false
   ```

   In `reset()`, add next to Task 07's loot-state resets:

   ```gdscript
   	has_trading_post = false
   ```

   In `end_world_turn()`, add the income line right after
   `world_turn += 1`:

   ```gdscript
   	world_turn += 1
   	if has_trading_post:
   		gold += TRADING_POST_INCOME_PER_TURN
   	if has_deployed_party():
   ```

   Add these methods near `can_upgrade_guild_hall()`/`upgrade_guild_hall()`:

   ```gdscript
   func can_purchase_trading_post() -> bool:
   	return not has_trading_post and gold >= TRADING_POST_PURCHASE_COST


   func purchase_trading_post() -> bool:
   	if not can_purchase_trading_post():
   		return false
   	gold -= TRADING_POST_PURCHASE_COST
   	has_trading_post = true
   	return true
   ```

   Add these methods near `get_item_definition()` (Task 01):

   ```gdscript
   const MANA_CRYSTAL_ID_PREFIX := "mana_crystal_"


   ## Gear sells for half its catalog price (rounded to the nearest integer); a
   ## mana crystal id ("mana_crystal_<tier>") sells for its full listed value,
   ## since it was never purchased at a price to halve. An unknown id prices at
   ## 0 rather than erroring, matching get_item_definition()'s not-found style.
   func get_item_sale_price(item_id: String) -> int:
   	if item_id.begins_with(MANA_CRYSTAL_ID_PREFIX):
   		var tier := int(item_id.trim_prefix(MANA_CRYSTAL_ID_PREFIX))
   		return MANA_CRYSTAL_VALUES.get(tier, 0)
   	var item := get_item_definition(item_id)
   	return 0 if item.is_empty() else int(round(item.price / 2.0))


   ## Requires a Trading Post (design doc: selling is only available "if we have
   ## a Trading Post") and at least `quantity` of item_id in stock (banked_gear
   ## for gear, mana_crystals for a "mana_crystal_<tier>" id). Rejects and
   ## mutates nothing otherwise.
   func sell_item(item_id: String, quantity: int = 1) -> bool:
   	if not has_trading_post or quantity <= 0:
   		return false
   	if item_id.begins_with(MANA_CRYSTAL_ID_PREFIX):
   		var tier := int(item_id.trim_prefix(MANA_CRYSTAL_ID_PREFIX))
   		if mana_crystals.get(tier, 0) < quantity:
   			return false
   		mana_crystals[tier] -= quantity
   		gold += get_item_sale_price(item_id) * quantity
   		return true
   	if banked_gear.get(item_id, 0) < quantity:
   		return false
   	banked_gear[item_id] -= quantity
   	gold += get_item_sale_price(item_id) * quantity
   	return true


   ## Requires a Trading Post and enough gold for item_id's full catalog price.
   ## Buys exactly one unit, banking it into banked_gear.
   func buy_item(item_id: String) -> bool:
   	if not has_trading_post:
   		return false
   	var item := get_item_definition(item_id)
   	if item.is_empty() or gold < int(item.price):
   		return false
   	gold -= int(item.price)
   	banked_gear[item_id] = banked_gear.get(item_id, 0) + 1
   	return true


   ## Moves one unit of item_id out of banked_gear onto adventurer_id's matching
   ## equipment slot (weapon or armor, from the item's own "slot" field), and
   ## returns whatever was previously equipped in that slot back to the bank —
   ## equipment is a swap, not a one-way consumption, so the adventurer's
   ## starting gear (or a previous purchase) is never silently lost. Rejects an
   ## item not in stock, an unknown item id, or an unknown adventurer, without
   ## mutating anything either way.
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
   	var previous_item_id: String = adventurers[adventurer_index].equipment.get(slot, "")
   	banked_gear[item_id] -= 1
   	adventurers[adventurer_index].equipment[slot] = item_id
   	if previous_item_id != "":
   		banked_gear[previous_item_id] = banked_gear.get(previous_item_id, 0) + 1
   	return true
   ```

5. **Run the tests to verify they pass.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit
   ```

   Expected: PASS.

6. **Run the full suite.**

   ```bash
   make test
   ```

   Expected: `---- All tests passed! ----`, exit code 0 (this also confirms
   `test_game_config.gd`'s DEFAULTS-mirrors-shipped-file check still passes
   with the new `trading_post` section).

7. **Commit** only this task's files:

   ```bash
   git add scripts/autoload/game_session.gd scripts/autoload/game_config.gd config/game_config.json tests/unit/test_game_session.gd
   git commit -m "feat: add Trading Post purchase/income and item buy/sell/equip rules"
   ```

## Milestone

`GameSession` alone (no screen involved yet) can answer every rules
question the Trade UI will need: can/does the Trading Post get purchased,
what does an item sell for, can it be sold/bought, and can it be equipped
onto a given adventurer — with the previously-equipped item safely returned
to the bank on a swap.
