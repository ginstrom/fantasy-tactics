extends GutTest

const UnitDetailsScene := preload("res://scenes/ui/unit_details.tscn")


func before_each() -> void:
	GameSession.reset()
	GameManager.route_context_id = ""
	GameManager.unit_details_origin = ""
	GameManager.add_member_return_party_id = ""


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.route_context_id = ""
	GameManager.unit_details_origin = ""
	GameManager.add_member_return_party_id = ""


func _open_unit_details(adventurer_id: String) -> Control:
	GameManager.route_context_id = adventurer_id
	GameManager.unit_details_origin = ""
	var screen: Control = UnitDetailsScene.instantiate()
	add_child_autofree(screen)
	return screen


func _open_unit_details_from_roster(adventurer_id: String) -> Control:
	GameManager.route_context_id = adventurer_id
	GameManager.unit_details_origin = GameManager.UNIT_DETAILS_ORIGIN_ROSTER
	var screen: Control = UnitDetailsScene.instantiate()
	add_child_autofree(screen)
	return screen


func _open_unit_details_from_add_member(adventurer_id: String, party_id: String) -> Control:
	GameManager.route_context_id = adventurer_id
	GameManager.unit_details_origin = GameManager.UNIT_DETAILS_ORIGIN_ADD_MEMBER
	GameManager.add_member_return_party_id = party_id
	var screen: Control = UnitDetailsScene.instantiate()
	add_child_autofree(screen)
	return screen


## Extracts a single top-level function's own source (from "func <name>(" up
## to the next top-level "func ", or end of file) so a source-string
## assertion can target that function's branches specifically. A whole-file
## substring search is too weak here: both GameManager.go_to_roster() and
## GameManager.go_to_parties() are called from more than one place in
## unit_details.gd (e.g. go_to_roster() is also the Add-to-Party success
## route), so a plain assert_string_contains(source, ...) against the whole
## file would still pass even if _on_back_pressed()'s two branches were
## swapped.
func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start == -1:
		return ""
	var next_func := source.find("\nfunc ", start + 1)
	return source.substr(start) if next_func == -1 else source.substr(start, next_func - start)


func test_unit_details_shows_the_title_and_the_back_action() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(screen.get_node("Center/VBox/Title").text, "unit_details.title")
	assert_eq(screen.get_node("Center/VBox/BackButton").text, "ui.back")


func test_shows_the_permanent_player_and_gold_rows() -> void:
	GameSession.player_name = "Aria"
	GameSession.gold = 25
	var screen := _open_unit_details(GameSession.WARRIOR_ID)
	var panel: Control = screen.get_node("InformationPanel")

	assert_true(panel.get_node("Content/PlayerName").visible)
	assert_eq(panel.get_node("Content/PlayerName").text, tr("information.player") % "Aria")
	assert_true(panel.get_node("Content/Gold").visible)
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


func test_reads_the_unit_id_from_route_context() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(screen.unit_id, GameSession.WARRIOR_ID)


func test_renders_name_class_level_and_availability_status() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(screen.get_node("Center/VBox/NameLabel").text, "Warrior")
	assert_eq(screen.get_node("Center/VBox/ClassLabel").text, tr("information.class") % "warrior")
	assert_eq(screen.get_node("Center/VBox/LevelLabel").text, tr("information.level") % 1)
	assert_eq(
		screen.get_node("Center/VBox/StatusLabel").text, tr("unit_details.status") % tr("availability.available")
	)


func test_renders_status_for_a_non_available_unit() -> void:
	GameSession.adventurers[0]["availability_status"] = "unavailable"
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(
		screen.get_node("Center/VBox/StatusLabel").text, tr("unit_details.status") % tr("availability.unavailable")
	)


func test_unit_details_uses_the_sessions_availability_query_not_a_private_predicate() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/unit_details.gd")
	assert_false(source.contains("func _is_adventurer_unassigned"))
	assert_string_contains(source, "GameSession.is_adventurer_available")


