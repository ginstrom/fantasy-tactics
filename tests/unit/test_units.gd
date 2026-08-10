extends GutTest

const UnitsScene := preload("res://scenes/ui/units.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()
	# test_entering_units_clears_a_stale_route_context_id() below is the one
	# test in this file that drives a REAL GameManager.go_to_units() ->
	# get_tree().change_scene_to_file() scene change rather than only
	# instancing UnitsScene directly. Leaving that real Units scene as
	# get_tree().current_scene for the rest of the suite's run makes it a
	# live, full-screen, mouse_filter=STOP Control sitting at the front of
	# the whole viewport's GUI hit-test -- silently absorbing any later
	# test's own push_input()-driven click anywhere onscreen, in a
	# completely unrelated scene/test. Unload it so this file never leaks
	# that into whatever test happens to run next.
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()


func test_units_shows_the_title_and_the_back_action() -> void:
	var screen: Control = UnitsScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "units.title")
	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


func test_shows_the_permanent_player_and_gold_rows() -> void:
	GameSession.player_name = "Aria"
	GameSession.gold = 25
	var screen: Control = UnitsScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("%InformationPanel")

	assert_true(panel.get_node("Content/PlayerName").visible)
	assert_eq(panel.get_node("Content/PlayerName").text, tr("information.player") % "Aria")
	assert_true(panel.get_node("Content/Gold").visible)
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


func test_parties_and_roster_are_active_branches() -> void:
	var screen: Control = UnitsScene.instantiate()
	add_child_autofree(screen)

	assert_false(screen.get_node("Body/Center/VBox/PartiesButton").disabled)
	assert_eq(screen.get_node("Body/Center/VBox/PartiesButton").text, "units.parties")
	assert_false(screen.get_node("Body/Center/VBox/RosterButton").disabled)
	assert_eq(screen.get_node("Body/Center/VBox/RosterButton").text, "units.roster")


func test_recruitment_is_an_active_branch() -> void:
	var screen: Control = UnitsScene.instantiate()
	add_child_autofree(screen)

	assert_false(screen.get_node("Body/Center/VBox/RecruitmentButton").disabled)
	assert_eq(screen.get_node("Body/Center/VBox/RecruitmentButton").text, "units.recruitment")


func test_recruitment_button_routes_to_the_recruitment_screen() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/units.gd")
	assert_string_contains(source, "GameManager.go_to_recruitment()")


func test_parties_button_routes_to_the_parties_screen() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/units.gd")
	assert_string_contains(source, "GameManager.go_to_parties()")


func test_roster_button_routes_to_the_roster_screen() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/units.gd")
	assert_string_contains(source, "GameManager.go_to_roster()")


func test_back_button_returns_to_the_encampment() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/units.gd")
	assert_string_contains(source, "GameManager.go_to_encampment()")


func test_entering_units_clears_a_stale_route_context_id() -> void:
	GameManager.route_context_id = "stale_id"

	GameManager.go_to_units()

	assert_eq(GameManager.route_context_id, "")


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var screen: Control = UnitsScene.instantiate()
	add_child_autofree(screen)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)


func test_units_contains_the_camp_nav() -> void:
	var screen: Control = UnitsScene.instantiate()
	add_child_autofree(screen)

	assert_not_null(screen.get_node("Body/CampNav"))
