extends GutTest

const PartyManagerScene := preload("res://scenes/ui/party_manager.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


func test_new_party_manager_shows_unassigned_warrior_and_create_action() -> void:
	var screen: Control = PartyManagerScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Center/VBox/WarriorSummary").text, "party.warrior.summary")
	assert_eq(screen.get_node("Center/VBox/PartyStatus").text, "party.status.unassigned")
	assert_true(screen.get_node("Center/VBox/CreatePartyButton").visible)
	assert_false(screen.get_node("Center/VBox/AddWarriorButton").visible)
	assert_false(screen.get_node("Center/VBox/RemoveWarriorButton").visible)


func test_refresh_shows_add_after_party_creation() -> void:
	GameSession.create_party()
	var screen: Control = PartyManagerScene.instantiate()
	add_child_autofree(screen)

	assert_true(screen.get_node("Center/VBox/CreatePartyButton").disabled)
	assert_true(screen.get_node("Center/VBox/AddWarriorButton").visible)
	assert_false(screen.get_node("Center/VBox/RemoveWarriorButton").visible)


func test_refresh_shows_remove_after_assignment() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var screen: Control = PartyManagerScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Center/VBox/PartyStatus").text, "party.status.assigned")
	assert_true(screen.get_node("Center/VBox/RemoveWarriorButton").visible)
	assert_false(screen.get_node("Center/VBox/AddWarriorButton").visible)


func test_buttons_create_assign_and_remove_the_warrior() -> void:
	var screen: Control = PartyManagerScene.instantiate()
	add_child_autofree(screen)

	screen.get_node("Center/VBox/CreatePartyButton").emit_signal("pressed")
	assert_true(screen.get_node("Center/VBox/AddWarriorButton").visible)

	screen.get_node("Center/VBox/AddWarriorButton").emit_signal("pressed")
	assert_true(screen.get_node("Center/VBox/RemoveWarriorButton").visible)

	screen.get_node("Center/VBox/RemoveWarriorButton").emit_signal("pressed")
	assert_true(screen.get_node("Center/VBox/AddWarriorButton").visible)


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var screen: Control = PartyManagerScene.instantiate()
	add_child_autofree(screen)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
