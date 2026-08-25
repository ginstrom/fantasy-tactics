extends GutTest

const AddMemberScene := preload("res://scenes/ui/add_member.tscn")
const UiTestHelpers := preload("res://tests/unit/ui_test_helpers.gd")


func before_each() -> void:
	GameSession.reset()
	GameManager.add_member_return_party_id = ""


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.route_context_id = ""
	GameManager.add_member_return_party_id = ""


func _open_add_member(party_id: String) -> Control:
	GameManager.route_context_id = party_id
	var screen: Control = AddMemberScene.instantiate()
	add_child_autofree(screen)
	return screen


func test_add_member_shows_the_title_and_the_back_action() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)

	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "add_member.title")
	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


func test_add_member_shows_the_activation_hint() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)

	assert_eq(screen.get_node("Body/Center/VBox/HintLabel").text, "add_member.hint")


func test_reads_the_party_id_from_route_context() -> void:
	GameSession.create_party()

	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)

	assert_eq(screen.party_id, GameSession.FIRST_PARTY_ID)


func test_add_member_uses_the_sessions_availability_query_not_a_private_predicate() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/add_member.gd")
	assert_false(source.contains("func _is_adventurer_available"))
	assert_string_contains(source, "GameSession.is_adventurer_available")


func test_no_available_adventurer_shows_the_empty_state_without_errors() -> void:
	GameSession.create_party()
	for adventurer in GameSession.adventurers:
		adventurer.availability_status = "unavailable"
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)

	assert_true(screen.get_node("Body/Center/VBox/EmptyLabel").visible)
	assert_eq(screen.get_node("Body/Center/VBox/EmptyLabel").text, "add_member.empty")
	var tree: Tree = screen.get_node("Body/Center/VBox/AdventurerTable/Tree")
	assert_eq(UiTestHelpers.tree_row_values(tree, 0), [] as Array[String])


func test_add_member_table_uses_the_documented_columns() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Body/Center/VBox/AdventurerTable/Tree")

	assert_eq(tree.columns, 3)
	assert_eq(tree.get_column_title(0), "Name")
	assert_eq(tree.get_column_title(1), "Class")
	assert_eq(tree.get_column_title(2), "Level")


func test_lists_exactly_the_available_adventurers() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Body/Center/VBox/AdventurerTable/Tree")

	assert_false(screen.get_node("Body/Center/VBox/EmptyLabel").visible)
	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Warrior", "Warrior 2", "Warrior 3", "Warrior 4"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 1), ["Warrior", "Warrior", "Warrior", "Warrior"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 2), ["1", "1", "1", "1"])


func test_add_member_localizes_a_scout_class() -> void:
	GameSession.adventurers.append(GameSession.get_default_scout("scout_001", "Scout"))
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Body/Center/VBox/AdventurerTable/Tree")

	assert_eq(UiTestHelpers.tree_row_values(tree, 1), ["Warrior", "Warrior", "Warrior", "Warrior", "Scout"])


func test_selecting_a_row_stores_the_id_locally_and_shows_its_summary_in_the_panel() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/AdventurerTable/Tree")
	var item := tree.get_root().get_first_child()

	item.select(0)
	tree.emit_signal("item_selected")

	assert_eq(screen.selected_adventurer_id, GameSession.WARRIOR_ID)
	assert_true(panel.get_node("Content/AdventurerName").visible)
	assert_eq(panel.get_node("Content/AdventurerName").text, "Warrior")
	assert_true(panel.get_node("Content/AdventurerViewButton").visible)
	assert_eq(
		GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids,
		[] as Array[String],
		"Selecting a row must not assign it"
	)


func test_the_panels_view_button_opens_card_navigator() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/AdventurerTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")

	panel.get_node("Content/AdventurerViewButton").emit_signal("pressed")

	var navigator: CardNavigator = screen.get_node("CardNavigator")
	assert_true(navigator.visible)
	assert_eq(navigator.get_current_id(), GameSession.WARRIOR_ID)


