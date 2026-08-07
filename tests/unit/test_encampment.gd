extends GutTest

const EncampmentScene := preload("res://scenes/ui/encampment.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


func test_encampment_contains_the_camp_nav() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_not_null(screen.get_node("Body/CampNav"))


func test_the_old_depart_and_manage_party_controls_are_absent() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_false(screen.has_node("Body/Center/VBox/DepartButton"))
	assert_false(screen.has_node("Body/Center/VBox/ManagePartyButton"))
	assert_false(screen.has_node("Body/Center/VBox/Status"))
	assert_false(
		screen.has_node("Body/Center/VBox/UnitsButton"),
		"Encampment's own content no longer has nav buttons -- they live in CampNav"
	)
	assert_false(screen.has_node("Body/Center/VBox/BuildingsButton"))
	assert_false(screen.has_node("Body/Center/VBox/TradeButton"))
	assert_false(screen.has_node("Body/Center/VBox/DeployPartyButton"))


func test_encampment_shows_population_parties_and_units_counts() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/PopulationLabel").text, tr("encampment.population") % 1)
	assert_eq(screen.get_node("Body/Center/VBox/PartiesLabel").text, tr("encampment.parties_count") % 1)
	assert_eq(screen.get_node("Body/Center/VBox/UnitsLabel").text, tr("encampment.units_count") % 1)


func test_units_count_excludes_members_of_a_deployed_party() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/PopulationLabel").text, tr("encampment.population") % 1)
	assert_eq(
		screen.get_node("Body/Center/VBox/UnitsLabel").text, tr("encampment.units_count") % 0,
		"The only adventurer is out with a deployed party"
	)


func test_refresh_updates_the_counts() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	assert_eq(screen.get_node("Body/Center/VBox/PartiesLabel").text, tr("encampment.parties_count") % 0)

	GameSession.create_party()
	screen.refresh()

	assert_eq(screen.get_node("Body/Center/VBox/PartiesLabel").text, tr("encampment.parties_count") % 1)


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
