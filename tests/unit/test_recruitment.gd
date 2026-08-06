extends GutTest

const RecruitmentScene := preload("res://scenes/ui/recruitment.tscn")
const UiTestHelpers := preload("res://tests/unit/ui_test_helpers.gd")
const ScreenshotTourScript := preload("res://scripts/tools/screenshot_tour.gd")


func before_each() -> void:
	GameSession.reset()
	GameManager.route_context_id = ""
	GameManager.unit_details_origin = ""


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.route_context_id = ""
	GameManager.unit_details_origin = ""


func test_recruitment_shows_the_title_and_the_back_action() -> void:
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Center/VBox/Title").text, "recruitment.title")
	assert_eq(screen.get_node("Center/VBox/BackButton").text, "ui.back")


func test_recruitment_uses_the_sessions_candidate_query_not_a_private_predicate() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/recruitment.gd")
	assert_false(source.contains("func _candidate_exists"))
	assert_string_contains(source, "GameSession.has_recruitment_candidate")


func test_screenshot_tour_captures_distinct_affordable_and_unaffordable_recruitment_states() -> void:
	var tour: Node = ScreenshotTourScript.new()
	autofree(tour)
	var step_names: Array[String] = []
	for step in tour._build_steps():
		step_names.append(step.name)

	assert_true(step_names.has("recruitment_affordable"))
	assert_true(step_names.has("recruitment_unaffordable"))


func test_shows_the_permanent_player_and_gold_rows() -> void:
	GameSession.player_name = "Aria"
	GameSession.gold = 25
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")

	assert_true(panel.get_node("Content/PlayerName").visible)
	assert_eq(panel.get_node("Content/PlayerName").text, tr("information.player") % "Aria")
	assert_true(panel.get_node("Content/Gold").visible)
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


func test_recruitment_table_uses_the_documented_columns() -> void:
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Center/VBox/RecruitmentTable/Tree")

	assert_eq(tree.columns, 4)
	assert_eq(tree.get_column_title(0), "Name")
	assert_eq(tree.get_column_title(1), "Class")
	assert_eq(tree.get_column_title(2), "Level")
	assert_eq(tree.get_column_title(3), "Cost")


## Task 4: a fresh campaign seeds exactly one active recruitment offer
## (warrior_002); the other fixed templates (warrior_003/004) only appear
## once their own 30-turn vacancy clock refills the offer list.
func test_recruitment_lists_exactly_the_current_candidates() -> void:
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Center/VBox/RecruitmentTable/Tree")

	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Warrior 2"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 1), ["warrior"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 2), ["1"])
	assert_eq(
		UiTestHelpers.tree_row_values(tree, 3),
		["%d %s" % [10, tr(&"recruitment.column.cost_unit")]]
	)


func test_recruitment_does_not_list_a_candidate_already_purchased_elsewhere() -> void:
	GameSession.gold = 10
	GameSession.purchase_recruit("warrior_002")
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Center/VBox/RecruitmentTable/Tree")

	assert_eq(UiTestHelpers.tree_row_values(tree, 0), [] as Array[String])


func test_selecting_a_row_stores_the_id_locally_and_shows_its_cost_in_the_panel() -> void:
	GameSession.gold = 25
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")
	var tree: Tree = screen.get_node("Center/VBox/RecruitmentTable/Tree")
	var item := tree.get_root().get_first_child()

	item.select(0)
	tree.emit_signal("item_selected")

	assert_eq(screen.selected_candidate_id, "warrior_002")
	assert_true(panel.get_node("Content/RecruitmentName").visible)
	assert_eq(panel.get_node("Content/RecruitmentName").text, "Warrior 2")
	assert_true(panel.get_node("Content/RecruitButton").visible)


## Selection alone must never purchase — only pressing the panel's Recruit
## action (see test_pressing_recruit_...) does that.
func test_selecting_a_row_does_not_purchase_it() -> void:
	GameSession.gold = 25
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Center/VBox/RecruitmentTable/Tree")
	var item := tree.get_root().get_first_child()

	item.select(0)
	tree.emit_signal("item_selected")

	assert_eq(GameSession.gold, 25)
	assert_eq(GameSession.get_recruitment_candidates().size(), 1)
	assert_eq(GameSession.adventurers.size(), 1)


