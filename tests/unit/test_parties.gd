extends GutTest

const PartiesScene := preload("res://scenes/ui/parties.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


func test_parties_shows_the_title_and_the_back_action() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Center/VBox/Title").text, "parties.title")
	assert_eq(screen.get_node("Center/VBox/BackButton").text, "ui.back")


func test_back_button_returns_to_the_encampment() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/parties.gd")
	assert_string_contains(source, "GameManager.go_to_encampment()")


func test_an_empty_party_list_shows_the_empty_state_without_errors() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)

	assert_true(screen.get_node("Center/VBox/EmptyLabel").visible)
	assert_eq(screen.get_node("Center/VBox/EmptyLabel").text, "parties.empty")
	assert_eq(screen.get_node("Center/VBox/PartyList").get_child_count(), 0)
	assert_eq(screen.selected_party_id, "")


func test_every_party_renders_as_a_selectable_row() -> void:
	GameSession.create_party()
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)

	assert_false(screen.get_node("Center/VBox/EmptyLabel").visible)
	var row: Button = screen.get_node("Center/VBox/PartyList").get_child(0)
	assert_eq(row.text, "Party 1")


func test_selecting_a_party_row_stores_the_id_locally_and_refreshes_the_panel() -> void:
	GameSession.create_party()
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")
	var row: Button = screen.get_node("Center/VBox/PartyList").get_child(0)

	row.emit_signal("pressed")

	assert_eq(screen.selected_party_id, GameSession.FIRST_PARTY_ID)
	assert_true(panel.get_node("Content/PartyName").visible)
	assert_eq(panel.get_node("Content/PartyName").text, tr("information.party") % "Party 1")
	assert_eq(panel.get_node("Content/PartyMembers").text, tr("information.members") % 0)
	assert_true(panel.get_node("Content/PartyViewButton").visible)


func test_the_panels_view_button_asks_game_manager_to_open_party_details() -> void:
	GameSession.create_party()
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")
	screen.get_node("Center/VBox/PartyList").get_child(0).emit_signal("pressed")

	panel.get_node("Content/PartyViewButton").emit_signal("pressed")

	assert_eq(
		GameManager.route_context_id,
		GameSession.FIRST_PARTY_ID,
		"Pressing View must ask GameManager to route to that party's details"
	)


func test_a_refresh_that_invalidates_the_selection_clears_it_and_falls_back_to_the_empty_state() -> void:
	GameSession.create_party()
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")
	screen.get_node("Center/VBox/PartyList").get_child(0).emit_signal("pressed")
	assert_eq(screen.selected_party_id, GameSession.FIRST_PARTY_ID)

	GameSession.reset()
	screen.refresh()

	assert_eq(screen.selected_party_id, "")
	assert_false(panel.get_node("Content/PartyName").visible)
	assert_true(screen.get_node("Center/VBox/EmptyLabel").visible)


func test_entering_parties_clears_a_stale_route_context_id() -> void:
	GameManager.route_context_id = "stale_id"

	GameManager.go_to_parties()

	assert_eq(GameManager.route_context_id, "")


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
