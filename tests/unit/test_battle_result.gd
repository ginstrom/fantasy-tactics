extends GutTest

const BattleResultScene := preload("res://scenes/ui/battle_result.tscn")
const UiTestHelpers := preload("res://tests/unit/ui_test_helpers.gd")


func before_each() -> void:
	GameSession.reset()
	GameManager.battle_result_summary = {}


func after_each() -> void:
	GameManager.battle_result_summary = {}


func _open_battle_result(summary: Dictionary) -> Control:
	GameManager.battle_result_summary = summary
	var screen: Control = BattleResultScene.instantiate()
	add_child_autofree(screen)
	return screen


func test_shows_kills_grouped_by_type() -> void:
	var screen := _open_battle_result({
		"kills_by_type": {"Goblin": 2, "Orc": 1}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
	})

	assert_true(
		screen.get_node("Center/VBox/KillsLabel").text.contains("Goblin x2")
		and screen.get_node("Center/VBox/KillsLabel").text.contains("Orc x1")
	)


func test_shows_no_kills_message_when_nothing_was_killed() -> void:
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
	})

	assert_eq(screen.get_node("Center/VBox/KillsLabel").text, tr("battle_result.no_kills"))


func test_shows_total_and_per_member_xp() -> void:
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 20.0, "party_member_count": 2, "leveled_up_ids": [],
	})

	assert_eq(screen.get_node("Center/VBox/XpLabel").text, tr("battle_result.xp") % [20, 10])


func test_hides_the_leveled_up_row_when_nobody_leveled_up() -> void:
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
	})

	assert_false(screen.get_node("Center/VBox/LevelUpLabel").visible)


func test_shows_the_leveled_up_members_names_when_present() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1,
		"leveled_up_ids": [GameSession.WARRIOR_ID],
	})

	assert_true(screen.get_node("Center/VBox/LevelUpLabel").visible)
	assert_eq(screen.get_node("Center/VBox/LevelUpLabel").text, tr("battle_result.leveled_up") % "Warrior")


func test_shows_the_battles_gold() -> void:
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
		"loot_gold": 5,
	})

	assert_eq(screen.get_node("Center/VBox/GoldLabel").text, tr("battle_result.gold") % 5)


func test_shows_this_battles_loot_as_a_table() -> void:
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
		"loot_gear_counts": {"shortsword_iron": 1}, "loot_mana_crystal_counts": {1: 2},
	})
	var tree: Tree = screen.get_node("Center/VBox/LootTable/Content/Table/Tree")

	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Iron Shortsword", "Mana Crystal (Tier 1)"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 2), ["1", "2"])


## LootTable no longer puts Sell/Equip in per-row Tree buttons -- selecting
## a row and clicking [View] (or double-clicking it) opens LootDetailPanel,
## a real PanelContainer with real, text-labeled Sell/Equip buttons (see
## scripts/ui/loot_table.gd/loot_detail_panel.gd; this redesign landed
## during Step 4's manual verification, after this step was originally
## drafted). configure(false, true) means the detail panel's Equip button
## shows for a gear row and its Sell button never does.
func test_loot_table_has_an_equip_action_but_no_sell_action() -> void:
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
		"loot_gear_counts": {"shortsword_iron": 1},
	})
	var tree: Tree = screen.get_node("Center/VBox/LootTable/Content/Table/Tree")
	var item := tree.get_root().get_first_child()
	item.select(0)
	tree.emit_signal("item_selected")
	screen.get_node("Center/VBox/LootTable/Content/ViewButton").emit_signal("pressed")

	var detail_panel: Control = screen.get_node("Center/VBox/LootTable/LootDetailPanel")
	assert_true(detail_panel.visible)
	assert_true(detail_panel.get_node("Content/ButtonRow/EquipButton").visible)
	assert_false(detail_panel.get_node("Content/ButtonRow/SellButton").visible)


func test_equip_routes_via_game_manager_scoped_to_this_battles_party() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/battle_result.gd")
	assert_string_contains(source, "GameManager.go_to_assign_equipment(")
	assert_string_contains(source, "GameManager.AssignEquipmentOrigin.BATTLE_RESULT")


func test_ok_button_returns_to_the_world_map() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/battle_result.gd")

	assert_string_contains(source, "GameManager.go_to_world_map()")


func test_ok_button_clears_the_summary() -> void:
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
	})

	screen.get_node("Center/VBox/OkButton").emit_signal("pressed")

	assert_eq(GameManager.battle_result_summary, {})
