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

	assert_true(screen.get_node("Body/Center/VBox/LootTable/EmptyLabel").visible)


func test_table_shows_a_gear_row_and_a_mana_crystal_row() -> void:
	GameSession.banked_gear = {"shortsword_iron": 3}
	GameSession.mana_crystals = {1: 2}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/LootTable/Content/Table/Tree")

	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Iron Shortsword", "Mana Crystal (Tier 1)"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 1), ["Weapon", "Mana Crystal"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 2), ["3", "2"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 3), ["10", "5"])
	assert_false(screen.get_node("Body/Center/VBox/LootTable/EmptyLabel").visible)


func _select_first_stores_row(screen: Control) -> void:
	var tree: Tree = screen.get_node("Body/Center/VBox/LootTable/Content/Table/Tree")
	var item := tree.get_root().get_first_child()
	item.select(0)
	tree.emit_signal("item_selected")


func _direct_action_button(screen: Control, button_name: String) -> Button:
	return screen.get_node("Body/Center/VBox/LootTable/Content/DirectActionBar/%s" % button_name)


func test_direct_action_bar_disables_every_action_without_a_selection() -> void:
	GameSession.banked_gear = {"shortsword_iron": 1}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)

	assert_true(_direct_action_button(screen, "ViewButton").disabled)
	assert_true(_direct_action_button(screen, "SellButton").disabled)
	assert_true(_direct_action_button(screen, "EquipButton").disabled)


func test_direct_action_bar_enables_every_action_for_affordable_gear() -> void:
	GameSession.banked_gear = {"shortsword_iron": 1}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	_select_first_stores_row(screen)

	assert_false(_direct_action_button(screen, "ViewButton").disabled)
	assert_false(_direct_action_button(screen, "SellButton").disabled)
	assert_false(_direct_action_button(screen, "EquipButton").disabled)


func test_direct_action_bar_disables_equip_for_mana_crystals() -> void:
	GameSession.mana_crystals = {1: 1}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	_select_first_stores_row(screen)

	assert_false(_direct_action_button(screen, "ViewButton").disabled)
	assert_false(_direct_action_button(screen, "SellButton").disabled)
	assert_true(_direct_action_button(screen, "EquipButton").disabled)


func test_direct_action_bar_disables_sell_when_the_shop_cannot_afford_the_item() -> void:
	GameSession.shop_gold = 9
	GameSession.banked_gear = {"shortsword_iron": 1}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	_select_first_stores_row(screen)

	assert_true(_direct_action_button(screen, "SellButton").disabled)


func test_refreshing_away_the_selected_row_disables_every_direct_action() -> void:
	GameSession.banked_gear = {"shortsword_iron": 1}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	_select_first_stores_row(screen)

	GameSession.banked_gear = {}
	screen.refresh()

	assert_true(_direct_action_button(screen, "ViewButton").disabled)
	assert_true(_direct_action_button(screen, "SellButton").disabled)
	assert_true(_direct_action_button(screen, "EquipButton").disabled)


func test_selecting_a_row_and_clicking_view_opens_the_detail_panel() -> void:
	GameSession.banked_gear = {"shortsword_iron": 1}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	_select_first_stores_row(screen)

	_direct_action_button(screen, "ViewButton").emit_signal("pressed")

	var detail_panel: Control = screen.get_node("Body/Center/VBox/LootTable/LootDetailPanel")
	assert_true(detail_panel.visible)
	assert_eq(detail_panel.get_node("Content/NameLabel").text, "Iron Shortsword")


func test_direct_equip_emits_the_selected_item_id() -> void:
	GameSession.banked_gear = {"shortsword_iron": 1}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	_select_first_stores_row(screen)
	var loot_table: LootTable = screen.get_node("Body/Center/VBox/LootTable")
	watch_signals(loot_table)

	_direct_action_button(screen, "EquipButton").emit_signal("pressed")

	assert_signal_emitted_with_parameters(loot_table, "equip_requested", ["shortsword_iron"])


func test_detail_panel_hides_direct_actions_for_mana_crystal_rows() -> void:
	GameSession.mana_crystals = {1: 2}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	_select_first_stores_row(screen)

	_direct_action_button(screen, "ViewButton").emit_signal("pressed")

	assert_false(
		screen.get_node("Body/Center/VBox/LootTable/LootDetailPanel/Content/ButtonRow/EquipButton").visible
	)


func test_direct_sell_of_one_item_updates_gold_shop_cash_and_stores_rows() -> void:
	GameSession.has_trading_post = true
	GameSession.banked_gear = {"shortsword_iron": 1}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	_select_first_stores_row(screen)

	_direct_action_button(screen, "SellButton").emit_signal("pressed")

	assert_eq(GameSession.banked_gear.shortsword_iron, 0)
	assert_eq(GameSession.gold, 10)
	assert_eq(GameSession.shop_gold, 90)
	assert_true(screen.get_node("Body/Center/VBox/LootTable/EmptyLabel").visible)


func test_direct_sale_of_multiple_items_waits_for_quantity_confirmation() -> void:
	GameSession.banked_gear = {"shortsword_iron": 2}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	_select_first_stores_row(screen)

	_direct_action_button(screen, "SellButton").emit_signal("pressed")

	assert_eq(GameSession.banked_gear.shortsword_iron, 2)
	assert_true(screen.get_node("Body/Center/VBox/LootTable/SellQuantityDialog").visible)


func test_underfunded_direct_sale_leaves_state_and_rows_unchanged() -> void:
	GameSession.shop_gold = 9
	GameSession.banked_gear = {"shortsword_iron": 1}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	_select_first_stores_row(screen)
	var loot_table: LootTable = screen.get_node("Body/Center/VBox/LootTable")
	watch_signals(loot_table)

	loot_table._handle_sell("shortsword_iron")

	assert_eq(GameSession.banked_gear.shortsword_iron, 1)
	assert_eq(GameSession.gold, 0)
	assert_eq(GameSession.shop_gold, 9)
	assert_signal_not_emitted(loot_table, "sold")


func test_pressing_equip_routes_via_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/stores.gd")
	assert_string_contains(source, "GameManager.go_to_assign_equipment(item_id)")


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
