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
	assert_eq(screen.get_node("Center/VBox/AdventurerList").get_child_count(), 0)


func test_lists_exactly_the_available_adventurers() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)

	assert_false(screen.get_node("Center/VBox/EmptyLabel").visible)
	assert_eq(screen.get_node("Center/VBox/AdventurerList").get_child_count(), 1)
	var row: Button = screen.get_node("Center/VBox/AdventurerList").get_child(0)
	assert_eq(row.text, tr("add_member.member_row") % ["Warrior", "warrior", 1])


func test_selecting_a_row_assigns_that_exact_adventurer_to_this_party() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var row: Button = screen.get_node("Center/VBox/AdventurerList").get_child(0)

	row.emit_signal("pressed")

	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [GameSession.WARRIOR_ID])


func test_selecting_a_row_returns_to_that_partys_details() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var row: Button = screen.get_node("Center/VBox/AdventurerList").get_child(0)

	row.emit_signal("pressed")

	assert_eq(GameManager.route_context_id, GameSession.FIRST_PARTY_ID)


func test_a_stale_row_fails_safely_and_refreshes_the_list_in_place() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var row: Button = screen.get_node("Center/VBox/AdventurerList").get_child(0)
	# The adventurer gets assigned elsewhere out from under the still-displayed row.
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)

	row.emit_signal("pressed")

	assert_true(screen.get_node("Center/VBox/EmptyLabel").visible)
	assert_eq(screen.get_node("Center/VBox/AdventurerList").get_child_count(), 0)


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