func test_the_recruit_action_is_disabled_with_zero_gold() -> void:
	GameSession.gold = 0
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")
	var tree: Tree = screen.get_node("Center/VBox/RecruitmentTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")

	assert_true(panel.get_node("Content/RecruitButton").disabled)


func test_the_recruit_action_is_enabled_with_ten_gold() -> void:
	GameSession.gold = 10
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")
	var tree: Tree = screen.get_node("Center/VBox/RecruitmentTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")

	assert_false(panel.get_node("Content/RecruitButton").disabled)


func test_pressing_recruit_purchases_the_selected_candidate_and_routes_to_roster() -> void:
	GameSession.gold = 10
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")
	var tree: Tree = screen.get_node("Center/VBox/RecruitmentTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")
	GameManager.route_context_id = "stale_id"

	panel.get_node("Content/RecruitButton").emit_signal("pressed")

	assert_eq(GameSession.gold, 0, "The one-time purchase must deduct the candidate's cost")
	assert_eq(GameSession.get_recruitment_candidates().size(), 0)
	assert_eq(GameSession.adventurers.size(), 2)
	assert_eq(GameSession.adventurers[1].id, "warrior_002")
	assert_eq(
		GameManager.route_context_id,
		"",
		"A successful purchase must route through go_to_roster(), which clears route context"
	)


func test_a_second_purchase_attempt_of_the_same_now_gone_candidate_does_not_purchase_again() -> void:
	GameSession.gold = 20
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")
	var tree: Tree = screen.get_node("Center/VBox/RecruitmentTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")
	panel.get_node("Content/RecruitButton").emit_signal("pressed")
	assert_eq(GameSession.gold, 10)

	# A second attempt at the same, now-purchased id, as if the action fired
	# again before the scene finished routing away.
	screen._on_information_panel_recruit_selected("warrior_002")

	assert_eq(GameSession.gold, 10, "A stale candidate id must never be purchased twice")


func test_pressing_recruit_for_a_candidate_purchased_elsewhere_refreshes_in_place() -> void:
	GameSession.gold = 10
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Center/VBox/RecruitmentTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")
	assert_eq(screen.selected_candidate_id, "warrior_002")
	# The candidate is purchased through another path while this screen is open.
	GameSession.purchase_recruit("warrior_002")

	screen._on_information_panel_recruit_selected("warrior_002")

	assert_eq(screen.selected_candidate_id, "")
	assert_eq(GameSession.gold, 0, "The stale purchase attempt must not deduct gold again")
	assert_eq(UiTestHelpers.tree_row_values(tree, 0), [] as Array[String])


func test_a_candidate_that_goes_stale_after_being_purchased_elsewhere_refreshes_safely() -> void:
	GameSession.gold = 25
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")
	var tree: Tree = screen.get_node("Center/VBox/RecruitmentTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")
	assert_eq(screen.selected_candidate_id, "warrior_002")
	GameSession.purchase_recruit("warrior_002")

	screen.refresh()

	assert_eq(screen.selected_candidate_id, "")
	assert_false(panel.get_node("Content/RecruitmentName").visible)
	assert_eq(UiTestHelpers.tree_row_values(tree, 0), [] as Array[String])


func test_an_empty_recruitment_shows_the_empty_state_without_errors() -> void:
	GameSession.recruitment_candidates.clear()
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)

	assert_true(screen.get_node("Center/VBox/EmptyLabel").visible)
	assert_eq(screen.get_node("Center/VBox/EmptyLabel").text, "recruitment.empty")


func test_purchasing_the_last_candidate_leaves_the_empty_state_after_a_refresh() -> void:
	GameSession.gold = 30
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	GameSession.purchase_recruit("warrior_002")

	screen.refresh()

	assert_true(screen.get_node("Center/VBox/EmptyLabel").visible)


func test_back_button_returns_to_units() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/recruitment.gd")
	assert_string_contains(source, "GameManager.go_to_units()")


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
