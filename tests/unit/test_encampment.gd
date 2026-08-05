extends GutTest

const EncampmentScene := preload("res://scenes/ui/encampment.tscn")


func after_each() -> void:
	GameManager.close_game_menu()


func test_encampment_has_a_manage_party_action() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Center/VBox/ManagePartyButton").text, "encampment.manage_party")


func test_encampment_disables_depart_until_party_has_a_member() -> void:
	GameSession.reset()
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_true(screen.get_node("Center/VBox/DepartButton").disabled)
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	screen.refresh()
	assert_false(screen.get_node("Center/VBox/DepartButton").disabled)


func test_encampment_contains_the_information_panel_and_refreshes_its_gold_total() -> void:
	GameSession.reset()
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")

	GameSession.gold = 25
	screen.refresh()

	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


func test_encampment_never_shows_party_info_since_it_has_no_selection_concept() -> void:
	GameSession.reset()
	GameSession.create_party()
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")

	screen.refresh()

	assert_false(panel.get_node("Content/PartyName").visible)
	assert_false(panel.get_node("Content/PartyMembers").visible)
	assert_false(panel.get_node("Content/PartyViewButton").visible)


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
