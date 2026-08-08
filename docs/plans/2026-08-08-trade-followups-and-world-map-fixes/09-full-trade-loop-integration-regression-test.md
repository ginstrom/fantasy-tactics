# Task 09: Full trade-loop integration regression test

## Objective

Every trade screen has its own unit tests, and `GameSession`'s trading
rules have theirs, but no single test proves the whole loop works
together end to end: purchase the Trading Post, buy a weapon, assign it to
an adventurer, and field that adventurer in battle with the new weapon's
damage range. This automates exactly what the trade plan's Task 17 asked
the user to verify by hand via `make play`, so a future regression in any
one link of this chain gets caught by `make test` instead of requiring
another manual pass.

## Files

- Create: `tests/unit/test_full_trade_loop_integration.gd`

## Depends on

Task 03 (split weapon names — this test asserts on `dagger_steel`'s
behavior, not its display name, so it doesn't strictly need Task 03, but
land it first so the codebase-wide naming is consistent when this test is
written) and Task 04 (equipment readback — not exercised by this test
directly, but keeping Phase B's tasks landed first avoids merge-order
surprises).

## Produces

One new test file with one integration test,
`test_full_trade_loop_buy_assign_and_fight_with_new_equipment`.

## Steps

1. **Write the test.** Create `tests/unit/test_full_trade_loop_integration.gd`:

   ```gdscript
   extends GutTest

   ## Proves the whole Trade loop works together, not just each screen in
   ## isolation: purchase the Trading Post, buy a weapon, assign it to the
   ## Warrior, then field that Warrior in battle and confirm the equipped
   ## weapon's damage range -- not the old default's -- is what's live.
   ## Mirrors test_first_campaign_ui_flow.gd's real-battle-through-to-
   ## completion pattern, applied to the trade loop instead of the
   ## expedition loop.

   const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
   const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")
   const TradeScene := preload("res://scenes/ui/trade.tscn")
   const TradingPostScene := preload("res://scenes/ui/trading_post.tscn")
   const StoresScene := preload("res://scenes/ui/stores.tscn")
   const AssignEquipmentScene := preload("res://scenes/ui/assign_equipment.tscn")


   func before_each() -> void:
   	GameSession.reset()
   	GameManager.route_context_id = ""


   func after_each() -> void:
   	GameManager.close_game_menu()
   	GameManager.route_context_id = ""


   func test_full_trade_loop_buy_assign_and_fight_with_new_equipment() -> void:
   	GameSession.create_party()
   	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
   	GameSession.gold = GameSession.TRADING_POST_PURCHASE_COST + GameSession.WEAPONS.dagger_steel.price

   	# Trade -> purchase the Trading Post.
   	var trade_screen: Control = TradeScene.instantiate()
   	add_child_autofree(trade_screen)
   	var purchase_button: Button = trade_screen.get_node("Body/Center/VBox/PurchaseTradingPostButton")
   	assert_false(purchase_button.disabled, "gold covers the Trading Post's cost")
   	purchase_button.emit_signal("pressed")
   	assert_true(GameSession.has_trading_post)

   	# Trading Post -> buy a Steel Dagger.
   	var trading_post_screen: Control = TradingPostScene.instantiate()
   	add_child_autofree(trading_post_screen)
   	trading_post_screen.selected_item_id = "dagger_steel"
   	var buy_button: Button = trading_post_screen.get_node("Body/Center/VBox/BuyButton")
   	buy_button.emit_signal("pressed")
   	assert_eq(GameSession.banked_gear.get("dagger_steel", 0), 1, "the bought dagger lands in the bank")
   	assert_eq(GameSession.gold, 0)

   	# Stores -> select the Steel Dagger, confirm its detail is correct, then
   	# route to Assign Equipment the same way the real Assign button does.
   	var stores_screen: Control = StoresScene.instantiate()
   	add_child_autofree(stores_screen)
   	var stores_tree: Tree = stores_screen.get_node("Body/Center/VBox/StoresTable/Tree")
   	stores_tree.get_root().get_first_child().select(0)
   	stores_tree.emit_signal("item_selected")
   	assert_eq(stores_screen.selected_item_id, "dagger_steel")
   	assert_true(stores_screen.get_node("Body/Center/VBox/AssignButton").visible)
   	GameManager.route_context_id = "dagger_steel"

   	# Assign Equipment -> equip the Warrior.
   	var assign_screen: Control = AssignEquipmentScene.instantiate()
   	add_child_autofree(assign_screen)
   	assign_screen._on_row_activated(GameSession.WARRIOR_ID)
   	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.weapon, "dagger_steel")
   	assert_eq(
   		GameSession.banked_gear.get("longsword_iron", 0), 1,
   		"the displaced default Iron Longsword returns to the bank"
   	)
   	assert_eq(GameSession.banked_gear.get("dagger_steel", 0), 0, "the assigned dagger leaves the bank")

   	# Field the Warrior in battle: the fielded Unit's damage range must be
   	# the newly-equipped Steel Dagger's (2-5), not the old Iron Longsword's
   	# (1-8) or any other stale default.
   	GameManager.deploy_party(GameSession.FIRST_PARTY_ID)
   	GameSession.set_deployed_party_position(GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position)
   	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)

   	var battlefield: Node2D = BattlefieldScene.instantiate()
   	add_child_autofree(battlefield)

   	var attacker := battlefield.grid.units[0]
   	assert_eq(attacker.damage_min, 2, "Steel Dagger's documented minimum damage")
   	assert_eq(attacker.damage_max, 5, "Steel Dagger's documented maximum damage")
   ```

2. **Run the test to verify it passes.** This test is not expected to fail
   at any point — every link in this chain (Trade's purchase gate, Trading
   Post's buy, Stores' selection/Assign gating, Assign Equipment's
   activation, `BattleController`'s weapon-range fielding) already has its
   own passing unit tests from the trade plan; this test's only job is
   proving they compose correctly together, which they already do:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_full_trade_loop_integration.gd -gexit
   ```

   Expected: PASS. If it fails, that's a genuine integration bug between
   two independently-correct pieces — investigate rather than assuming the
   test itself is wrong.

3. **Run the full suite.**

   ```bash
   make test
   ```

   Expected: `---- All tests passed! ----`, exit code 0.

4. **Commit** only this task's file:

   ```bash
   git add tests/unit/test_full_trade_loop_integration.gd
   git commit -m "test: add a full Trade-loop integration regression test"
   ```

## Milestone

`make test` now automatically catches a regression in the seam between any
two Trade-loop screens — the exact class of bug that would otherwise only
surface during another manual `make play` pass.