func test_skills_perks_and_stats_are_only_labelled_tbd_placeholders() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(screen.get_node("Center/VBox/SkillsLabel").text, "unit_details.skills")
	assert_eq(screen.get_node("Center/VBox/PerksLabel").text, "unit_details.perks")
	assert_eq(screen.get_node("Center/VBox/StatsLabel").text, "unit_details.stats")
	assert_true(screen.get_node("Center/VBox/SkillsLabel").visible)
	assert_true(screen.get_node("Center/VBox/PerksLabel").visible)
	assert_true(screen.get_node("Center/VBox/StatsLabel").visible)


func test_an_unknown_unit_id_shows_a_not_found_message_and_hides_detail_rows() -> void:
	var screen := _open_unit_details("no_such_adventurer")

	assert_true(screen.get_node("Center/VBox/NotFoundLabel").visible)
	assert_eq(screen.get_node("Center/VBox/NotFoundLabel").text, "unit_details.not_found")
	assert_false(screen.get_node("Center/VBox/NameLabel").visible)
	assert_false(screen.get_node("Center/VBox/ClassLabel").visible)
	assert_false(screen.get_node("Center/VBox/LevelLabel").visible)
	assert_false(screen.get_node("Center/VBox/StatusLabel").visible)
	assert_false(screen.get_node("Center/VBox/SkillsLabel").visible)
	assert_false(screen.get_node("Center/VBox/PerksLabel").visible)
	assert_false(screen.get_node("Center/VBox/StatsLabel").visible)


func test_an_unknown_unit_id_still_has_a_safe_working_back_button() -> void:
	var screen := _open_unit_details("no_such_adventurer")

	assert_false(screen.get_node("Center/VBox/BackButton").disabled)
	screen.get_node("Center/VBox/BackButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, "")


func test_back_button_returns_to_parties() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/unit_details.gd")

	assert_string_contains(source, "GameManager.go_to_parties()")


func test_back_button_clears_only_the_ui_route_context() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	screen.get_node("Center/VBox/BackButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, "")
	assert_false(GameSession.has_deployed_party(), "Back must never deploy or otherwise mutate the party")
	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [GameSession.WARRIOR_ID])


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)


func test_assignment_section_is_hidden_when_not_opened_via_roster() -> void:
	GameSession.create_party()
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_false(screen.get_node("Center/VBox/PartyPicker").visible)
	assert_false(screen.get_node("Center/VBox/AddToPartyButton").visible)
	assert_false(screen.get_node("Center/VBox/AssignmentExplanationLabel").visible)


func test_roster_origin_shows_an_enabled_picker_and_action_for_an_available_unassigned_unit() -> void:
	GameSession.create_party()
	var screen := _open_unit_details_from_roster(GameSession.WARRIOR_ID)

	var picker: OptionButton = screen.get_node("Center/VBox/PartyPicker")
	var add_button: Button = screen.get_node("Center/VBox/AddToPartyButton")
	assert_true(picker.visible)
	assert_true(add_button.visible)
	assert_false(add_button.disabled)
	assert_false(screen.get_node("Center/VBox/AssignmentExplanationLabel").visible)
	assert_eq(picker.item_count, 1)
	assert_eq(picker.get_item_text(0), "Party 1")
	assert_eq(picker.get_item_metadata(0), GameSession.FIRST_PARTY_ID)


func test_roster_origin_with_no_encamped_party_shows_a_disabled_explained_action() -> void:
	var screen := _open_unit_details_from_roster(GameSession.WARRIOR_ID)

	var picker: OptionButton = screen.get_node("Center/VBox/PartyPicker")
	var add_button: Button = screen.get_node("Center/VBox/AddToPartyButton")
	assert_false(picker.visible)
	assert_true(add_button.visible, "The disabled action itself should still be present, not merely absent")
	assert_true(add_button.disabled)
	assert_true(screen.get_node("Center/VBox/AssignmentExplanationLabel").visible)
	assert_eq(
		screen.get_node("Center/VBox/AssignmentExplanationLabel").text, "unit_details.no_eligible_party"
	)


func test_roster_origin_hides_the_assignment_section_for_an_assigned_unit() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_unit_details_from_roster(GameSession.WARRIOR_ID)

	assert_false(screen.get_node("Center/VBox/PartyPicker").visible)
	assert_false(screen.get_node("Center/VBox/AddToPartyButton").visible)
	assert_false(screen.get_node("Center/VBox/AssignmentExplanationLabel").visible)


