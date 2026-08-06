extends GutTest

const RosterScene := preload("res://scenes/ui/roster.tscn")


func before_each() -> void:
	GameSession.reset()
	GameManager.route_context_id = ""
	GameManager.unit_details_origin = ""


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.route_context_id = ""
	GameManager.unit_details_origin = ""


func _tree_row_values(tree: Tree, column: int) -> Array[String]:
	var values: Array[String] = []
	var item := tree.get_root().get_first_child()
	while item != null:
		values.append(item.get_text(column))
		item = item.get_next()
	return values


func test_roster_shows_the_title_and_the_back_action() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Center/VBox/Title").text, "roster.title")
	assert_eq(screen.get_node("Center/VBox/BackButton").text, "ui.back")


func test_shows_the_permanent_player_and_gold_rows() -> void:
	GameSession.player_name = "Aria"
	GameSession.gold = 25
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")

	assert_true(panel.get_node("Content/PlayerName").visible)
	assert_eq(panel.get_node("Content/PlayerName").text, tr("information.player") % "Aria")
	assert_true(panel.get_node("Content/Gold").visible)
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


## Column titles are resolved via tr() (see roster.gd), but the actual
## English copy is added later in the localization milestone; until then
## tr() falls back to returning the key itself, which is what these columns
## are documented by (Name/Class/Level/Status/Party — see the design doc).
func test_roster_table_uses_the_documented_columns() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Center/VBox/RosterTable/Tree")

	assert_eq(tree.columns, 5)
	assert_eq(tree.get_column_title(0), "roster.column.name")
	assert_eq(tree.get_column_title(1), "roster.column.class")
	assert_eq(tree.get_column_title(2), "roster.column.level")
	assert_eq(tree.get_column_title(3), "roster.column.status")
	assert_eq(tree.get_column_title(4), "roster.column.party")


func test_an_unassigned_warrior_shows_unassigned_in_the_party_column() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Center/VBox/RosterTable/Tree")

	assert_eq(_tree_row_values(tree, 0), ["Warrior"])
	assert_eq(_tree_row_values(tree, 1), ["warrior"])
	assert_eq(_tree_row_values(tree, 2), ["1"])
	assert_eq(_tree_row_values(tree, 3), ["available"])
	assert_eq(_tree_row_values(tree, 4), ["roster.unassigned"])


func test_an_assigned_warrior_shows_its_partys_name_in_the_party_column() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Center/VBox/RosterTable/Tree")

	assert_eq(_tree_row_values(tree, 4), ["Party 1"])


func test_selecting_a_row_stores_the_id_locally_and_refreshes_the_panel() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")
	var tree: Tree = screen.get_node("Center/VBox/RosterTable/Tree")
	var item := tree.get_root().get_first_child()

	item.select(0)
	tree.emit_signal("item_selected")

	assert_eq(screen.selected_adventurer_id, GameSession.WARRIOR_ID)
	assert_true(panel.get_node("Content/AdventurerName").visible)
	assert_eq(panel.get_node("Content/AdventurerName").text, "Warrior")
	assert_true(panel.get_node("Content/AdventurerViewButton").visible)


func test_the_panels_view_button_routes_to_unit_details_via_the_roster_origin() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")
	var tree: Tree = screen.get_node("Center/VBox/RosterTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")

	panel.get_node("Content/AdventurerViewButton").emit_signal("pressed")

	assert_eq(
		GameManager.route_context_id,
		GameSession.WARRIOR_ID,
		"Pressing View must ask GameManager to route to that exact unit's details"
	)
	assert_eq(GameManager.unit_details_origin, "roster")


func test_activating_a_row_routes_to_unit_details_via_the_roster_origin() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Center/VBox/RosterTable/Tree")
	tree.get_root().get_first_child().select(0)

	tree.emit_signal("item_activated")

	assert_eq(GameManager.route_context_id, GameSession.WARRIOR_ID)
	assert_eq(GameManager.unit_details_origin, "roster")


func test_an_empty_roster_shows_the_empty_state_without_errors() -> void:
	GameSession.adventurers.clear()
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)

	assert_true(screen.get_node("Center/VBox/EmptyLabel").visible)
	assert_eq(screen.get_node("Center/VBox/EmptyLabel").text, "roster.empty")


func test_a_refresh_that_invalidates_the_selection_clears_it() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")
	var tree: Tree = screen.get_node("Center/VBox/RosterTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")
	assert_eq(screen.selected_adventurer_id, GameSession.WARRIOR_ID)

	GameSession.reset()
	GameSession.adventurers.clear()
	screen.refresh()

	assert_eq(screen.selected_adventurer_id, "")
	assert_false(panel.get_node("Content/AdventurerName").visible)
	assert_true(screen.get_node("Center/VBox/EmptyLabel").visible)


func test_refresh_reflects_a_new_assignment_made_elsewhere() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Center/VBox/RosterTable/Tree")
	assert_eq(_tree_row_values(tree, 4), ["roster.unassigned"])

	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	screen.refresh()

	assert_eq(_tree_row_values(tree, 4), ["Party 1"])


func test_back_button_returns_to_units() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/roster.gd")
	assert_string_contains(source, "GameManager.go_to_units()")


func test_entering_roster_clears_a_stale_route_context_id() -> void:
	GameManager.route_context_id = "stale_id"
	GameManager.unit_details_origin = GameManager.UNIT_DETAILS_ORIGIN_ROSTER

	GameManager.go_to_roster()

	assert_eq(GameManager.route_context_id, "")
	assert_eq(GameManager.unit_details_origin, "")


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var screen: Control = RosterScene.instantiate()
	add_child_autofree(screen)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
