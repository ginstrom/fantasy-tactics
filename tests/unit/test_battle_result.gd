extends GutTest

const BattleResultScene := preload("res://scenes/ui/battle_result.tscn")


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


func test_shows_this_battles_loot_read_live_from_game_session() -> void:
	GameSession.pending_reward = 5
	GameSession.pending_mana_crystals = {1: 2}
	GameSession.pending_gear = ["dagger_iron"]
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
	})

	assert_eq(screen.get_node("Center/VBox/LootLabel").text, tr("battle_result.loot") % [5, 2, 1])


func test_ok_button_returns_to_the_world_map() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/battle_result.gd")

	assert_string_contains(source, "GameManager.go_to_world_map()")


func test_ok_button_clears_the_summary() -> void:
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
	})

	screen.get_node("Center/VBox/OkButton").emit_signal("pressed")

	assert_eq(GameManager.battle_result_summary, {})
