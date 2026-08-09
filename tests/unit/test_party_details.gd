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

	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "party_details.title")
	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


func test_add_member_is_enabled_for_an_encamped_party_with_an_available_adventurer() -> void:
	GameSession.create_party()
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	var add_button: Button = screen.get_node("Body/Center/VBox/AddMemberButton")
	assert_true(add_button.visible, "Add Member must be offered for an encamped party")
	assert_false(add_button.disabled, "An available adventurer exists, so Add Member must be usable")
	assert_eq(add_button.text, "party_details.add_member")


func test_add_member_is_disabled_when_no_adventurer_is_available() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	var add_button: Button = screen.get_node("Body/Center/VBox/AddMemberButton")
	assert_true(add_button.visible)
	assert_true(add_button.disabled, "The only adventurer is already a member of this party")


## Mirrors test_add_member_is_disabled_when_no_adventurer_is_available's
## setup but with the party filled to the level-1 cap (4 members) instead of
## simply having no available adventurer left — Add Member must stay
## disabled once the party itself has no room, not only when the roster is
## exhausted (see design.md's "party is full" UI awareness).
func test_add_member_is_disabled_when_party_is_at_the_level_one_cap() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.recruit_adventurer()
	GameSession.recruit_adventurer()
	GameSession.recruit_adventurer()
	# recruit_adventurer()'s id-collision avoidance skips warrior_002 (still a
	# live recruitment candidate on a fresh session — see
	# GameSession.recruit_adventurer), so three calls mint warrior_003/004/005.
	GameSession.assign_adventurer_to_selected_party("warrior_003")
	GameSession.assign_adventurer_to_selected_party("warrior_004")
	GameSession.assign_adventurer_to_selected_party("warrior_005")
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	var add_button: Button = screen.get_node("Body/Center/VBox/AddMemberButton")
	assert_true(add_button.visible, "Add Member must still be offered even though the party is full")
	assert_true(add_button.disabled, "The party is at the level-1 cap of 4 members")


