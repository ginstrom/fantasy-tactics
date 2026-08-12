extends GutTest

const RecruitmentScene := preload("res://scenes/ui/recruitment.tscn")
const UiTestHelpers := preload("res://tests/unit/ui_test_helpers.gd")
const ScreenshotTourScript := preload("res://scripts/tools/screenshot_tour.gd")


func before_each() -> void:
	GameSession.reset()
	GameManager.route_context_id = ""
	GameManager.unit_details_origin = ""
	GameManager.recruitment_target_party_id = ""


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.route_context_id = ""
	GameManager.unit_details_origin = ""
	GameManager.recruitment_target_party_id = ""


func test_recruitment_shows_the_title_and_the_back_action() -> void:
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "recruitment.title")
	assert_eq(screen.get_node("Body/Center/VBox/ViewRosterButton").text, "recruitment.view_roster")
	assert_eq(tr("recruitment.view_roster"), "View Roster")
	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


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
	var panel: Control = screen.get_node("%InformationPanel")

	assert_true(panel.get_node("Content/PlayerName").visible)
	assert_eq(panel.get_node("Content/PlayerName").text, tr("information.player") % "Aria")
	assert_true(panel.get_node("Content/Gold").visible)
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


func test_recruitment_table_uses_the_documented_columns() -> void:
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/RecruitmentTable/Tree")

	assert_eq(tree.columns, 4)
	assert_eq(tree.get_column_title(0), "Name")
	assert_eq(tree.get_column_title(1), "Class")
	assert_eq(tree.get_column_title(2), "Level")
	assert_eq(tree.get_column_title(3), "Cost")


## Task 4: a fresh campaign seeds exactly one active recruitment offer
## (warrior_002); the other fixed templates (warrior_003/004) only appear
## once their own variable 30 +/- 5 turn vacancy clock refills the offer list.
func test_recruitment_lists_exactly_the_current_candidates() -> void:
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/RecruitmentTable/Tree")

	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Warrior 2"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 1), ["Warrior"])
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
	var tree: Tree = screen.get_node("Body/Center/VBox/RecruitmentTable/Tree")

	assert_eq(UiTestHelpers.tree_row_values(tree, 0), [] as Array[String])


func test_selecting_a_row_stores_the_id_locally_and_shows_its_cost_in_the_panel() -> void:
	GameSession.gold = 25
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/RecruitmentTable/Tree")
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
	var tree: Tree = screen.get_node("Body/Center/VBox/RecruitmentTable/Tree")
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
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/RecruitmentTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")

	assert_true(panel.get_node("Content/RecruitButton").disabled)


func test_the_recruit_action_is_enabled_with_ten_gold() -> void:
	GameSession.gold = 10
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/RecruitmentTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")

	assert_false(panel.get_node("Content/RecruitButton").disabled)


func test_pressing_recruit_purchases_the_selected_candidate_and_refreshes_in_place() -> void:
	GameSession.gold = 10
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
		await get_tree().process_frame
	assert_eq(GameManager.go_to_recruitment(), OK)
	var settle_frames := 0
	while get_tree().current_scene == null and settle_frames < 10:
		await get_tree().process_frame
		settle_frames += 1
	var screen: Control = get_tree().current_scene
	assert_not_null(screen, "The real Recruitment route must produce a live scene")
	if screen == null:
		return
	assert_eq(screen.name, "Recruitment")
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/RecruitmentTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")
	GameManager.route_context_id = "stale_id"

	panel.get_node("Content/RecruitButton").emit_signal("pressed")

	assert_eq(GameSession.gold, 0, "The one-time purchase must deduct the candidate's cost")
	assert_eq(GameSession.get_recruitment_candidates().size(), 0)
	assert_eq(GameSession.adventurers.size(), 2)
	assert_eq(GameSession.adventurers[1].id, "warrior_002")
	assert_eq(screen.selected_candidate_id, "", "A purchased candidate must not remain selected")
	assert_eq(UiTestHelpers.tree_row_values(tree, 0), [] as Array[String])
	await get_tree().process_frame
	assert_eq(get_tree().current_scene, screen, "Ordinary recruitment must remain on the live Recruitment scene")


func test_targeted_recruitment_assigns_only_the_requested_encamped_party() -> void:
	GameSession.create_party()
	GameSession.recruit_adventurer()
	GameSession.gold = 10
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
		await get_tree().process_frame
	assert_eq(GameManager.go_to_recruitment_for_party(GameSession.FIRST_PARTY_ID), OK)
	var settle_frames := 0
	while get_tree().current_scene == null and settle_frames < 10:
		await get_tree().process_frame
		settle_frames += 1
	var screen: Control = get_tree().current_scene
	assert_not_null(screen, "The real targeted Recruitment route must produce a live scene")
	if screen == null:
		return
	assert_eq(screen.name, "Recruitment")
	var tree: Tree = screen.get_node("Body/Center/VBox/RecruitmentTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")
	screen.get_node("%InformationPanel/Content/RecruitButton").emit_signal("pressed")
	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, ["warrior_002"])
	assert_eq(GameManager.recruitment_target_party_id, GameSession.FIRST_PARTY_ID)
	assert_eq(screen.selected_candidate_id, "")
	assert_eq(UiTestHelpers.tree_row_values(tree, 0), [] as Array[String])
	await get_tree().process_frame
	assert_eq(get_tree().current_scene, screen, "Targeted recruitment must remain on the live Recruitment scene")


