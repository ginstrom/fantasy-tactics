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

	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "trading_post.title")
	assert_eq(
		screen.get_node("Body/Center/VBox/IncomeLabel").text,
		tr("trading_post.income") % GameSession.TRADING_POST_INCOME_PER_TURN
	)
	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


func test_trading_post_contains_the_camp_nav() -> void:
	var screen: Control = TradingPostScene.instantiate()
	add_child_autofree(screen)

	assert_not_null(screen.get_node_or_null("Body/CampNav"))


func test_back_button_returns_to_trade() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/trading_post.gd")
	assert_string_contains(source, "GameManager.go_to_trade()")


func test_buy_table_lists_every_weapon_and_armor() -> void:
	var screen: Control = TradingPostScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/BuyTable/Tree")

	assert_eq(
		UiTestHelpers.tree_row_values(tree, 0).size(),
		GameSession.WEAPONS.size() + GameSession.ARMORS.size()
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
		"every weapon/armor name in the Trading Post catalog must be distinct, e.g. Iron Dagger vs. Steel Dagger, not two rows both reading 'Dagger'"
	)


func test_type_column_uses_trading_posts_own_translation_keys() -> void:
	var screen: Control = TradingPostScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/BuyTable/Tree")

	var row_values := UiTestHelpers.tree_row_values(tree, 1)
	assert_true(row_values.has(tr("trading_post.type.weapon")))
	assert_true(row_values.has(tr("trading_post.type.armor")))


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
	GameSession.has_trading_post = true
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
