extends GutTest

const EncampmentScene := preload("res://scenes/ui/encampment.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


func test_encampment_exposes_units_buildings_trade_and_deploy_party() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Center/VBox/UnitsButton").text, "encampment.units")
	assert_false(screen.get_node("Center/VBox/UnitsButton").disabled)
	assert_eq(screen.get_node("Center/VBox/DeployPartyButton").text, "encampment.deploy_party")


func test_buildings_and_trade_are_present_but_cannot_route_to_unimplemented_systems() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Center/VBox/BuildingsButton").text, "encampment.buildings")
	assert_true(screen.get_node("Center/VBox/BuildingsButton").disabled)
	assert_eq(screen.get_node("Center/VBox/TradeButton").text, "encampment.trade")
	assert_true(screen.get_node("Center/VBox/TradeButton").disabled)


func test_the_old_depart_and_manage_party_controls_are_absent() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_false(screen.has_node("Center/VBox/DepartButton"))
	assert_false(screen.has_node("Center/VBox/ManagePartyButton"))
	assert_false(screen.has_node("Center/VBox/Status"))


func test_deploy_party_is_disabled_until_a_deployable_party_exists() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_true(screen.get_node("Center/VBox/DeployPartyButton").disabled)

	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	screen.refresh()

	assert_false(screen.get_node("Center/VBox/DeployPartyButton").disabled)


func test_deploy_party_becomes_disabled_again_once_no_deployable_party_remains() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	screen.refresh()
	assert_false(screen.get_node("Center/VBox/DeployPartyButton").disabled)

	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	screen.refresh()

	assert_true(screen.get_node("Center/VBox/DeployPartyButton").disabled)


func test_units_button_routes_via_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/encampment.gd")
	assert_string_contains(source, "GameManager.go_to_units()")


func test_deploy_party_button_routes_via_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/encampment.gd")
	assert_string_contains(source, "GameManager.go_to_deploy_party()")


func test_encampment_contains_the_information_panel_and_refreshes_its_gold_total() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")

	GameSession.gold = 25
	screen.refresh()

	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


func test_encampment_never_shows_party_info_since_it_has_no_selection_concept() -> void:
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