func test_view_roster_clears_the_target_context_and_routes_through_roster() -> void:
	GameSession.create_party()
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
		await get_tree().process_frame
	assert_eq(GameManager.go_to_recruitment_for_party(GameSession.FIRST_PARTY_ID), OK)
	var settle_frames := 0
	while get_tree().current_scene == null and settle_frames < 10:
		await get_tree().process_frame
		settle_frames += 1
	var screen: Control = get_tree().current_scene
	assert_not_null(screen, "The real targeted Recruitment route must produce a live scene")
	if screen == null:
		return

	screen.get_node("Body/Center/VBox/ViewRosterButton").emit_signal("pressed")
	await get_tree().process_frame

	assert_eq(GameManager.recruitment_target_party_id, "")
	assert_eq(GameManager.route_context_id, "")
	assert_eq(get_tree().current_scene.name, "Roster")


func test_view_roster_button_is_between_the_candidate_state_and_back() -> void:
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var vbox: VBoxContainer = screen.get_node("Body/Center/VBox")

	assert_lt(vbox.get_node("RecruitmentTable").get_index(), vbox.get_node("ViewRosterButton").get_index())
	assert_lt(vbox.get_node("EmptyLabel").get_index(), vbox.get_node("ViewRosterButton").get_index())
	assert_lt(vbox.get_node("ViewRosterButton").get_index(), vbox.get_node("BackButton").get_index())


func test_stale_targeted_recruitment_falls_back_without_assigning_elsewhere() -> void:
	GameSession.gold = 10
	GameManager.recruitment_target_party_id = "missing_party"
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	screen._on_information_panel_recruit_selected("warrior_002")
	assert_eq(GameSession.adventurers.size(), 1)
	assert_eq(GameSession.get_recruitment_candidates().size(), 1)
	assert_eq(GameManager.recruitment_target_party_id, "")


func _assert_stale_target_purchase_is_inert() -> void:
	var gold_before: int = GameSession.gold
	var candidates_before: Array = GameSession.get_recruitment_candidates()
	var roster_before: Array = GameSession.adventurers.duplicate(true)
	var members_before: Array = GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids.duplicate()
	var vacancies_before: Array = GameSession.recruitment_vacancies.duplicate(true)
	assert_eq(GameManager.purchase_recruit_for_target_party("warrior_002"), ERR_INVALID_DATA)
	assert_eq(GameSession.gold, gold_before)
	assert_eq(GameSession.get_recruitment_candidates(), candidates_before)
	assert_eq(GameSession.adventurers, roster_before)
	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, members_before)
	assert_eq(GameSession.recruitment_vacancies, vacancies_before)
	assert_eq(GameManager.recruitment_target_party_id, "")


func test_targeted_recruitment_becomes_ordinary_when_the_target_deploys() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.gold = 10
	assert_eq(GameManager.go_to_recruitment_for_party(GameSession.FIRST_PARTY_ID), OK)
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	_assert_stale_target_purchase_is_inert()


func test_targeted_recruitment_becomes_ordinary_when_the_target_fills() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.gold = 10
	assert_eq(GameManager.go_to_recruitment_for_party(GameSession.FIRST_PARTY_ID), OK)
	for index in 3:
		GameSession.recruit_adventurer()
		GameSession.assign_adventurer_to_selected_party("warrior_%03d" % (index + 3))
	_assert_stale_target_purchase_is_inert()


func test_a_second_purchase_attempt_of_the_same_now_gone_candidate_does_not_purchase_again() -> void:
	GameSession.gold = 20
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/RecruitmentTable/Tree")
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
	var tree: Tree = screen.get_node("Body/Center/VBox/RecruitmentTable/Tree")
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
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/RecruitmentTable/Tree")
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

	assert_true(screen.get_node("Body/Center/VBox/EmptyLabel").visible)
	assert_eq(screen.get_node("Body/Center/VBox/EmptyLabel").text, "recruitment.empty")


func test_purchasing_the_last_candidate_leaves_the_empty_state_after_a_refresh() -> void:
	GameSession.gold = 30
	var screen: Control = RecruitmentScene.instantiate()
	add_child_autofree(screen)
	GameSession.purchase_recruit("warrior_002")

	screen.refresh()

	assert_true(screen.get_node("Body/Center/VBox/EmptyLabel").visible)


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
