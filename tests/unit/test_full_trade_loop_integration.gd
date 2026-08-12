extends GutTest

## Proves the whole Trade loop works together, not just each screen in
## isolation: upgrade the Shop, buy a weapon, assign it to the
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
	GameSession.reset()
	GameManager.close_game_menu()
	GameManager.route_context_id = ""


func test_full_trade_loop_buy_assign_and_fight_with_new_equipment() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.gold = GameSession.SHOP_UPGRADE_COST + GameSession.WEAPONS.dagger_steel.price

	# Trade -> Shop is immediately available; upgrade it for steel weapons.
	var trade_screen: Control = TradeScene.instantiate()
	add_child_autofree(trade_screen)
	assert_true(GameSession.upgrade_shop())

	# Shop -> buy a Steel Dagger.
	var trading_post_screen: Control = TradingPostScene.instantiate()
	add_child_autofree(trading_post_screen)
	trading_post_screen.selected_item_id = "dagger_steel"
	var buy_button: Button = trading_post_screen.get_node("Body/Center/VBox/BuyButton")
	buy_button.emit_signal("pressed")
	assert_eq(GameSession.banked_gear.get("dagger_steel", 0), 1, "the bought dagger lands in the bank")
	assert_eq(GameSession.gold, 0)

	# Stores -> select the Steel Dagger row and use the direct Equip action
	# to route to Assign Equipment.
	var stores_screen: Control = StoresScene.instantiate()
	add_child_autofree(stores_screen)
	var stores_tree: Tree = stores_screen.get_node("Body/Center/VBox/LootTable/Content/Table/Tree")
	var dagger_item := stores_tree.get_root().get_first_child()
	dagger_item.select(0)
	stores_tree.emit_signal("item_selected")
	var equip_button: Button = stores_screen.get_node(
		"Body/Center/VBox/LootTable/Content/DirectActionBar/EquipButton"
	)
	assert_false(equip_button.disabled, "the gear row enables Stores' direct Equip action")
	equip_button.emit_signal("pressed")
	assert_eq(GameManager.route_context_id, "dagger_steel")

	# Assign Equipment -> equip the Warrior.
	var assign_screen: Control = AssignEquipmentScene.instantiate()
	add_child_autofree(assign_screen)
	assign_screen._on_row_activated(GameSession.WARRIOR_ID)
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

	# Field the Warrior in battle: the fielded Unit's damage range must be
	# the newly-equipped Steel Dagger's (2-5), not the old Iron Longsword's
	# (1-8) or any other stale default.
	GameManager.deploy_party(GameSession.FIRST_PARTY_ID)
	GameSession.set_deployed_party_position(GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position)
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)

	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	var attacker = battlefield.grid.units[0]
	assert_eq(attacker.damage_min, 2, "Steel Dagger's documented minimum damage")
	assert_eq(attacker.damage_max, 5, "Steel Dagger's documented maximum damage")
