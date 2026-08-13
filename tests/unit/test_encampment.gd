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

	assert_eq(screen.get_node("Body/Center/VBox/PopulationLabel").text, tr("encampment.population") % 4)
	assert_eq(screen.get_node("Body/Center/VBox/PartiesLabel").text, tr("encampment.parties_count") % 1)
	assert_eq(screen.get_node("Body/Center/VBox/UnitsLabel").text, tr("encampment.units_count") % 4)


func test_units_count_excludes_members_of_a_deployed_party() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/PopulationLabel").text, tr("encampment.population") % 4)
	assert_eq(
		screen.get_node("Body/Center/VBox/UnitsLabel").text, tr("encampment.units_count") % 3,
		"One of the four adventurers is out with a deployed party"
	)


func test_refresh_updates_the_counts() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	assert_eq(screen.get_node("Body/Center/VBox/PartiesLabel").text, tr("encampment.parties_count") % 0)

	GameSession.create_party()
	screen.refresh()

	assert_eq(screen.get_node("Body/Center/VBox/PartiesLabel").text, tr("encampment.parties_count") % 1)


func test_first_party_dialog_dismisses_only_for_this_scene_visit() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	var dialog: Control = screen.get_node("FirstPartyDialog")
	assert_true(dialog.visible)
	dialog.get_node("Content/Buttons/DismissButton").emit_signal("pressed")
	assert_false(dialog.visible)
	screen.refresh()
	assert_false(dialog.visible)
	var returned: Control = EncampmentScene.instantiate()
	add_child_autofree(returned)
	assert_true(returned.get_node("FirstPartyDialog").visible)


func test_first_party_dialog_uses_the_exact_prompt_and_create_routes_to_parties() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	assert_eq(screen.get_node("FirstPartyDialog/Content/Title").text, tr("encampment.first_party.title"))
	assert_eq(screen.get_node("FirstPartyDialog/Content/Message").text, tr("encampment.first_party.message"))
	assert_eq(screen.get_node("FirstPartyDialog/Content/Buttons/CreateButton").text, tr("encampment.first_party.create"))
	assert_eq(screen.get_node("FirstPartyDialog/Content/Buttons/DismissButton").text, tr("encampment.first_party.dismiss"))
	screen.get_node("FirstPartyDialog/Content/Buttons/CreateButton").emit_signal("pressed")
	assert_eq(GameManager.route_context_id, "")
	assert_true(GameManager.create_party_on_open, "First party dialog create button must ask go_to_parties to create immediately")



func test_encampment_contains_the_information_panel_and_refreshes_its_gold_total() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("%InformationPanel")

	GameSession.gold = 25
	screen.refresh()

	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


func test_encampment_never_shows_party_info_since_it_has_no_selection_concept() -> void:
	GameSession.create_party()
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("%InformationPanel")

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
