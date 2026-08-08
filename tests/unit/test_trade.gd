extends GutTest

const TradeScene := preload("res://scenes/ui/trade.tscn")
const UiTestHelpers := preload("res://tests/unit/ui_test_helpers.gd")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


func test_trade_shows_the_title_and_the_back_action() -> void:
	var screen: Control = TradeScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "trade.title")
	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


func test_trade_contains_the_camp_nav() -> void:
	var screen: Control = TradeScene.instantiate()
	add_child_autofree(screen)

	assert_not_null(screen.get_node_or_null("Body/CampNav"))


func test_back_button_returns_to_the_encampment() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/trade.gd")
	assert_string_contains(source, "GameManager.go_to_encampment()")


func test_trade_table_shows_only_stores_before_a_trading_post_is_purchased() -> void:
	var screen: Control = TradeScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/TradeTable/Tree")

	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Stores"])


func test_trade_table_also_shows_trading_post_once_purchased() -> void:
	GameSession.gold = GameSession.TRADING_POST_PURCHASE_COST
	GameSession.purchase_trading_post()
	var screen: Control = TradeScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/TradeTable/Tree")

	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Stores", "Trading Post"])


func test_activating_the_stores_row_routes_via_game_manager() -> void:
	var screen: Control = TradeScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/TradeTable/Tree")
	tree.get_root().get_first_child().select(0)

	tree.emit_signal("item_activated")

	var source := FileAccess.get_file_as_string("res://scripts/ui/trade.gd")
	assert_string_contains(source, "GameManager.go_to_stores()")


func test_purchase_button_is_disabled_below_the_cost_and_enabled_at_it() -> void:
	var screen: Control = TradeScene.instantiate()
	add_child_autofree(screen)
	var purchase_button: Button = screen.get_node("Body/Center/VBox/PurchaseTradingPostButton")

	assert_true(purchase_button.visible)
	assert_true(purchase_button.disabled, "No gold cannot afford the Trading Post")
	assert_eq(purchase_button.text, tr("trade.purchase_trading_post") % GameSession.TRADING_POST_PURCHASE_COST)

	GameSession.gold = GameSession.TRADING_POST_PURCHASE_COST
	screen.refresh()

	assert_false(purchase_button.disabled)


func test_pressing_purchase_buys_the_trading_post_and_hides_the_button() -> void:
	GameSession.gold = GameSession.TRADING_POST_PURCHASE_COST
	var screen: Control = TradeScene.instantiate()
	add_child_autofree(screen)
	var purchase_button: Button = screen.get_node("Body/Center/VBox/PurchaseTradingPostButton")

	purchase_button.emit_signal("pressed")

	assert_true(GameSession.has_trading_post)
	assert_false(screen.get_node("Body/Center/VBox/PurchaseTradingPostButton").visible)


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var screen: Control = TradeScene.instantiate()
	add_child_autofree(screen)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