func test_assigning_from_unit_card_targets_the_current_party() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/AdventurerTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")
	panel.get_node("Content/AdventurerViewButton").emit_signal("pressed")

	assert_true(screen.unit_detail_card.add_to_party_button.visible)
	assert_false(screen.unit_detail_card.party_picker.visible, "Add Member has a fixed route-context party")
	screen.unit_detail_card.add_to_party_button.emit_signal("pressed")

	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [GameSession.WARRIOR_ID])
	assert_false(screen.card_navigator.visible)
	assert_eq(GameManager.route_context_id, GameSession.FIRST_PARTY_ID)


func test_add_member_card_navigator_cycles_and_wraps() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/AdventurerTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")
	panel.get_node("Content/AdventurerViewButton").emit_signal("pressed")

	var navigator: CardNavigator = screen.get_node("CardNavigator")
	var next_btn: Button = navigator.get_node("%NextButton")
	var prev_btn: Button = navigator.get_node("%PrevButton")

	assert_eq(navigator.get_current_id(), GameSession.WARRIOR_ID)
	next_btn.emit_signal("pressed")
	assert_eq(navigator.get_current_id(), GameSession.adventurers[1].id)
	next_btn.emit_signal("pressed")
	assert_eq(navigator.get_current_id(), GameSession.adventurers[2].id)
	next_btn.emit_signal("pressed")
	assert_eq(navigator.get_current_id(), GameSession.adventurers[3].id)
	next_btn.emit_signal("pressed")
	assert_eq(navigator.get_current_id(), GameSession.WARRIOR_ID, "Must wrap to first")

	prev_btn.emit_signal("pressed")
	assert_eq(navigator.get_current_id(), GameSession.adventurers[3].id, "Must wrap to last")


func test_add_member_closing_card_navigator_restores_selection() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/AdventurerTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")
	panel.get_node("Content/AdventurerViewButton").emit_signal("pressed")

	var navigator: CardNavigator = screen.get_node("CardNavigator")
	navigator.next()
	var second_id: String = GameSession.adventurers[1].id
	assert_eq(navigator.get_current_id(), second_id)

	navigator.close()
	assert_false(navigator.visible)
	assert_eq(screen.selected_adventurer_id, second_id)
	var selected_ids: Array = screen.get_node("Body/Center/VBox/AdventurerTable").get_selected_row_ids()
	assert_eq(selected_ids, [second_id])


func test_activating_a_row_assigns_that_exact_adventurer_to_this_party() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Body/Center/VBox/AdventurerTable/Tree")
	tree.get_root().get_first_child().select(0)

	tree.emit_signal("item_activated")

	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [GameSession.WARRIOR_ID])


func test_activating_a_row_returns_to_that_partys_details() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Body/Center/VBox/AdventurerTable/Tree")
	tree.get_root().get_first_child().select(0)

	tree.emit_signal("item_activated")

	assert_eq(GameManager.route_context_id, GameSession.FIRST_PARTY_ID)


func test_a_stale_row_fails_safely_and_refreshes_the_list_in_place() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Body/Center/VBox/AdventurerTable/Tree")
	tree.get_root().get_first_child().select(0)
	# The adventurer gets assigned elsewhere out from under the still-displayed row.
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)

	tree.emit_signal("item_activated")

	assert_false(screen.get_node("Body/Center/VBox/EmptyLabel").visible)
	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Warrior 2", "Warrior 3", "Warrior 4"])


func test_back_button_returns_to_party_details_without_mutating_the_party() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)

	screen.get_node("Body/Center/VBox/BackButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, GameSession.FIRST_PARTY_ID)
	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [] as Array[String])


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)


func test_add_member_candidate_unavailable_while_card_open_closes_safely() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/AdventurerTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")
	panel.get_node("Content/AdventurerViewButton").emit_signal("pressed")

	var navigator: CardNavigator = screen.get_node("CardNavigator")
	assert_true(navigator.visible)

	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	screen.refresh()

	assert_false(navigator.visible, "CardNavigator must close if candidate becomes unavailable")
