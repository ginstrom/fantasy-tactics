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


func test_create_party_wraps_the_one_party_session_contract_without_routing() -> void:
	GameSession.reset()
	GameManager.route_context_id = "existing_context"

	assert_eq(GameManager.create_party(), OK)
	assert_eq(GameManager.create_party(), ERR_INVALID_DATA)
	assert_eq(GameSession.parties.size(), 1)
	assert_eq(GameSession.selected_party_id, GameSession.FIRST_PARTY_ID)
	assert_eq(GameManager.route_context_id, "existing_context")
	GameManager.route_context_id = ""


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


func test_units_route_points_to_the_units_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/units.tscn")
	assert_string_contains(source, "func go_to_units()")


func test_parties_route_points_to_the_parties_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/parties.tscn")
	assert_string_contains(source, "func go_to_parties()")


func test_party_details_route_points_to_the_party_details_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/party_details.tscn")
	assert_string_contains(source, "func go_to_party_details(")


func test_unit_details_route_points_to_the_unit_details_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/unit_details.tscn")
	assert_string_contains(source, "func go_to_unit_details(")


func test_deploy_party_route_points_to_the_deploy_party_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/deploy_party.tscn")
	assert_string_contains(source, "func go_to_deploy_party()")


func test_route_context_id_starts_empty() -> void:
	GameSession.reset()

	assert_eq(GameManager.route_context_id, "")


func test_going_to_party_details_with_an_unknown_id_is_invalid_and_leaves_the_route_context_empty() -> void:
	GameSession.reset()

	var err: Error = GameManager.go_to_party_details("no_such_party")

	assert_ne(err, OK, "An unknown party id must not be treated as a valid route")
	assert_eq(GameManager.route_context_id, "")


func test_going_to_unit_details_with_an_unknown_id_is_invalid_and_leaves_the_route_context_empty() -> void:
	GameSession.reset()

	var err: Error = GameManager.go_to_unit_details("no_such_adventurer")

	assert_ne(err, OK, "An unknown adventurer id must not be treated as a valid route")
	assert_eq(GameManager.route_context_id, "")


func test_deploy_party_route_reuses_the_world_map_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "func deploy_party(")
	assert_string_contains(source, "GameSession.deploy_party(")


func test_deploy_party_reports_invalid_data_for_an_ineligible_party_and_does_not_deploy_it() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.deploy_party("no_such_party")

	assert_ne(err, OK, "An ineligible party id must not be treated as a valid deployment")
	assert_false(GameSession.has_deployed_party())


func test_deploy_party_deploys_the_selected_party_before_routing_to_the_world_map() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.deploy_party(GameSession.FIRST_PARTY_ID)

	assert_eq(err, OK)
	assert_true(GameSession.has_deployed_party())
	assert_eq(GameSession.selected_party_id, GameSession.FIRST_PARTY_ID)


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


func test_add_member_route_points_to_the_add_member_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/add_member.tscn")
	assert_string_contains(source, "func go_to_add_member(")


func test_going_to_add_member_with_an_unknown_party_id_is_invalid_and_leaves_the_route_context_empty() -> void:
	GameSession.reset()

	var err: Error = GameManager.go_to_add_member("no_such_party")

	assert_ne(err, OK, "An unknown party id must not be treated as a valid route")
	assert_eq(GameManager.route_context_id, "")


func test_going_to_add_member_with_a_known_party_id_sets_the_route_context() -> void:
	GameSession.reset()
	GameSession.create_party()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.go_to_add_member(GameSession.FIRST_PARTY_ID)

	assert_eq(err, OK)
	assert_eq(manager.route_context_id, GameSession.FIRST_PARTY_ID)


func test_assign_adventurer_to_party_reports_invalid_data_for_an_unknown_adventurer() -> void:
	GameSession.reset()
	GameSession.create_party()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.assign_adventurer_to_party(GameSession.FIRST_PARTY_ID, "no_such_adventurer")

	assert_ne(err, OK)
	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [] as Array[String])


func test_assign_adventurer_to_party_assigns_the_named_adventurer_to_the_named_party() -> void:
	GameSession.reset()
	GameSession.create_party()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.assign_adventurer_to_party(GameSession.FIRST_PARTY_ID, GameSession.WARRIOR_ID)

	assert_eq(err, OK)
	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [GameSession.WARRIOR_ID])