func test_roster_origin_hides_the_assignment_section_for_an_unavailable_unit() -> void:
	GameSession.create_party()
	GameSession.adventurers[0]["availability_status"] = "unavailable"
	var screen := _open_unit_details_from_roster(GameSession.WARRIOR_ID)

	assert_false(screen.get_node("Center/VBox/PartyPicker").visible)
	assert_false(screen.get_node("Center/VBox/AddToPartyButton").visible)


func test_pressing_add_to_party_assigns_the_chosen_party_and_routes_to_roster() -> void:
	GameSession.create_party()
	var screen := _open_unit_details_from_roster(GameSession.WARRIOR_ID)
	var add_button: Button = screen.get_node("Center/VBox/AddToPartyButton")

	add_button.emit_signal("pressed")

	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [GameSession.WARRIOR_ID])
	assert_eq(GameManager.route_context_id, "")
	assert_eq(GameManager.unit_details_origin, "")


func test_a_stale_party_selection_fails_safely_and_refreshes_in_place() -> void:
	GameSession.create_party()
	var screen := _open_unit_details_from_roster(GameSession.WARRIOR_ID)
	var add_button: Button = screen.get_node("Center/VBox/AddToPartyButton")
	# The chosen party stops being eligible while the screen is still open.
	GameSession.parties[0].deployed = true

	add_button.emit_signal("pressed")

	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [] as Array[String])
	assert_eq(GameManager.route_context_id, GameSession.WARRIOR_ID, "A stale selection must not navigate away")
	assert_true(
		screen.get_node("Center/VBox/AssignmentExplanationLabel").visible,
		"No encamped party remains, so the disabled explanation should show"
	)
	assert_true(screen.get_node("Center/VBox/AddToPartyButton").disabled)


## A whole-file search for "GameManager.go_to_roster()" would also match the
## Add-to-Party success path, so this scopes the assertion to
## _on_back_pressed()'s own source and checks each branch of its single
## if/else independently: the branch guarded by the Roster-origin check must
## route to Roster, and the other branch must route to Parties. This fails
## if the two branches are ever swapped, unlike a plain substring search.
func test_back_button_routes_to_roster_for_roster_origin_and_to_parties_otherwise() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/unit_details.gd")
	var back_pressed_source := _function_source(source, "_on_back_pressed")
	var branches := back_pressed_source.split("else", true, 1)

	assert_eq(
		branches.size(),
		2,
		"_on_back_pressed must branch once on origin (if/else) for this test to discriminate the branches"
	)
	assert_string_contains(
		branches[0],
		"UNIT_DETAILS_ORIGIN_ROSTER",
		"The first branch must be the one guarded by the Roster-origin check"
	)
	assert_string_contains(
		branches[0],
		"GameManager.go_to_roster()",
		"The Roster-origin branch specifically must route to Roster"
	)
	assert_string_contains(
		branches[1], "GameManager.go_to_parties()", "Every other origin must route to Parties"
	)


func test_back_button_from_roster_origin_routes_to_roster_and_clears_context() -> void:
	var screen := _open_unit_details_from_roster(GameSession.WARRIOR_ID)

	screen.get_node("Center/VBox/BackButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, "")
	assert_eq(GameManager.unit_details_origin, "")


func test_back_from_add_member_returns_to_the_same_partys_candidate_list() -> void:
	GameSession.create_party()
	var screen := _open_unit_details_from_add_member(GameSession.WARRIOR_ID, GameSession.FIRST_PARTY_ID)

	screen.get_node("Center/VBox/BackButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, GameSession.FIRST_PARTY_ID)
	assert_eq(GameManager.unit_details_origin, "")
	assert_eq(GameManager.add_member_return_party_id, "")


func test_back_from_add_member_with_a_stale_party_falls_back_to_parties() -> void:
	GameSession.create_party()
	var screen := _open_unit_details_from_add_member(GameSession.WARRIOR_ID, GameSession.FIRST_PARTY_ID)
	GameSession.reset()

	screen.get_node("Center/VBox/BackButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, "")
	assert_eq(GameManager.unit_details_origin, "")
	assert_eq(GameManager.add_member_return_party_id, "")
