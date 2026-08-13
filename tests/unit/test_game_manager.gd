extends GutTest

const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const SaveRepositoryScript := preload("res://scripts/save/save_repository.gd")
const TEST_SAVE_PATH := "user://test_game_manager_campaign.json"


## A minimal double exposing the same save_campaign()/load_campaign()/
## has_valid_save() surface as SaveRepository (see GameManager.
## save_repository's own doc comment), used by the boundary-guard tests
## below so they can prove exactly whether the repository was ever asked to
## write -- without touching real disk I/O the way a real SaveRepository
## pointed at TEST_SAVE_PATH would.
class FakeSaveRepository extends RefCounted:
	var save_called: bool = false
	var save_result: Dictionary = {"ok": true, "error": ""}

	func save_campaign(_session: Object) -> Dictionary:
		save_called = true
		return save_result

	func load_campaign(_session: Object) -> Dictionary:
		return {"ok": false, "snapshot": {}, "error": "not used by these tests", "status": SaveRepositoryScript.LoadStatus.ABSENT}

	func has_valid_save() -> bool:
		return false


func after_each() -> void:
	# A failed assertion in an open_game_menu test can skip its manual
	# close_game_menu() cleanup, leaving the tree paused for later tests.
	get_tree().paused = false
	GameManager.add_member_return_party_id = ""
	GameManager.battle_result_summary = {}
	GameManager.create_party_on_open = false
	GameSession.loot_gold_roll = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
	GameSession.loot_gear_roll = func() -> float: return randf()

	# Save-related tests inject a repository pointed at TEST_SAVE_PATH instead
	# of the real campaign-save.json; put GameManager back on a fresh default
	# repository and remove any file this run may have left behind so no test
	# leaks save state into another.
	GameManager.save_repository = SaveRepositoryScript.new()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


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


func test_create_party_passes_the_given_name_through_to_game_session() -> void:
	GameSession.reset()

	GameManager.create_party("Alpha Party")

	assert_eq(GameSession.parties[0].name, "Alpha Party")


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


func test_go_to_world_map_merges_the_battle_store_into_the_party_store() -> void:
	GameSession.reset()
	GameSession.battle_reward = 5
	GameSession.battle_mana_crystals = {1: 1}
	GameSession.battle_gear = {"dagger_iron": 1}
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.go_to_world_map()

	assert_eq(GameSession.pending_reward, 5)
	assert_eq(GameSession.pending_mana_crystals, {1: 1})
	assert_eq(GameSession.pending_gear, {"dagger_iron": 1})
	assert_eq(GameSession.battle_reward, 0)
	assert_eq(GameSession.battle_mana_crystals, {})
	assert_eq(GameSession.battle_gear, {})


func test_go_to_encampment_deposits_pending_gold_once() -> void:
	GameSession.reset()
	GameSession.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	GameSession.loot_gear_roll = func() -> float: return 1.0
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	GameSession.complete_current_encounter()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.go_to_world_map()

	manager.go_to_encampment()

	assert_eq(GameSession.gold, 20, "Entering the encampment must bank the queued reward")
	assert_eq(GameSession.pending_reward, 0)

	manager.go_to_encampment()

	assert_eq(GameSession.gold, 20, "A second visit must not pay the reward again")
	assert_eq(GameSession.pending_reward, 0)




func test_go_to_encampment_does_not_bank_the_reward_while_the_party_is_still_deployed() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	GameSession.complete_current_encounter()
	var queued_reward: int = GameSession.battle_reward
	assert_true(queued_reward > 0, "Test setup must actually queue a reward")
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.go_to_encampment()

	assert_eq(GameSession.gold, 0, "Gold must not be banked while the party is still deployed away from home")
	assert_eq(
		GameSession.battle_reward, queued_reward,
		"The queued reward must remain untouched until the party actually returns"
	)
	assert_true(
		GameSession.has_deployed_party(),
		"CampNav's Encampment shortcut must not silently return the party"
	)


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
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	assert_eq(GameManager.apply_super_power(), OK)

	assert_eq(warrior.max_action_points, BattleControllerScript.SUPER_POWER_ACTION_POINTS)
	assert_eq(warrior.damage_min, 100)
	assert_eq(warrior.damage_max, 100)
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
	assert_string_contains(source, "func go_to_parties(")



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
	assert_eq(GameSession.adventurers.size(), 5)
	assert_false(GameSession.adventurers[4].id.is_empty())


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


