extends GutTest

const StoresScene := preload("res://scenes/ui/stores.tscn")
const UiTestHelpers := preload("res://tests/unit/ui_test_helpers.gd")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


func test_stores_shows_the_title_and_the_back_action() -> void:
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "stores.title")
	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


func test_stores_contains_the_camp_nav() -> void:
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)

	assert_not_null(screen.get_node_or_null("Body/CampNav"))


func test_back_button_returns_to_trade() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/stores.gd")
	assert_string_contains(source, "GameManager.go_to_trade()")


func test_empty_label_shows_when_nothing_is_banked() -> void:
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)

	assert_true(screen.get_node("Body/Center/VBox/EmptyLabel").visible)


func test_table_shows_a_gear_row_and_a_mana_crystal_row() -> void:
	GameSession.banked_gear = {"shortsword_iron": 3}
	GameSession.mana_crystals = {1: 2}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/StoresTable/Tree")

	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Iron Shortsword", "Mana Crystal (Tier 1)"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 1), ["Weapon", "Mana Crystal"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 2), ["3", "2"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 3), ["10", "5"])
	assert_false(screen.get_node("Body/Center/VBox/EmptyLabel").visible)


func test_selecting_a_gear_row_shows_its_detail_and_both_actions() -> void:
	GameSession.banked_gear = {"shortsword_iron": 3}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/StoresTable/Tree")
	tree.get_root().get_first_child().select(0)

	tree.emit_signal("item_selected")

	assert_eq(
		screen.get_node("Body/Center/VBox/SelectedItemLabel").text,
		tr("stores.selected") % ["Iron Shortsword", 3, 10]
	)
	assert_true(screen.get_node("Body/Center/VBox/SellButton").visible)
	assert_true(screen.get_node("Body/Center/VBox/AssignButton").visible)


func test_selecting_a_mana_crystal_row_hides_the_assign_action() -> void:
	GameSession.mana_crystals = {1: 2}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/StoresTable/Tree")
	tree.get_root().get_first_child().select(0)

	tree.emit_signal("item_selected")

	assert_false(screen.get_node("Body/Center/VBox/AssignButton").visible)


func test_sell_button_is_disabled_without_a_trading_post_and_enabled_with_one() -> void:
	GameSession.banked_gear = {"shortsword_iron": 1}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/StoresTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")

	assert_true(screen.get_node("Body/Center/VBox/SellButton").disabled)

	GameSession.has_trading_post = true
	screen.refresh()

	assert_false(screen.get_node("Body/Center/VBox/SellButton").disabled)


func test_pressing_sell_sells_one_unit_and_refreshes() -> void:
	GameSession.has_trading_post = true
	GameSession.banked_gear = {"shortsword_iron": 2}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/StoresTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")
	var sell_button: Button = screen.get_node("Body/Center/VBox/SellButton")

	sell_button.emit_signal("pressed")

	assert_eq(GameSession.banked_gear.shortsword_iron, 1)
	assert_eq(GameSession.gold, 10)


func test_pressing_assign_routes_via_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/stores.gd")
	assert_string_contains(source, "GameManager.go_to_assign_equipment(selected_item_id)")


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
