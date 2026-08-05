extends GutTest


func after_each() -> void:
	# A failed assertion in an open_game_menu test can skip its manual
	# close_game_menu() cleanup, leaving the tree paused for later tests.
	get_tree().paused = false


func test_battle_route_uses_battlefield_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(
		source,
		"res://scenes/battle/battlefield.tscn",
		"The tactical route must use the battle-domain scene"
	)


func test_party_manager_and_encampment_routes_are_available() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "open_party_manager()")
	assert_string_contains(source, "go_to_encampment()")
	assert_string_contains(source, "res://scenes/ui/encampment.tscn")


func test_start_menu_route_uses_start_menu_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/start_menu.tscn")
	assert_string_contains(source, "go_to_start_menu()")


func test_new_game_routes_to_starting_settlement() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/local/starting_settlement.tscn")


func test_debug_scenario_target_maps_known_ids() -> void:
	assert_eq(GameManager.debug_scenario_target("encampment"), GameManager.DebugTarget.ENCAMPMENT)
	assert_eq(GameManager.debug_scenario_target("party_manager"), GameManager.DebugTarget.PARTY_MANAGER)
	assert_eq(GameManager.debug_scenario_target("world_map"), GameManager.DebugTarget.WORLD_MAP)
	assert_eq(GameManager.debug_scenario_target("goblin_camp"), GameManager.DebugTarget.BATTLEFIELD)
	assert_eq(GameManager.debug_scenario_target("orc_outpost"), GameManager.DebugTarget.BATTLEFIELD)
	assert_eq(GameManager.debug_scenario_target("unknown"), GameManager.DebugTarget.NONE)


func test_running_goblin_camp_scenario_selects_the_encounter_before_battle_route() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	assert_eq(manager.run_debug_scenario("goblin_camp"), OK)
	assert_eq(GameSession.selected_encounter, GameSession.GOBLIN_CAMP_ID)


func test_running_orc_outpost_scenario_selects_the_outpost_before_battle_route() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	assert_eq(manager.run_debug_scenario("orc_outpost"), OK)
	assert_eq(GameSession.selected_encounter, GameSession.ORC_OUTPOST_ID)


func test_depart_selected_party_deploys_before_changing_scene() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.depart_selected_party()

	assert_true(GameSession.has_deployed_party())


func test_return_party_to_encampment_returns_party_and_deposits_reward() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.pending_reward = 15
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.return_party_to_encampment()

	assert_false(GameSession.has_deployed_party())
	assert_eq(GameSession.gold, 15, "Returning to the encampment must bank any queued reward")


func test_go_to_encampment_deposits_pending_gold_once() -> void:
	GameSession.reset()
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	GameSession.complete_current_encounter()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.go_to_encampment()

	assert_eq(GameSession.gold, 10, "Entering the encampment must bank the queued reward")
	assert_eq(GameSession.pending_reward, 0)

	manager.go_to_encampment()

	assert_eq(GameSession.gold, 10, "A second visit must not pay the reward again")
	assert_eq(GameSession.pending_reward, 0)


func test_fail_battle_abandons_the_encounter_and_returns_the_party_home() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.enter_encounter("goblin_camp")
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.fail_battle()

	assert_false(GameSession.has_deployed_party())
	assert_eq(GameSession.selected_encounter, "")
	assert_false(GameSession.is_encounter_complete("goblin_camp"))


func test_apply_super_power_reports_unavailable_without_an_active_battlefield() -> void:
	assert_eq(GameManager.apply_super_power(), ERR_UNAVAILABLE)


func test_apply_super_power_maxes_out_player_units_on_the_active_battlefield() -> void:
	GameSession.reset()
	var battlefield: Node2D = preload("res://scenes/battle/battlefield.tscn").instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(Vector2i(1, 1))

	assert_eq(GameManager.apply_super_power(), OK)

	assert_eq(warrior.move_range, 100)
	assert_eq(warrior.attack_damage, 100)
	assert_eq(warrior.hit_chance, 1.0)


func test_change_scene_reports_error_for_missing_scene() -> void:
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager._change_scene("res://scenes/missing_scene.tscn")

	assert_ne(err, OK, "Missing scene should return an Error")
	assert_push_error("missing_scene.tscn")
	# Missing resources also emit engine load errors; those are expected here.
	for tracked in get_errors():
		tracked.handled = true


func test_open_game_menu_shows_the_overlay_and_pauses_the_tree() -> void:
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.open_game_menu()

	assert_true(manager.is_game_menu_open())
	assert_true(get_tree().paused)

	manager.close_game_menu()


func test_close_game_menu_hides_the_overlay_and_unpauses_the_tree() -> void:
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.open_game_menu()

	manager.close_game_menu()

	assert_false(manager.is_game_menu_open())
	assert_false(get_tree().paused)