func test_buildings_route_points_to_the_buildings_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/buildings.tscn")
	assert_string_contains(source, "func go_to_buildings()")


func test_guild_hall_route_points_to_the_guild_hall_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/guild_hall.tscn")
	assert_string_contains(source, "func go_to_guild_hall()")


func test_blacksmith_route_points_to_the_blacksmith_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/blacksmith.tscn")
	assert_string_contains(source, "func go_to_blacksmith()")


func test_alchemy_workshop_route_points_to_its_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/alchemy_workshop.tscn")
	assert_string_contains(source, "func go_to_alchemy_workshop()")


func test_runic_workshop_route_points_to_its_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/runic_workshop.tscn")
	assert_string_contains(source, "func go_to_runic_workshop()")


func test_entering_buildings_clears_a_stale_route_context_id() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.route_context_id = "stale_id"

	var err: Error = manager.go_to_buildings()

	assert_eq(err, OK)
	assert_eq(manager.route_context_id, "")


func test_entering_guild_hall_clears_a_stale_route_context_id() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.route_context_id = "stale_id"

	var err: Error = manager.go_to_guild_hall()

	assert_eq(err, OK)
	assert_eq(manager.route_context_id, "")


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


func test_go_to_unit_details_from_add_member_preserves_a_valid_return_party() -> void:
	GameSession.reset()
	GameSession.create_party()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	assert_eq(
		manager.go_to_unit_details_from_add_member(GameSession.WARRIOR_ID, GameSession.FIRST_PARTY_ID), OK
	)
	assert_eq(manager.route_context_id, GameSession.WARRIOR_ID)
	assert_eq(manager.unit_details_origin, manager.UNIT_DETAILS_ORIGIN_ADD_MEMBER)
	assert_eq(manager.add_member_return_party_id, GameSession.FIRST_PARTY_ID)


func test_go_to_unit_details_from_add_member_rejects_missing_live_records_and_clears_context() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.route_context_id = "stale"
	manager.unit_details_origin = "stale"
	manager.add_member_return_party_id = "stale"

	assert_eq(manager.go_to_unit_details_from_add_member(GameSession.WARRIOR_ID, "missing_party"), ERR_INVALID_DATA)
	assert_eq(manager.route_context_id, "")
	assert_eq(manager.unit_details_origin, "")
	assert_eq(manager.add_member_return_party_id, "")


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
	assert_eq(GameSession.adventurers.size(), 4)


func test_purchase_recruit_reports_invalid_data_when_funds_are_insufficient() -> void:
	GameSession.reset()
	GameSession.gold = 0
	var cand_id := str(GameSession.recruitment_candidates[0].id)
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.purchase_recruit(cand_id)

	assert_ne(err, OK)
	assert_eq(GameSession.adventurers.size(), 4)
	assert_eq(GameSession.get_recruitment_candidates().size(), 4)


func test_purchase_recruit_deducts_gold_removes_the_candidate_and_adds_the_adventurer() -> void:
	GameSession.reset()
	GameSession.gold = 10
	var cand_id := str(GameSession.recruitment_candidates[0].id)
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.purchase_recruit(cand_id)

	assert_eq(err, OK)
	assert_eq(GameSession.gold, 0)
	assert_eq(GameSession.adventurers.size(), 5)
	assert_eq(GameSession.adventurers[4].id, cand_id)
	assert_eq(GameSession.get_recruitment_candidates().size(), 3)