func test_recruit_adventurer_appends_a_new_adventurer_to_the_roster() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.recruit_adventurer()

	assert_eq(err, OK)
	assert_eq(GameSession.adventurers.size(), 2)
	# warrior_002/003/004 are live, unpurchased recruitment candidates on a
	# fresh session, so the debug recruit's id-collision avoidance (see
	# GameSession.recruit_adventurer) skips all three.
	assert_eq(GameSession.adventurers[1].id, "warrior_005")


func test_debug_scenario_target_maps_party_empty_to_the_encampment() -> void:
	assert_eq(GameManager.debug_scenario_target("party_empty"), GameManager.DebugTarget.ENCAMPMENT)


func test_roster_route_points_to_the_roster_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/roster.tscn")
	assert_string_contains(source, "func go_to_roster()")


func test_recruitment_route_points_to_the_recruitment_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/recruitment.tscn")
	assert_string_contains(source, "func go_to_recruitment()")


func test_go_to_roster_clears_stale_route_context_before_changing_scene() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.route_context_id = "stale_id"
	manager.unit_details_origin = manager.UNIT_DETAILS_ORIGIN_ROSTER

	var err: Error = manager.go_to_roster()

	assert_eq(err, OK)
	assert_eq(manager.route_context_id, "")
	assert_eq(manager.unit_details_origin, "")


func test_go_to_unit_details_from_roster_sets_route_context_and_marks_the_roster_origin() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.go_to_unit_details_from_roster(GameSession.WARRIOR_ID)

	assert_eq(err, OK)
	assert_eq(manager.route_context_id, GameSession.WARRIOR_ID)
	assert_eq(manager.unit_details_origin, manager.UNIT_DETAILS_ORIGIN_ROSTER)


func test_going_to_unit_details_from_roster_with_an_unknown_id_is_invalid_and_clears_both_fields() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.route_context_id = "stale_id"
	manager.unit_details_origin = manager.UNIT_DETAILS_ORIGIN_ROSTER

	var err: Error = manager.go_to_unit_details_from_roster("no_such_adventurer")

	assert_ne(err, OK, "An unknown adventurer id must not be treated as a valid route")
	assert_eq(manager.route_context_id, "")
	assert_eq(manager.unit_details_origin, "")


func test_go_to_unit_details_clears_a_stale_roster_origin_flag() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.unit_details_origin = manager.UNIT_DETAILS_ORIGIN_ROSTER

	var err: Error = manager.go_to_unit_details(GameSession.WARRIOR_ID)

	assert_eq(err, OK)
	assert_eq(
		manager.unit_details_origin,
		"",
		"The pre-Roster entry path must never leave a stale roster origin behind"
	)


func test_go_to_recruitment_clears_stale_route_context_before_changing_scene() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.route_context_id = "stale_id"

	var err: Error = manager.go_to_recruitment()

	assert_eq(err, OK)
	assert_eq(manager.route_context_id, "")


func test_purchase_recruit_reports_invalid_data_for_an_unknown_candidate() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.purchase_recruit("no_such_candidate")

	assert_ne(err, OK, "An unknown candidate id must not be treated as a valid purchase")
	assert_eq(GameSession.adventurers.size(), 1)


func test_purchase_recruit_reports_invalid_data_when_funds_are_insufficient() -> void:
	GameSession.reset()
	GameSession.gold = 0
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.purchase_recruit("warrior_002")

	assert_ne(err, OK)
	assert_eq(GameSession.adventurers.size(), 1)
	assert_eq(GameSession.get_recruitment_candidates().size(), 3)


func test_purchase_recruit_deducts_gold_removes_the_candidate_and_adds_the_adventurer() -> void:
	GameSession.reset()
	GameSession.gold = 10
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.purchase_recruit("warrior_002")

	assert_eq(err, OK)
	assert_eq(GameSession.gold, 0)
	assert_eq(GameSession.adventurers.size(), 2)
	assert_eq(GameSession.adventurers[1].id, "warrior_002")
	assert_eq(GameSession.get_recruitment_candidates().size(), 2)
