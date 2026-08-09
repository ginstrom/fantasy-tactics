extends GutTest

const AssignEquipmentScene := preload("res://scenes/ui/assign_equipment.tscn")
const UiTestHelpers := preload("res://tests/unit/ui_test_helpers.gd")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.route_context_id = ""
	GameManager.assign_equipment_party_id = ""
	GameManager.assign_equipment_origin = GameManager.AssignEquipmentOrigin.STORES


func test_assign_equipment_shows_the_title_and_the_back_action() -> void:
	GameManager.route_context_id = "dagger_iron"
	var screen: Control = AssignEquipmentScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "assign_equipment.title")
	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


func test_assign_equipment_contains_the_camp_nav() -> void:
	GameManager.route_context_id = "dagger_iron"
	var screen: Control = AssignEquipmentScene.instantiate()
	add_child_autofree(screen)

	assert_not_null(screen.get_node_or_null("Body/CampNav"))


func test_back_button_returns_to_stores() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/assign_equipment.gd")
	assert_string_contains(source, "GameManager.go_to_stores()")


func test_back_returns_to_battle_result_when_that_was_the_origin() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/assign_equipment.gd")
	assert_string_contains(source, "GameManager.go_to_battle_result(GameManager.battle_result_summary)")


func test_back_returns_to_party_details_when_that_was_the_origin() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/assign_equipment.gd")
	assert_string_contains(source, "GameManager.go_to_party_details(GameManager.assign_equipment_party_id)")


func test_table_lists_the_default_warrior() -> void:
	GameManager.route_context_id = "dagger_iron"
	var screen: Control = AssignEquipmentScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/AdventurerTable/Tree")

	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Warrior"])
	assert_false(screen.get_node("Body/Center/VBox/EmptyLabel").visible)


func test_table_is_scoped_to_the_party_when_a_party_id_is_set() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.recruit_adventurer()
	GameManager.route_context_id = "dagger_iron"
	GameManager.assign_equipment_party_id = GameSession.FIRST_PARTY_ID
	var screen: Control = AssignEquipmentScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/AdventurerTable/Tree")

	assert_eq(
		UiTestHelpers.tree_row_values(tree, 0), ["Warrior"],
		"Only the party's own member, not the freshly recruited, unassigned adventurer"
	)


func test_activating_a_row_equips_the_item_and_returns_to_stores() -> void:
	GameSession.banked_gear = {"dagger_iron": 1}
	GameManager.route_context_id = "dagger_iron"
	var screen: Control = AssignEquipmentScene.instantiate()
	add_child_autofree(screen)

	screen._on_row_activated(GameSession.WARRIOR_ID)

	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.weapon, "dagger_iron")


func test_activating_a_row_for_an_item_no_longer_in_stock_refreshes_in_place() -> void:
	GameManager.route_context_id = "dagger_iron"
	var screen: Control = AssignEquipmentScene.instantiate()
	add_child_autofree(screen)

	screen._on_row_activated(GameSession.WARRIOR_ID)

	assert_eq(
		GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.weapon,
		GameSession.DEFAULT_WEAPON_ID,
		"An item that was sold elsewhere while this screen was open must not equip"
	)


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	GameManager.route_context_id = "dagger_iron"
	var screen: Control = AssignEquipmentScene.instantiate()
	add_child_autofree(screen)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