func test_targeted_purchase_keeps_an_eligible_party_as_the_recruitment_target() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.gold = 10
	var cand_id := str(GameSession.recruitment_candidates[0].id)
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	autofree(manager)
	manager.recruitment_target_party_id = GameSession.FIRST_PARTY_ID

	assert_eq(manager.purchase_recruit_for_target_party(cand_id), OK)
	assert_eq(manager.recruitment_target_party_id, GameSession.FIRST_PARTY_ID)


func test_targeted_purchase_clears_a_party_target_that_becomes_full() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.adventurers[0].id)
	GameSession.assign_adventurer_to_selected_party(GameSession.adventurers[1].id)
	GameSession.assign_adventurer_to_selected_party(GameSession.adventurers[2].id)
	GameSession.gold = 10
	var cand_id := str(GameSession.recruitment_candidates[0].id)
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	autofree(manager)
	manager.recruitment_target_party_id = GameSession.FIRST_PARTY_ID

	assert_eq(manager.purchase_recruit_for_target_party(cand_id), OK)
	assert_eq(manager.recruitment_target_party_id, "")


func test_go_to_trade_changes_scene_and_clears_detail_context() -> void:
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.route_context_id = "stale"

	assert_eq(manager.go_to_trade(), OK)
	assert_eq(manager.route_context_id, "")


func test_go_to_stores_changes_scene() -> void:
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	assert_eq(manager.go_to_stores(), OK)


func test_go_to_trading_post_changes_scene() -> void:
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	assert_eq(manager.go_to_trading_post(), OK)


func test_go_to_assign_equipment_sets_route_context_and_changes_scene_for_a_known_item() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	assert_eq(manager.go_to_assign_equipment("dagger_iron"), OK)
	assert_eq(manager.route_context_id, "dagger_iron")


func test_go_to_assign_equipment_rejects_an_unknown_item_id() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.route_context_id = "stale"

	assert_eq(manager.go_to_assign_equipment("no_such_item"), ERR_INVALID_DATA)
	assert_eq(manager.route_context_id, "")


func test_go_to_assign_equipment_with_a_party_id_scopes_and_records_the_origin() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	assert_eq(
		manager.go_to_assign_equipment(
			"dagger_iron", GameSession.FIRST_PARTY_ID, manager.AssignEquipmentOrigin.PARTY_DETAILS
		),
		OK
	)
	assert_eq(manager.route_context_id, "dagger_iron")
	assert_eq(manager.assign_equipment_party_id, GameSession.FIRST_PARTY_ID)
	assert_eq(manager.assign_equipment_origin, manager.AssignEquipmentOrigin.PARTY_DETAILS)


func test_go_to_assign_equipment_rejects_an_unknown_party_id() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.assign_equipment_party_id = "stale"

	assert_eq(manager.go_to_assign_equipment("dagger_iron", "no_such_party"), ERR_INVALID_DATA)
	assert_eq(manager.assign_equipment_party_id, "")


func test_go_to_assign_equipment_defaults_to_the_stores_origin_and_no_party_scope() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.go_to_assign_equipment("dagger_iron")

	assert_eq(manager.assign_equipment_party_id, "")
	assert_eq(manager.assign_equipment_origin, manager.AssignEquipmentOrigin.STORES)


func test_go_to_battle_result_stores_the_summary_dictionary() -> void:
	var summary := {"kills_by_type": {"Goblin": 1}, "total_xp": 15.0, "party_member_count": 1, "leveled_up_ids": []}

	GameManager.go_to_battle_result(summary)

	assert_eq(GameManager.battle_result_summary, summary)


func test_battle_result_summary_starts_empty() -> void:
	assert_eq(GameManager.battle_result_summary, {})


## --- Save/load wrappers (Step 2 -- see docs/plans/2026-08-10-initial- ------
## --- campaign-and-automation/02-atomic-save-repository.md). These tests ---
## --- only prove GameManager delegates to an injectable SaveRepository ----
## --- instead of ever touching FileAccess/DirAccess itself. The boundary --
## --- guard and routing decision tests are below, in the Step 3 section. --


func test_game_manager_source_never_touches_file_or_dir_access_directly() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_false(source.contains("FileAccess"), "UI/manager code must go through SaveRepository, never FileAccess directly")
	assert_false(source.contains("DirAccess"), "UI/manager code must go through SaveRepository, never DirAccess directly")


