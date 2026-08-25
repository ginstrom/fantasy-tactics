extends GutTest

const RosterScene := preload("res://scenes/ui/roster.tscn")
const UiTestHelpers := preload("res://tests/unit/ui_test_helpers.gd")


func before_each() -> void:
	GameSession.reset()
	GameManager.route_context_id = ""
	GameManager.unit_details_origin = ""


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.route_context_id = ""
	GameManager.unit_details_origin = ""


func test_roster_shows_the_title_and_the_back_action() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "roster.title")
	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


func test_shows_the_permanent_player_and_gold_rows() -> void:
	GameSession.player_name = "Aria"
	GameSession.gold = 25
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("%InformationPanel")

	assert_true(panel.get_node("Content/PlayerName").visible)
	assert_eq(panel.get_node("Content/PlayerName").text, tr("information.player") % "Aria")
	assert_true(panel.get_node("Content/Gold").visible)
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


func test_roster_table_uses_the_documented_columns() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/RosterTable/Tree")

	assert_eq(tree.columns, 5)
	assert_eq(tree.get_column_title(0), "Name")
	assert_eq(tree.get_column_title(1), "Class")
	assert_eq(tree.get_column_title(2), "Level")
	assert_eq(tree.get_column_title(3), "Status")
	assert_eq(tree.get_column_title(4), "Party")


func test_an_unassigned_warrior_shows_unassigned_in_the_party_column() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/RosterTable/Tree")

	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Warrior", "Warrior 2", "Warrior 3", "Warrior 4"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 1), ["Warrior", "Warrior", "Warrior", "Warrior"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 2), ["1", "1", "1", "1"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 3), ["Healthy", "Healthy", "Healthy", "Healthy"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 4), ["Unassigned", "Unassigned", "Unassigned", "Unassigned"])


func test_an_assigned_warrior_shows_its_partys_name_in_the_party_column() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/RosterTable/Tree")

	assert_eq(UiTestHelpers.tree_row_values(tree, 4), ["Party 1", "Unassigned", "Unassigned", "Unassigned"])


func test_selecting_a_row_stores_the_id_locally_and_refreshes_the_panel() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/RosterTable/Tree")
	var item := tree.get_root().get_first_child()

	item.select(0)
	tree.emit_signal("item_selected")

	assert_eq(screen.selected_adventurer_id, GameSession.WARRIOR_ID)
	assert_true(panel.get_node("Content/AdventurerName").visible)
	assert_eq(panel.get_node("Content/AdventurerName").text, "Warrior")
	assert_true(panel.get_node("Content/AdventurerViewButton").visible)


func test_the_panels_view_button_opens_card_navigator() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/RosterTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")

	panel.get_node("Content/AdventurerViewButton").emit_signal("pressed")

	var navigator: CardNavigator = screen.get_node("CardNavigator")
	assert_true(navigator.visible)
	assert_eq(navigator.get_current_id(), GameSession.WARRIOR_ID)


func test_activating_a_row_opens_card_navigator() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/RosterTable/Tree")
	tree.get_root().get_first_child().select(0)

	tree.emit_signal("item_activated")

	var navigator: CardNavigator = screen.get_node("CardNavigator")
	assert_true(navigator.visible)
	assert_eq(navigator.get_current_id(), GameSession.WARRIOR_ID)


func test_roster_card_navigator_cycles_in_displayed_order_and_wraps() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/RosterTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_activated")

	var navigator: CardNavigator = screen.get_node("CardNavigator")
	var next_btn: Button = navigator.get_node("%NextButton")
	var prev_btn: Button = navigator.get_node("%PrevButton")

	assert_eq(navigator.get_current_id(), GameSession.WARRIOR_ID)
	next_btn.emit_signal("pressed")
	assert_eq(navigator.get_current_id(), GameSession.adventurers[1].id)
	next_btn.emit_signal("pressed")
	assert_eq(navigator.get_current_id(), GameSession.adventurers[2].id)
	next_btn.emit_signal("pressed")
	assert_eq(navigator.get_current_id(), GameSession.adventurers[3].id)
	next_btn.emit_signal("pressed")
	assert_eq(navigator.get_current_id(), GameSession.WARRIOR_ID, "Must wrap forward to first entry")

	prev_btn.emit_signal("pressed")
	assert_eq(navigator.get_current_id(), GameSession.adventurers[3].id, "Must wrap backward to last entry")


func test_roster_closing_card_navigator_restores_selection_and_table_focus() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/RosterTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_activated")

	var navigator: CardNavigator = screen.get_node("CardNavigator")
	navigator.next()
	navigator.next()
	var third_id: String = GameSession.adventurers[2].id
	assert_eq(navigator.get_current_id(), third_id)

	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true
	navigator._unhandled_input(escape_event)

	assert_false(navigator.visible)
	assert_eq(screen.selected_adventurer_id, third_id)
	var selected_ids: Array = screen.get_node("Body/Center/VBox/RosterTable").get_selected_row_ids()
	assert_eq(selected_ids, [third_id])


func test_an_empty_roster_shows_the_empty_state_without_errors() -> void:
	GameSession.adventurers.clear()
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)

	assert_true(screen.get_node("Body/Center/VBox/EmptyLabel").visible)
	assert_eq(screen.get_node("Body/Center/VBox/EmptyLabel").text, "roster.empty")


func test_a_refresh_that_invalidates_the_selection_clears_it() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/RosterTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")
	assert_eq(screen.selected_adventurer_id, GameSession.WARRIOR_ID)

	GameSession.reset()
	GameSession.adventurers.clear()
	screen.refresh()

	assert_eq(screen.selected_adventurer_id, "")
	assert_false(panel.get_node("Content/AdventurerName").visible)
	assert_true(screen.get_node("Body/Center/VBox/EmptyLabel").visible)


func test_refresh_reflects_a_new_assignment_made_elsewhere() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/RosterTable/Tree")
	assert_eq(UiTestHelpers.tree_row_values(tree, 4), ["Unassigned", "Unassigned", "Unassigned", "Unassigned"])

	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	screen.refresh()

	assert_eq(UiTestHelpers.tree_row_values(tree, 4), ["Party 1", "Unassigned", "Unassigned", "Unassigned"])


func test_back_button_returns_to_units() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/roster.gd")
	assert_string_contains(source, "GameManager.go_to_units()")


func test_escape_marks_input_handled_and_opens_the_game_menu_when_card_navigator_is_closed() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
