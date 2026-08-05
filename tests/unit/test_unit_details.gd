extends GutTest

const UnitDetailsScene := preload("res://scenes/ui/unit_details.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.route_context_id = ""


func _open_unit_details(adventurer_id: String) -> Control:
	GameManager.route_context_id = adventurer_id
	var screen: Control = UnitDetailsScene.instantiate()
	add_child_autofree(screen)
	return screen


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
		screen.get_node("Center/VBox/StatusLabel").text, tr("unit_details.status") % "available"
	)


func test_renders_status_for_a_non_available_unit() -> void:
	GameSession.adventurers[0]["availability_status"] = "unavailable"
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(
		screen.get_node("Center/VBox/StatusLabel").text, tr("unit_details.status") % "unavailable"
	)


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