func test_save_repository_is_test_injectable() -> void:
	var repository := SaveRepositoryScript.new(TEST_SAVE_PATH)

	GameManager.save_repository = repository

	assert_eq(GameManager.save_repository.save_path, TEST_SAVE_PATH)


func test_save_current_campaign_delegates_to_the_injected_repository() -> void:
	GameSession.reset()
	GameSession.gold = 77
	GameManager.save_repository = SaveRepositoryScript.new(TEST_SAVE_PATH)

	var result: Dictionary = GameManager.save_current_campaign()

	assert_true(result.ok, result.get("error", ""))
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH))
	var json := JSON.new()
	assert_eq(json.parse(FileAccess.get_file_as_string(TEST_SAVE_PATH)), OK)
	assert_eq(json.data.gold, 77)


func test_load_current_campaign_imports_into_game_session_via_the_injected_repository() -> void:
	GameSession.reset()
	var writer_repository := SaveRepositoryScript.new(TEST_SAVE_PATH)
	var writer_session: Node = preload("res://scripts/autoload/game_session.gd").new()
	autofree(writer_session)
	writer_session.gold = 123
	writer_repository.save_campaign(writer_session)
	GameSession.reset()
	GameManager.save_repository = writer_repository

	var result: Dictionary = GameManager.load_current_campaign()

	assert_true(result.ok, result.get("error", ""))
	assert_eq(GameSession.gold, 123)


func test_load_current_campaign_never_mutates_game_session_when_the_repository_load_fails() -> void:
	GameSession.reset()
	GameSession.gold = 5
	GameManager.save_repository = SaveRepositoryScript.new(TEST_SAVE_PATH)

	var result: Dictionary = GameManager.load_current_campaign()

	assert_false(result.ok)
	assert_eq(GameSession.gold, 5)


func test_has_valid_save_reflects_the_injected_repository() -> void:
	GameManager.save_repository = SaveRepositoryScript.new(TEST_SAVE_PATH)

	assert_false(GameManager.has_valid_save())

	GameSession.reset()
	GameManager.save_current_campaign()

	assert_true(GameManager.has_valid_save())


## --- Save boundaries and the resume-a-campaign decision (Step 3 -- see ----
## --- docs/plans/2026-08-10-initial-campaign-and-automation/ ---------------
## --- 03-save-boundaries-and-menu.md). can_save_current_campaign()/ --------
## --- save_current_campaign() are tested against a FakeSaveRepository so ---
## --- "no write happened" is a cheap, deterministic assertion rather than --
## --- an absence-of-a-file check; go_to_loaded_campaign()'s routing --------
## --- decision is tested against a real (throwaway-path) SaveRepository ----
## --- since it needs an actual round trip to prove which branch fired. -----


func test_can_save_current_campaign_is_true_outside_an_active_encounter() -> void:
	GameSession.reset()

	assert_true(GameManager.can_save_current_campaign())


func test_can_save_current_campaign_is_false_during_an_active_encounter() -> void:
	GameSession.reset()
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)

	assert_false(GameManager.can_save_current_campaign())

	GameSession.abandon_current_encounter()


## complete_current_encounter() clears selected_encounter *before* battle_
## reward/battle_gear/battle_mana_crystals are merged into the party (that
## happens later, in go_to_world_map()) -- so on the Battle Result screen,
## selected_encounter == "" even though this battle's loot has not yet been
## settled. can_save_current_campaign() must not rely solely on
## selected_encounter to cover this window; see GameSession.
## has_unsettled_battle_loot().
func test_can_save_current_campaign_is_false_when_battle_loot_is_unsettled() -> void:
	GameSession.reset()
	GameSession.battle_reward = 5

	assert_eq(GameSession.selected_encounter, "", "Sanity check: no active encounter is blocking the save")
	assert_false(GameManager.can_save_current_campaign())


