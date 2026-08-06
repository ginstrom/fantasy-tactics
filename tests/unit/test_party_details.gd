extends GutTest

const PartyDetailsScene := preload("res://scenes/ui/party_details.tscn")
const UiTestHelpers := preload("res://tests/unit/ui_test_helpers.gd")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.route_context_id = ""


func _open_party_details(party_id: String) -> Control:
	GameManager.route_context_id = party_id
	var screen: Control = PartyDetailsScene.instantiate()
	add_child_autofree(screen)
	return screen


func test_party_details_shows_the_title_and_the_back_action() -> void:
	GameSession.create_party()
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	assert_eq(screen.get_node("Center/VBox/Title").text, "party_details.title")
	assert_eq(screen.get_node("Center/VBox/BackButton").text, "ui.back")


func test_add_member_is_enabled_for_an_encamped_party_with_an_available_adventurer() -> void:
	GameSession.create_party()
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	var add_button: Button = screen.get_node("Center/VBox/AddMemberButton")
	assert_true(add_button.visible, "Add Member must be offered for an encamped party")
	assert_false(add_button.disabled, "An available adventurer exists, so Add Member must be usable")
	assert_eq(add_button.text, "party_details.add_member")


func test_add_member_is_disabled_when_no_adventurer_is_available() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	var add_button: Button = screen.get_node("Center/VBox/AddMemberButton")
	assert_true(add_button.visible)
	assert_true(add_button.disabled, "The only adventurer is already a member of this party")


func test_pressing_add_member_routes_to_the_add_member_screen_with_this_partys_id() -> void:
	GameSession.create_party()
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	screen.get_node("Center/VBox/AddMemberButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, GameSession.FIRST_PARTY_ID)


func test_add_member_is_hidden_entirely_for_a_deployed_party() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	assert_false(
		screen.get_node("Center/VBox/AddMemberButton").visible,
		"You can't add a member to a party that's out in the field"
	)


func test_reads_the_party_id_from_route_context() -> void:
	GameSession.create_party()

	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	assert_eq(screen.party_id, GameSession.FIRST_PARTY_ID)


func test_an_empty_party_shows_the_empty_state_without_errors() -> void:
	GameSession.create_party()
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	assert_true(screen.get_node("Center/VBox/EmptyLabel").visible)
	assert_eq(screen.get_node("Center/VBox/EmptyLabel").text, "party_details.no_members")
	var tree: Tree = screen.get_node("Center/VBox/MemberTable/Tree")
	assert_eq(UiTestHelpers.tree_row_values(tree, 0), [] as Array[String])


## Column titles are resolved via tr() (see party_details.gd) to the real
## English copy in translations/en.tres (Name/Class/Level — see the
## migration brief).
func test_party_details_table_uses_the_documented_columns() -> void:
	GameSession.create_party()
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Center/VBox/MemberTable/Tree")

	assert_eq(tree.columns, 3)
	assert_eq(tree.get_column_title(0), "Name")
	assert_eq(tree.get_column_title(1), "Class")
	assert_eq(tree.get_column_title(2), "Level")


func test_every_member_renders_as_a_row_with_name_class_and_level() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Center/VBox/MemberTable/Tree")

	assert_false(screen.get_node("Center/VBox/EmptyLabel").visible)
	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Warrior"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 1), ["warrior"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 2), ["1"])


func test_selecting_a_member_row_refreshes_the_panels_adventurer_context() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)
	var panel: Control = screen.get_node("InformationPanel")
	var tree: Tree = screen.get_node("Center/VBox/MemberTable/Tree")
	var item := tree.get_root().get_first_child()

	item.select(0)
	tree.emit_signal("item_selected")

	assert_eq(screen.selected_adventurer_id, GameSession.WARRIOR_ID)
	assert_true(panel.get_node("Content/AdventurerName").visible)
	assert_eq(panel.get_node("Content/AdventurerName").text, "Warrior")
	assert_true(panel.get_node("Content/AdventurerViewButton").visible)


func test_the_panels_view_button_asks_game_manager_to_open_unit_details_for_that_exact_id() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)
	var panel: Control = screen.get_node("InformationPanel")
	var tree: Tree = screen.get_node("Center/VBox/MemberTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")

	panel.get_node("Content/AdventurerViewButton").emit_signal("pressed")

	assert_eq(
		GameManager.route_context_id,
		GameSession.WARRIOR_ID,
		"Pressing View must ask GameManager to route to that exact unit's details"
	)


func test_activating_a_row_asks_game_manager_to_open_unit_details_for_that_exact_id() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Center/VBox/MemberTable/Tree")
	tree.get_root().get_first_child().select(0)

	tree.emit_signal("item_activated")

	assert_eq(GameManager.route_context_id, GameSession.WARRIOR_ID)


func test_a_refresh_that_invalidates_the_selection_clears_it() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)
	var panel: Control = screen.get_node("InformationPanel")
	var tree: Tree = screen.get_node("Center/VBox/MemberTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")
	assert_eq(screen.selected_adventurer_id, GameSession.WARRIOR_ID)

	GameSession.reset()
	screen.refresh()

	assert_eq(screen.selected_adventurer_id, "")
	assert_false(panel.get_node("Content/AdventurerName").visible)


func test_an_unknown_party_id_does_not_crash_and_shows_no_members() -> void:
	var screen := _open_party_details("no_such_party")
	var tree: Tree = screen.get_node("Center/VBox/MemberTable/Tree")

	assert_eq(UiTestHelpers.tree_row_values(tree, 0), [] as Array[String])


func test_back_button_returns_to_parties_and_leaves_the_party_untouched() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var source := FileAccess.get_file_as_string("res://scripts/ui/party_details.gd")

	assert_string_contains(source, "GameManager.go_to_parties()")


func test_back_button_clears_only_the_ui_route_context() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	screen.get_node("Center/VBox/BackButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, "")
	assert_false(GameSession.has_deployed_party(), "Back must never deploy or otherwise mutate the party")
	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [GameSession.WARRIOR_ID])


func test_back_button_returns_to_the_world_map_for_a_deployed_party() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/party_details.gd")

	assert_string_contains(source, "GameManager.go_to_world_map()")


func test_back_button_clears_route_context_and_leaves_a_deployed_party_untouched() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	screen.get_node("Center/VBox/BackButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, "")
	assert_true(
		GameSession.has_deployed_party(),
		"Back must never undeploy the party just because it viewed its details"
	)
	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [GameSession.WARRIOR_ID])


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	GameSession.create_party()
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
