extends GutTest

const AddMemberScene := preload("res://scenes/ui/add_member.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.route_context_id = ""


func _open_add_member(party_id: String) -> Control:
	GameManager.route_context_id = party_id
	var screen: Control = AddMemberScene.instantiate()
	add_child_autofree(screen)
	return screen


func _tree_row_values(tree: Tree, column: int) -> Array[String]:
	var values: Array[String] = []
	var item := tree.get_root().get_first_child()
	while item != null:
		values.append(item.get_text(column))
		item = item.get_next()
	return values


func test_add_member_shows_the_title_and_the_back_action() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)

	assert_eq(screen.get_node("Center/VBox/Title").text, "add_member.title")
	assert_eq(screen.get_node("Center/VBox/BackButton").text, "ui.back")


func test_reads_the_party_id_from_route_context() -> void:
	GameSession.create_party()

	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)

	assert_eq(screen.party_id, GameSession.FIRST_PARTY_ID)


func test_no_available_adventurer_shows_the_empty_state_without_errors() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)

	assert_true(screen.get_node("Center/VBox/EmptyLabel").visible)
	assert_eq(screen.get_node("Center/VBox/EmptyLabel").text, "add_member.empty")
	var tree: Tree = screen.get_node("Center/VBox/AdventurerTable/Tree")
	assert_eq(_tree_row_values(tree, 0), [] as Array[String])


## Column titles are resolved via tr() (see add_member.gd), but the actual
## English copy is added later in the localization milestone; until then
## tr() falls back to returning the key itself, which is what these columns
## are documented by (Name/Class/Level — see the migration brief).
func test_add_member_table_uses_the_documented_columns() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Center/VBox/AdventurerTable/Tree")

	assert_eq(tree.columns, 3)
	assert_eq(tree.get_column_title(0), "add_member.column.name")
	assert_eq(tree.get_column_title(1), "add_member.column.class")
	assert_eq(tree.get_column_title(2), "add_member.column.level")


func test_lists_exactly_the_available_adventurers() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Center/VBox/AdventurerTable/Tree")

	assert_false(screen.get_node("Center/VBox/EmptyLabel").visible)
	assert_eq(_tree_row_values(tree, 0), ["Warrior"])
	assert_eq(_tree_row_values(tree, 1), ["warrior"])
	assert_eq(_tree_row_values(tree, 2), ["1"])


## Selection alone must never assign — only activating a row (see
## test_activating_a_row_assigns_...) does that.
func test_selecting_a_row_stores_the_id_locally_and_shows_its_summary_in_the_panel() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var panel: Control = screen.get_node("InformationPanel")
	var tree: Tree = screen.get_node("Center/VBox/AdventurerTable/Tree")
	var item := tree.get_root().get_first_child()

	item.select(0)
	tree.emit_signal("item_selected")

	assert_eq(screen.selected_adventurer_id, GameSession.WARRIOR_ID)
	assert_true(panel.get_node("Content/AdventurerName").visible)
	assert_eq(panel.get_node("Content/AdventurerName").text, "Warrior")
	assert_true(panel.get_node("Content/AdventurerViewButton").visible)
	assert_eq(
		GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids,
		[] as Array[String],
		"Selecting a row must not assign it"
	)


func test_the_panels_view_button_asks_game_manager_to_open_unit_details() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var panel: Control = screen.get_node("InformationPanel")
	var tree: Tree = screen.get_node("Center/VBox/AdventurerTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")

	panel.get_node("Content/AdventurerViewButton").emit_signal("pressed")

	assert_eq(
		GameManager.route_context_id,
		GameSession.WARRIOR_ID,
		"Pressing View must ask GameManager to route to that exact unit's details"
	)


func test_activating_a_row_assigns_that_exact_adventurer_to_this_party() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Center/VBox/AdventurerTable/Tree")
	tree.get_root().get_first_child().select(0)

	tree.emit_signal("item_activated")

	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [GameSession.WARRIOR_ID])


func test_activating_a_row_returns_to_that_partys_details() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Center/VBox/AdventurerTable/Tree")
	tree.get_root().get_first_child().select(0)

	tree.emit_signal("item_activated")

	assert_eq(GameManager.route_context_id, GameSession.FIRST_PARTY_ID)


func test_a_stale_row_fails_safely_and_refreshes_the_list_in_place() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Center/VBox/AdventurerTable/Tree")
	tree.get_root().get_first_child().select(0)
	# The adventurer gets assigned elsewhere out from under the still-displayed row.
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)

	tree.emit_signal("item_activated")

	assert_true(screen.get_node("Center/VBox/EmptyLabel").visible)
	assert_eq(_tree_row_values(tree, 0), [] as Array[String])


func test_back_button_returns_to_party_details_without_mutating_the_party() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)

	screen.get_node("Center/VBox/BackButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, GameSession.FIRST_PARTY_ID)
	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [] as Array[String])


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