func test_can_save_current_campaign_is_true_again_once_unsettled_battle_loot_is_merged() -> void:
	GameSession.reset()
	GameSession.battle_reward = 5
	GameSession.merge_battle_loot_into_party()

	assert_true(GameManager.can_save_current_campaign())


func test_save_current_campaign_makes_no_write_during_an_active_encounter() -> void:
	GameSession.reset()
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var fake := FakeSaveRepository.new()
	GameManager.save_repository = fake

	var result: Dictionary = GameManager.save_current_campaign()

	assert_false(result.ok)
	assert_false(fake.save_called, "A blocked save must never reach the repository")
	GameSession.abandon_current_encounter()


func test_save_current_campaign_writes_when_no_encounter_is_active() -> void:
	GameSession.reset()
	var fake := FakeSaveRepository.new()
	GameManager.save_repository = fake

	var result: Dictionary = GameManager.save_current_campaign()

	assert_true(result.ok)
	assert_true(fake.save_called)


func test_successful_save_does_not_change_reward_buckets() -> void:
	GameSession.reset()
	GameSession.gold = 42
	GameSession.pending_reward = 7
	GameSession.mana_crystals = {1: 3}
	GameSession.banked_gear = {"dagger_iron": 2}
	GameManager.save_repository = FakeSaveRepository.new()

	GameManager.save_current_campaign()

	assert_eq(GameSession.gold, 42)
	assert_eq(GameSession.pending_reward, 7)
	assert_eq(GameSession.mana_crystals, {1: 3})
	assert_eq(GameSession.banked_gear, {"dagger_iron": 2})


func test_go_to_loaded_campaign_routes_to_the_world_map_for_a_deployed_party() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	var writer_repository := SaveRepositoryScript.new(TEST_SAVE_PATH)
	writer_repository.save_campaign(GameSession)
	GameSession.reset()
	GameManager.save_repository = writer_repository
	GameManager.route_context_id = "stale"

	var result: Dictionary = GameManager.go_to_loaded_campaign()

	assert_true(result.ok, result.get("error", ""))
	assert_true(GameSession.has_deployed_party())
	# go_to_world_map() is the only routing branch that clears
	# route_context_id (via _clear_detail_context()) -- go_to_encampment()
	# never touches it -- so this doubles as proof of which branch fired.
	assert_eq(GameManager.route_context_id, "", "A deployed party must route through go_to_world_map()")
	GameManager.route_context_id = ""


func test_go_to_loaded_campaign_routes_to_the_encampment_for_an_undeployed_party() -> void:
	GameSession.reset()
	var writer_repository := SaveRepositoryScript.new(TEST_SAVE_PATH)
	writer_repository.save_campaign(GameSession)
	GameSession.reset()
	GameManager.save_repository = writer_repository
	GameManager.route_context_id = "stale"

	var result: Dictionary = GameManager.go_to_loaded_campaign()

	assert_true(result.ok, result.get("error", ""))
	assert_false(GameSession.has_deployed_party())
	assert_eq(
		GameManager.route_context_id, "stale",
		"An undeployed party must route through go_to_encampment(), which never touches route_context_id"
	)
	GameManager.route_context_id = ""


