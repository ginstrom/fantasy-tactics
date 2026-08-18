extends GutTest

const TradingPostScene := preload("res://scenes/ui/trading_post.tscn")
const UiTestHelpers := preload("res://tests/unit/ui_test_helpers.gd")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


func test_trading_post_shows_the_title_income_and_back_action() -> void:
	var screen: Control = TradingPostScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "shop.title")
	assert_eq(
		screen.get_node("Body/Center/VBox/IncomeLabel").text,
		tr("shop.status") % [1, 100, 100]
	)
	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


func test_trading_post_contains_the_camp_nav() -> void:
	var screen: Control = TradingPostScene.instantiate()
	add_child_autofree(screen)

	assert_not_null(screen.get_node_or_null("Body/CampNav"))


func test_back_button_returns_to_trade() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/trading_post.gd")
	assert_string_contains(source, "GameManager.go_to_trade()")


func test_upgrade_button_is_disabled_below_the_upgrade_cost_and_enabled_at_it() -> void:
	var screen: Control = TradingPostScene.instantiate()
	add_child_autofree(screen)
	var upgrade_button: Button = screen.get_node("Body/Center/VBox/UpgradeButton")

	assert_true(upgrade_button.visible)
	assert_true(upgrade_button.disabled, "Level 1 with no gold cannot afford the upgrade")
	assert_eq(upgrade_button.text, tr("shop.upgrade") % [2, GameSession.SHOP_UPGRADE_COST])

	GameSession.gold = GameSession.SHOP_UPGRADE_COST
	screen.refresh()

	assert_false(upgrade_button.disabled, "150 gold is exactly enough to afford the upgrade")


## Guards the Critical finding from the Step 3 review: shop_level could
## previously only ever be advanced from a test, never from any UI, so
## Tier 2/3 income and the Tier-3 healing potion purchase (stores.gd) were
## permanently unreachable by a real player. Mirrors guild_hall.gd's
## pressing-upgrade tests.
func test_pressing_upgrade_raises_the_shop_level_and_deducts_gold() -> void:
	GameSession.gold = GameSession.SHOP_UPGRADE_COST
	var screen: Control = TradingPostScene.instantiate()
	add_child_autofree(screen)
	var upgrade_button: Button = screen.get_node("Body/Center/VBox/UpgradeButton")

	upgrade_button.emit_signal("pressed")

	assert_eq(GameSession.shop_level, 2)
	assert_eq(GameSession.gold, 0)
	assert_true(screen.get_node("Body/Center/VBox/UpgradeButton").visible, "Level 2 still has a level 3 upgrade to offer")
	assert_false(screen.get_node("Body/Center/VBox/MaxLevelLabel").visible)
	assert_eq(upgrade_button.text, tr("shop.upgrade") % [3, GameSession.SHOP_LEVEL_3_UPGRADE_COST])


func test_pressing_upgrade_at_level_two_reaches_the_max_level_state() -> void:
	GameSession.gold = GameSession.SHOP_UPGRADE_COST
	var screen: Control = TradingPostScene.instantiate()
	add_child_autofree(screen)
	screen.get_node("Body/Center/VBox/UpgradeButton").emit_signal("pressed")
	GameSession.gold = GameSession.SHOP_LEVEL_3_UPGRADE_COST
	screen.refresh()

	screen.get_node("Body/Center/VBox/UpgradeButton").emit_signal("pressed")

	assert_eq(GameSession.shop_level, 3)
	assert_eq(GameSession.gold, 0)
	assert_false(screen.get_node("Body/Center/VBox/UpgradeButton").visible, "Max level has no further upgrade to offer")
	assert_true(screen.get_node("Body/Center/VBox/MaxLevelLabel").visible)


func test_buy_table_lists_only_level_one_iron_weapons() -> void:
	var screen: Control = TradingPostScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/BuyTable/Tree")

	assert_eq(
		UiTestHelpers.tree_row_values(tree, 0).size(),
		GameSession.get_shop_catalogue_item_ids().size()
	)


func test_every_weapon_and_armor_name_in_the_buy_table_is_distinct() -> void:
	var screen: Control = TradingPostScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/BuyTable/Tree")

	var names: Array = UiTestHelpers.tree_row_values(tree, 0)
	var unique_names := {}
	for name in names:
		unique_names[name] = true

	assert_eq(
		unique_names.size(), names.size(),
		"every Shop catalog name must be distinct, e.g. Iron Dagger vs. Steel Dagger, not two rows both reading 'Dagger'"
	)


func test_type_column_uses_trading_posts_own_translation_keys() -> void:
	var screen: Control = TradingPostScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/BuyTable/Tree")

	var row_values := UiTestHelpers.tree_row_values(tree, 1)
	assert_true(row_values.has(tr("shop.type.weapon")))
	assert_false(row_values.has(tr("shop.type.armor")))


func test_selecting_a_row_shows_its_detail_and_the_buy_button() -> void:
	var screen: Control = TradingPostScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/BuyTable/Tree")
	tree.get_root().get_first_child().select(0)

	tree.emit_signal("item_selected")

	assert_true(screen.get_node("Body/Center/VBox/BuyButton").visible)
	assert_true(screen.get_node("Body/Center/VBox/SelectedItemLabel").visible)


func test_buy_button_is_disabled_when_unaffordable_and_enabled_once_affordable() -> void:
	var screen: Control = TradingPostScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/BuyTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")

	assert_true(screen.get_node("Body/Center/VBox/BuyButton").disabled)

	GameSession.gold = 1000
	screen.refresh()
	screen._on_row_selected(screen.selected_item_id)

	assert_false(screen.get_node("Body/Center/VBox/BuyButton").disabled)


func test_pressing_buy_purchases_the_selected_item_and_refreshes() -> void:
	GameSession.gold = 1000
	var screen: Control = TradingPostScene.instantiate()
	add_child_autofree(screen)
	screen.selected_item_id = "dagger_iron"
	var buy_button: Button = screen.get_node("Body/Center/VBox/BuyButton")

	buy_button.emit_signal("pressed")

	assert_eq(GameSession.banked_gear.get("dagger_iron", 0), 1)


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var screen: Control = TradingPostScene.instantiate()
	add_child_autofree(screen)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