func test_pressing_add_member_routes_to_the_add_member_screen_with_this_partys_id() -> void:
	GameSession.create_party()
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	screen.get_node("Body/Center/VBox/AddMemberButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, GameSession.FIRST_PARTY_ID)


func test_add_member_is_hidden_entirely_for_a_deployed_party() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	assert_false(
		screen.get_node("Body/Center/VBox/AddMemberButton").visible,
		"You can't add a member to a party that's out in the field"
	)


func test_reads_the_party_id_from_route_context() -> void:
	GameSession.create_party()

	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	assert_eq(screen.party_id, GameSession.FIRST_PARTY_ID)


func test_party_details_shows_gold_and_hides_the_loot_table_for_an_encamped_party() -> void:
	GameSession.create_party()
	GameSession.gold = 250
	# Banked (not pending) loot -- Stores' inventory, not this party's own.
	# An encamped party has already deposited everything it carried; the
	# loot table must not show Stores' inventory here at all.
	GameSession.mana_crystals = {1: 2, 2: 1}
	GameSession.banked_gear = {"dagger_iron": 1, "leather_armor": 2}
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	assert_eq(screen.get_node("Body/Center/VBox/GoldLabel").text, tr("party_details.gold") % 250)
	assert_false(
		screen.get_node("Body/Center/VBox/LootTable").visible,
		"Loot has already banked into Stores by the time a party is back at the Encampment"
	)


func test_party_details_shows_zero_gold_on_a_fresh_session() -> void:
	GameSession.create_party()
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	assert_eq(screen.get_node("Body/Center/VBox/GoldLabel").text, tr("party_details.gold") % 0)


func test_a_deployed_partys_pending_reward_shows_next_to_gold() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	GameSession.pending_reward = 15
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	assert_true(screen.get_node("Body/Center/VBox/PendingRewardLabel").visible)
	assert_eq(
		screen.get_node("Body/Center/VBox/PendingRewardLabel").text,
		tr("information.pending_reward") % 15
	)


func test_pending_reward_row_is_hidden_when_zero_or_the_party_is_encamped() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	var deployed_screen := _open_party_details(GameSession.FIRST_PARTY_ID)
	assert_false(
		deployed_screen.get_node("Body/Center/VBox/PendingRewardLabel").visible,
		"Zero pending reward must not show an empty row"
	)

	GameSession.return_deployed_party_to_settlement()
	GameSession.pending_reward = 5
	var encamped_screen := _open_party_details(GameSession.FIRST_PARTY_ID)
	assert_false(
		encamped_screen.get_node("Body/Center/VBox/PendingRewardLabel").visible,
		"An encamped party must not show a pending reward row even if one is somehow still queued"
	)


func test_a_deployed_partys_loot_table_shows_everything_it_is_carrying() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	GameSession.pending_mana_crystals = {1: 2}
	GameSession.pending_gear = {"dagger_iron": 2}
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Body/Center/VBox/LootTable/Content/Table/Tree")

	assert_true(screen.get_node("Body/Center/VBox/LootTable").visible)
	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Iron Dagger", "Mana Crystal (Tier 1)"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 2), ["2", "2"])


## LootTable no longer puts Sell/Equip in per-row Tree buttons -- selecting
## a row and clicking [View] (or double-clicking it) opens LootDetailPanel,
## a real PanelContainer with real, text-labeled Sell/Equip buttons (see
## scripts/ui/loot_table.gd/loot_detail_panel.gd; this redesign landed
## during Step 4's manual verification, after this step was originally
## drafted). configure(false, true) means the detail panel's Equip button
## shows for a gear row and its Sell button never does.
func test_deployed_loot_table_has_an_equip_action_but_no_sell_action() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	GameSession.pending_gear = {"dagger_iron": 1}
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Body/Center/VBox/LootTable/Content/Table/Tree")
	var item := tree.get_root().get_first_child()
	item.select(0)
	tree.emit_signal("item_selected")
	screen.get_node("Body/Center/VBox/LootTable/Content/ViewButton").emit_signal("pressed")

	var detail_panel: Control = screen.get_node("Body/Center/VBox/LootTable/LootDetailPanel")
	assert_true(detail_panel.visible)
	assert_true(detail_panel.get_node("Content/ButtonRow/EquipButton").visible)
	assert_false(detail_panel.get_node("Content/ButtonRow/SellButton").visible)


func test_equip_routes_via_game_manager_scoped_to_this_party() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/party_details.gd")
	assert_string_contains(source, "GameManager.go_to_assign_equipment(item_id, party_id")
	assert_string_contains(source, "GameManager.AssignEquipmentOrigin.PARTY_DETAILS")


func test_an_empty_party_shows_the_empty_state_without_errors() -> void:
	GameSession.create_party()
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	assert_true(screen.get_node("Body/Center/VBox/EmptyLabel").visible)
	assert_eq(screen.get_node("Body/Center/VBox/EmptyLabel").text, "party_details.no_members")
	var tree: Tree = screen.get_node("Body/Center/VBox/MemberTable/Tree")
	assert_eq(UiTestHelpers.tree_row_values(tree, 0), [] as Array[String])


## Column titles are resolved via tr() (see party_details.gd) to the real
## English copy in translations/en.tres (Name/Class/Level — see the
## migration brief).
func test_party_details_table_uses_the_documented_columns() -> void:
	GameSession.create_party()
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Body/Center/VBox/MemberTable/Tree")

	assert_eq(tree.columns, 3)
	assert_eq(tree.get_column_title(0), "Name")
	assert_eq(tree.get_column_title(1), "Class")
	assert_eq(tree.get_column_title(2), "Level")


func test_every_member_renders_as_a_row_with_name_class_and_level() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Body/Center/VBox/MemberTable/Tree")

	assert_false(screen.get_node("Body/Center/VBox/EmptyLabel").visible)
	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Warrior"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 1), ["warrior"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 2), ["1"])


func test_selecting_a_member_row_refreshes_the_panels_adventurer_context() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/MemberTable/Tree")
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
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/MemberTable/Tree")
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
	var tree: Tree = screen.get_node("Body/Center/VBox/MemberTable/Tree")
	tree.get_root().get_first_child().select(0)

	tree.emit_signal("item_activated")

	assert_eq(GameManager.route_context_id, GameSession.WARRIOR_ID)


func test_a_refresh_that_invalidates_the_selection_clears_it() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/MemberTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")
	assert_eq(screen.selected_adventurer_id, GameSession.WARRIOR_ID)

	GameSession.reset()
	screen.refresh()

	assert_eq(screen.selected_adventurer_id, "")
	assert_false(panel.get_node("Content/AdventurerName").visible)


func test_an_unknown_party_id_does_not_crash_and_shows_no_members() -> void:
	var screen := _open_party_details("no_such_party")
	var tree: Tree = screen.get_node("Body/Center/VBox/MemberTable/Tree")

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

	screen.get_node("Body/Center/VBox/BackButton").emit_signal("pressed")

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

	screen.get_node("Body/Center/VBox/BackButton").emit_signal("pressed")

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