## Reward buckets must be preserved across a load, never additionally
## settled by it -- the same guarantee test_successful_save_does_not_
## change_reward_buckets() proves for the save side. go_to_loaded_campaign()
## calls the underlying routing primitives directly (_clear_detail_context()
## / _change_scene()) rather than go_to_world_map()/go_to_encampment()
## themselves, so this is a structural guarantee, not merely an argument
## about which states a real save can reach: GameSession.
## merge_battle_loot_into_party() and GameSession.deposit_pending_reward()
## are never called from anywhere in the load path, for any state. These
## tests set every reward bucket nonzero -- including combinations (e.g.
## nonzero battle_reward, or nonzero pending_reward on an undeployed party)
## that a real save could probably never actually contain -- specifically to
## prove the guarantee does not depend on reachability.
func test_go_to_loaded_campaign_preserves_settled_reward_buckets_when_routing_to_the_encampment() -> void:
	GameSession.reset()
	GameSession.gold = 10
	GameSession.pending_reward = 12
	GameSession.banked_gear = {"dagger_iron": 3}
	GameSession.mana_crystals = {1: 2}
	GameSession.battle_reward = 3
	GameSession.battle_gear = {"buckler_wood": 1}
	GameSession.battle_mana_crystals = {2: 1}
	var writer_repository := SaveRepositoryScript.new(TEST_SAVE_PATH)
	writer_repository.save_campaign(GameSession)
	GameSession.reset()
	GameManager.save_repository = writer_repository

	var result: Dictionary = GameManager.go_to_loaded_campaign()

	assert_true(result.ok, result.get("error", ""))
	assert_false(GameSession.has_deployed_party(), "Sanity check: this must route through the Encampment branch")
	assert_eq(GameSession.gold, 10)
	assert_eq(GameSession.pending_reward, 12)
	assert_eq(GameSession.banked_gear, {"dagger_iron": 3})
	assert_eq(GameSession.mana_crystals, {1: 2})
	assert_eq(GameSession.battle_reward, 3)
	assert_eq(GameSession.battle_gear, {"buckler_wood": 1})
	assert_eq(GameSession.battle_mana_crystals, {2: 1})


func test_go_to_loaded_campaign_preserves_reward_buckets_when_routing_to_the_world_map() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	GameSession.gold = 5
	GameSession.pending_reward = 25
	GameSession.pending_gear = {"dagger_iron": 1}
	GameSession.pending_mana_crystals = {1: 4}
	GameSession.battle_reward = 7
	GameSession.battle_gear = {"shortsword_iron": 1}
	GameSession.battle_mana_crystals = {1: 1}
	var writer_repository := SaveRepositoryScript.new(TEST_SAVE_PATH)
	writer_repository.save_campaign(GameSession)
	GameSession.reset()
	GameManager.save_repository = writer_repository

	var result: Dictionary = GameManager.go_to_loaded_campaign()

	assert_true(result.ok, result.get("error", ""))
	assert_true(GameSession.has_deployed_party(), "Sanity check: this must route through the World Map branch")
	assert_eq(GameSession.gold, 5)
	assert_eq(GameSession.pending_reward, 25)
	assert_eq(GameSession.pending_gear, {"dagger_iron": 1})
	assert_eq(GameSession.pending_mana_crystals, {1: 4})
	assert_eq(GameSession.battle_reward, 7)
	assert_eq(GameSession.battle_gear, {"shortsword_iron": 1})
	assert_eq(GameSession.battle_mana_crystals, {1: 1})


func test_go_to_loaded_campaign_closes_an_open_pause_menu_on_success() -> void:
	GameSession.reset()
	var writer_repository := SaveRepositoryScript.new(TEST_SAVE_PATH)
	writer_repository.save_campaign(GameSession)
	GameManager.save_repository = writer_repository
	GameManager.open_game_menu()

	GameManager.go_to_loaded_campaign()

	assert_false(GameManager.is_game_menu_open())
	assert_false(get_tree().paused)


func test_go_to_loaded_campaign_leaves_game_session_and_routing_untouched_on_a_failed_load() -> void:
	GameSession.reset()
	GameSession.gold = 55
	GameManager.save_repository = SaveRepositoryScript.new(TEST_SAVE_PATH)
	GameManager.route_context_id = "stale"

	var result: Dictionary = GameManager.go_to_loaded_campaign()

	assert_false(result.ok)
	assert_eq(GameSession.gold, 55, "A failed load must never touch GameSession")
	assert_eq(GameManager.route_context_id, "stale", "A failed load must never route anywhere")
	GameManager.route_context_id = ""


func test_go_to_parties_with_create_immediately_flag_sets_and_consumes_flag() -> void:
	GameManager.create_party_on_open = false

	GameManager.go_to_parties(true)

	assert_true(GameManager.create_party_on_open)
	assert_true(GameManager.consume_create_party_on_open())
	assert_false(GameManager.create_party_on_open)

