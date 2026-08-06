extends GutTest

const GameSessionScript := preload("res://scripts/autoload/game_session.gd")


func _party(party_id: String, member_ids: Array[String], location_id: String, deployed: bool) -> Dictionary:
	return {
		"id": party_id,
		"member_ids": member_ids,
		"location_id": location_id,
		"world_position": Vector2i(0, 0),
		"deployed": deployed,
		"travel_route": [] as Array[Vector2i],
		"movement_spent": false,
		"name": "Test Party",
		"progression": {},
		"metadata": {},
	}


func _adventurer(adventurer_id: String, availability_status: String) -> Dictionary:
	return {
		"id": adventurer_id,
		"name": "Extra",
		"class": "warrior",
		"weapon": "sword",
		"level": 1,
		"availability_status": availability_status,
		"stats": {},
		"progression": {},
	}


func test_new_session_has_one_unassigned_warrior_and_no_party() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.adventurers, [GameSessionScript.DEFAULT_WARRIOR])
	assert_eq(session.parties, [])
	assert_eq(session.selected_party_id, "")


func test_new_session_defaults_the_player_name() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.player_name, GameSessionScript.DEFAULT_PLAYER_NAME)


func test_start_new_game_sets_the_player_name_and_resets_other_state() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 25

	session.start_new_game("Aria")

	assert_eq(session.player_name, "Aria")
	assert_eq(session.gold, 0)


func test_reset_restores_the_default_player_name() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.start_new_game("Aria")

	session.reset()

	assert_eq(session.player_name, GameSessionScript.DEFAULT_PLAYER_NAME)


func test_create_party_then_add_and_remove_warrior() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_true(session.create_party())
	assert_true(session.assign_adventurer_to_selected_party("warrior_001"))
	assert_eq(session.get_selected_party().member_ids, ["warrior_001"])
	assert_true(session.remove_adventurer_from_selected_party("warrior_001"))
	assert_false(session.can_depart_selected_party())


func test_deploy_and_return_change_only_the_selected_party_state() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	assert_true(session.depart_selected_party())
	assert_true(session.has_deployed_party())
	assert_eq(session.get_deployed_party_position(), Vector2i(0, 0))
	session.set_deployed_party_position(Vector2i(1, 0))
	session.return_deployed_party_to_settlement()
	assert_false(session.has_deployed_party())
	assert_eq(session.get_selected_party().location_id, "starting_settlement")

func test_cannot_create_a_second_party() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_true(session.create_party())
	assert_false(session.create_party())


func test_cannot_assign_an_unknown_or_already_assigned_adventurer() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.create_party()
	assert_false(session.assign_adventurer_to_selected_party("unknown"))
	assert_true(session.assign_adventurer_to_selected_party("warrior_001"))
	assert_false(session.assign_adventurer_to_selected_party("warrior_001"))


func test_available_adventurers_excludes_assigned_warrior() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.get_available_adventurers(), [GameSessionScript.DEFAULT_WARRIOR])
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	assert_eq(session.get_available_adventurers(), [])


func test_empty_party_cannot_depart() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.create_party()

	assert_false(session.depart_selected_party())


func test_cannot_write_position_without_a_deployed_party() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_false(session.set_deployed_party_position(Vector2i(1, 0)))


func test_new_session_starts_at_world_turn_one() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.world_turn, 1)


func test_deploying_a_party_starts_with_an_empty_route_and_unspent_movement() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")

	session.depart_selected_party()

	assert_eq(session.get_deployed_party_route(), [] as Array[Vector2i])
	assert_false(session.get_selected_party().movement_spent)


func test_cannot_set_a_route_without_a_deployed_party() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_false(session.set_deployed_party_route([Vector2i(1, 0)] as Array[Vector2i]))


func test_setting_a_valid_adjacent_route_persists_it_without_moving() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.depart_selected_party()
	var route: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0)]

	assert_true(session.set_deployed_party_route(route))

	assert_eq(session.get_deployed_party_route(), route)
	assert_eq(session.get_deployed_party_position(), Vector2i(0, 0), "Saving a route must not move the party")


func test_setting_an_empty_route_is_rejected() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.depart_selected_party()

	assert_false(session.set_deployed_party_route([] as Array[Vector2i]))


func test_setting_a_non_adjacent_route_is_rejected() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.depart_selected_party()

	assert_false(session.set_deployed_party_route([Vector2i(2, 0)] as Array[Vector2i]))
	assert_eq(session.get_deployed_party_route(), [] as Array[Vector2i])


func test_take_next_route_step_moves_one_tile_and_spends_movement() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.depart_selected_party()
	session.set_deployed_party_route([Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])

	var moved: bool = session.take_next_route_step()

	assert_true(moved)
	assert_eq(session.get_deployed_party_position(), Vector2i(1, 0))
	assert_eq(session.get_deployed_party_route(), [Vector2i(2, 0)])
	assert_true(session.get_selected_party().movement_spent)


func test_take_next_route_step_refuses_a_second_step_in_the_same_turn() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.depart_selected_party()
	session.set_deployed_party_route([Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])
	session.take_next_route_step()

	var moved_again: bool = session.take_next_route_step()

	assert_false(moved_again)
	assert_eq(session.get_deployed_party_position(), Vector2i(1, 0))


func test_route_is_empty_after_the_final_step_completes_it() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.depart_selected_party()
	session.set_deployed_party_route([Vector2i(1, 0)] as Array[Vector2i])

	session.take_next_route_step()

	assert_eq(session.get_deployed_party_route(), [] as Array[Vector2i], "Arrival should clear the route")


func test_end_world_turn_auto_steps_when_movement_is_unused() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.depart_selected_party()
	session.set_deployed_party_route([Vector2i(1, 0)] as Array[Vector2i])

	var auto_moved: bool = session.end_world_turn()

	assert_true(auto_moved)
	assert_eq(session.get_deployed_party_position(), Vector2i(1, 0))
	assert_eq(session.world_turn, 2)
	assert_false(
		session.get_selected_party().movement_spent, "Movement should be available again next turn"
	)


func test_end_world_turn_does_not_move_again_after_a_manual_step() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.depart_selected_party()
	session.set_deployed_party_route([Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])
	session.take_next_route_step()

	var auto_moved: bool = session.end_world_turn()

	assert_false(auto_moved)
	assert_eq(
		session.get_deployed_party_position(),
		Vector2i(1, 0),
		"End Turn must not add a second move after a manual step"
	)
	assert_eq(session.world_turn, 2)


func test_returning_home_clears_the_route() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.depart_selected_party()
	session.set_deployed_party_route([Vector2i(1, 0)] as Array[Vector2i])

	session.return_deployed_party_to_settlement()
	session.depart_selected_party()

	assert_eq(session.get_deployed_party_route(), [] as Array[Vector2i])


func test_entering_an_encounter_records_it_as_selected() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)

	assert_eq(session.selected_encounter, GameSessionScript.GOBLIN_CAMP_ID)
	assert_false(session.is_encounter_complete(GameSessionScript.GOBLIN_CAMP_ID), "Entering does not itself complete an encounter")


func test_completing_the_current_encounter_marks_it_complete() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.enter_encounter("goblin_camp")

	session.complete_current_encounter()

	assert_true(session.is_encounter_complete("goblin_camp"), "Completing marks the encounter complete")
	assert_eq(session.selected_encounter, "", "Completing clears the selected encounter")


func test_abandoning_the_current_encounter_clears_selection_without_completing_it() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.enter_encounter("goblin_camp")

	session.abandon_current_encounter()

	assert_eq(session.selected_encounter, "")
	assert_false(session.is_encounter_complete("goblin_camp"))


func test_reset_clears_encounter_state() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.enter_encounter("goblin_camp")
	session.complete_current_encounter()

	session.reset()

	assert_false(
		session.is_encounter_complete("goblin_camp"), "reset() clears previously completed encounters"
	)
	assert_eq(session.selected_encounter, "", "reset() clears the selected encounter")


func test_reset_restores_a_deep_duplicated_default_warrior() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.adventurers[0].name = "Changed"
	session.reset()

	assert_eq(session.adventurers, [GameSessionScript.DEFAULT_WARRIOR])


func test_orc_outpost_id_constant_is_orc_outpost() -> void:
	assert_eq(GameSessionScript.ORC_OUTPOST_ID, "orc_outpost")


func test_get_expedition_returns_the_documented_goblin_camp_record() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var record: Dictionary = session.get_expedition(GameSessionScript.GOBLIN_CAMP_ID)

	assert_eq(record.position, Vector2i(4, 4))
	assert_eq(record.reward, 10)
	assert_eq(record.enemy.max_health, 3)
	assert_eq(record.enemy.attack_damage, 1)
	assert_eq(record.enemy.hit_chance, 0.3)
	assert_eq(record.enemy.attack_name_key, "battle.enemy.goblin.attack")


func test_get_expedition_returns_the_documented_orc_outpost_record() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var record: Dictionary = session.get_expedition(GameSessionScript.ORC_OUTPOST_ID)

	assert_eq(record.position, Vector2i(4, 0))
	assert_eq(record.reward, 25)
	assert_eq(record.enemy.max_health, 5)
	assert_eq(record.enemy.attack_damage, 2)
	assert_eq(record.enemy.hit_chance, 0.5)
	assert_eq(record.enemy.attack_name_key, "battle.enemy.orc.attack")


func test_get_expedition_returns_an_empty_dictionary_for_an_unknown_id() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.get_expedition("missing"), {})


func test_get_expedition_returns_a_record_that_can_be_mutated_without_affecting_the_catalog() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var record: Dictionary = session.get_expedition(GameSessionScript.GOBLIN_CAMP_ID)
	record.reward = 999
	record.enemy.max_health = 999

	var second_record: Dictionary = session.get_expedition(GameSessionScript.GOBLIN_CAMP_ID)
	assert_eq(second_record.reward, 10, "Mutating a returned record must not affect the catalog")
	assert_eq(
		second_record.enemy.max_health,
		3,
		"Mutating a nested dictionary in a returned record must not affect the catalog"
	)


func test_new_session_has_zero_gold_and_pending_reward() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.gold, 0)
	assert_eq(session.pending_reward, 0)


func test_reset_clears_gold_and_pending_reward() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 5
	session.pending_reward = 5

	session.reset()

	assert_eq(session.gold, 0)
	assert_eq(session.pending_reward, 0)


func test_completing_the_entered_goblin_camp_queues_its_reward_without_paying_gold() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)

	session.complete_current_encounter()

	assert_eq(session.pending_reward, 10, "Victory should queue the goblin camp's fixed reward")
	assert_eq(session.gold, 0, "Completing an encounter must not bank gold directly")
	assert_true(session.is_encounter_complete(GameSessionScript.GOBLIN_CAMP_ID))


func test_deposit_pending_reward_pays_once_then_returns_zero_on_a_second_call() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()

	var deposited: int = session.deposit_pending_reward()

	assert_eq(deposited, 10)
	assert_eq(session.gold, 10)
	assert_eq(session.pending_reward, 0)

	var second_deposit: int = session.deposit_pending_reward()

	assert_eq(second_deposit, 0, "A second deposit must not pay again")
	assert_eq(session.gold, 10, "Gold must not change on a second deposit")


func test_chaining_two_victories_without_depositing_accumulates_both_rewards() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)

	session.complete_current_encounter()

	assert_eq(
		session.pending_reward,
		35,
		"Both rewards should accumulate when banking happens after both victories"
	)
	assert_true(session.is_encounter_complete(GameSessionScript.GOBLIN_CAMP_ID))
	assert_true(session.is_encounter_complete(GameSessionScript.ORC_OUTPOST_ID))


func test_depositing_after_chained_victories_banks_the_combined_reward() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)
	session.complete_current_encounter()

	var deposited: int = session.deposit_pending_reward()

	assert_eq(deposited, 35)
	assert_eq(session.gold, 35)
	assert_eq(session.pending_reward, 0)


func test_completing_an_already_completed_encounter_does_not_requeue_its_reward() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.deposit_pending_reward()
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)

	session.complete_current_encounter()

	assert_eq(
		session.pending_reward,
		0,
		"Re-completing an already-completed site must not requeue its reward"
	)
	assert_eq(session.gold, 10, "Gold already banked must be unaffected by re-completing a finished site")


func test_abandoning_the_entered_orc_outpost_leaves_zero_gold_and_pending_reward() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)

	session.abandon_current_encounter()

	assert_eq(session.gold, 0)
	assert_eq(session.pending_reward, 0)
	assert_false(session.is_encounter_complete(GameSessionScript.ORC_OUTPOST_ID), "Abandoning must leave the site retryable")


func test_default_warrior_has_level_availability_and_placeholder_progression() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var warrior: Dictionary = session.adventurers[0]

	assert_eq(warrior.name, "Warrior")
	assert_eq(warrior["class"], "warrior")
	assert_eq(warrior.level, 1, "A fresh Warrior starts at level 1")
	assert_eq(warrior.availability_status, "available", "A fresh Warrior starts available for a party")
	assert_eq(warrior.stats, {}, "Stats are a TBD placeholder that must not affect combat")
	assert_eq(warrior.progression, {}, "Progression is a TBD placeholder that must not affect combat")


func test_create_party_sets_name_encampment_location_and_placeholder_metadata() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.create_party()
	var party: Dictionary = session.get_selected_party()

	assert_eq(party.name, "Party 1")
	assert_eq(party.location_id, GameSessionScript.STARTING_SETTLEMENT_ID)
	assert_eq(party.progression, {})
	assert_eq(party.metadata, {})
	assert_eq(party.member_ids, [] as Array[String], "Existing route/member fields must survive the new metadata")
	assert_false(party.deployed)
	assert_eq(party.travel_route, [] as Array[Vector2i])
	assert_false(party.movement_spent)


func test_get_party_returns_a_safe_copy_and_empty_dictionary_for_an_unknown_id() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()

	var party: Dictionary = session.get_party(GameSessionScript.FIRST_PARTY_ID)
	assert_eq(party.id, GameSessionScript.FIRST_PARTY_ID)

	party.name = "Mutated"
	assert_eq(
		session.get_selected_party().name,
		"Party 1",
		"Mutating a returned party copy must not affect session state"
	)
	assert_eq(session.get_party("missing"), {})


func test_get_adventurer_returns_a_safe_copy_and_empty_dictionary_for_an_unknown_id() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var warrior: Dictionary = session.get_adventurer(GameSessionScript.WARRIOR_ID)
	assert_eq(warrior.id, GameSessionScript.WARRIOR_ID)

	warrior.name = "Mutated"
	assert_eq(
		session.adventurers[0].name,
		"Warrior",
		"Mutating a returned adventurer copy must not affect session state"
	)
	assert_eq(session.get_adventurer("missing"), {})


func test_get_deployable_encamped_parties_excludes_an_empty_party() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.parties.append(
		_party("empty_party", [] as Array[String], GameSessionScript.STARTING_SETTLEMENT_ID, false)
	)

	assert_eq(session.get_deployable_encamped_parties(), [])


func test_get_deployable_encamped_parties_excludes_a_deployed_party() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.parties.append(
		_party("deployed_party", ["warrior_001"], GameSessionScript.STARTING_SETTLEMENT_ID, true)
	)

	assert_eq(session.get_deployable_encamped_parties(), [])


func test_get_deployable_encamped_parties_excludes_a_party_outside_the_starting_encampment() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.parties.append(
		_party("away_party", ["warrior_001"], GameSessionScript.GOBLIN_CAMP_ID, false)
	)

	assert_eq(session.get_deployable_encamped_parties(), [])


func test_get_deployable_encamped_parties_excludes_a_party_with_no_available_members() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.adventurers.append(_adventurer("scout_001", "on_expedition"))
	session.parties.append(
		_party("busy_party", ["scout_001"], GameSessionScript.STARTING_SETTLEMENT_ID, false)
	)

	assert_eq(session.get_deployable_encamped_parties(), [])


func test_get_deployable_encamped_parties_includes_a_party_with_an_available_member() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.parties.append(
		_party("ready_party", ["warrior_001"], GameSessionScript.STARTING_SETTLEMENT_ID, false)
	)

	var deployable: Array[Dictionary] = session.get_deployable_encamped_parties()

	assert_eq(deployable.size(), 1)
	assert_eq(deployable[0].id, "ready_party")


func test_deploy_party_rejects_an_unknown_id() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_false(session.deploy_party("does_not_exist"))
	assert_eq(session.selected_party_id, "")


func test_deploy_party_rejects_an_ineligible_party() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.parties.append(
		_party("empty_party", [] as Array[String], GameSessionScript.STARTING_SETTLEMENT_ID, false)
	)

	assert_false(session.deploy_party("empty_party"))
	assert_eq(session.selected_party_id, "")


func test_deploy_party_deploys_an_eligible_party_and_leaves_others_untouched() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.parties.append(
		_party("ready_party", ["warrior_001"], GameSessionScript.STARTING_SETTLEMENT_ID, false)
	)
	session.parties.append(
		_party("other_party", ["warrior_001"], GameSessionScript.GOBLIN_CAMP_ID, false)
	)

	assert_true(session.deploy_party("ready_party"))

	assert_eq(session.selected_party_id, "ready_party")
	var deployed_party: Dictionary = session.get_party("ready_party")
	assert_true(deployed_party.deployed)
	assert_eq(deployed_party.location_id, GameSessionScript.STARTING_SETTLEMENT_ID)
	assert_eq(deployed_party.world_position, GameSessionScript.STARTING_SETTLEMENT_WORLD_POSITION)

	var other_party: Dictionary = session.get_party("other_party")
	assert_false(other_party.deployed, "Deploying one party must not affect another")
	assert_eq(
		other_party.location_id,
		GameSessionScript.GOBLIN_CAMP_ID,
		"Deploying one party must not affect another"
	)


func test_assign_adventurer_to_party_targets_the_named_party_not_the_selected_one() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.parties.append(
		_party("second_party", [] as Array[String], GameSessionScript.STARTING_SETTLEMENT_ID, false)
	)

	assert_true(session.assign_adventurer_to_party("second_party", "warrior_001"))

	assert_eq(session.get_party("second_party").member_ids, ["warrior_001"])
	assert_eq(
		session.get_selected_party().member_ids,
		[] as Array[String],
		"Only the named party should gain the member"
	)


func test_assign_adventurer_to_party_rejects_unknown_party_unknown_adventurer_and_double_assignment() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()

	assert_false(session.assign_adventurer_to_party("no_such_party", "warrior_001"))
	assert_false(session.assign_adventurer_to_party(GameSessionScript.FIRST_PARTY_ID, "no_such_adventurer"))
	assert_true(session.assign_adventurer_to_party(GameSessionScript.FIRST_PARTY_ID, "warrior_001"))
	assert_false(session.assign_adventurer_to_party(GameSessionScript.FIRST_PARTY_ID, "warrior_001"))


func test_assign_adventurer_to_selected_party_still_works_as_a_thin_wrapper() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()

	assert_true(session.assign_adventurer_to_selected_party("warrior_001"))

	assert_eq(session.get_selected_party().member_ids, ["warrior_001"])


func test_recruit_adventurer_appends_a_new_available_adventurer_with_a_fresh_id() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.recruit_adventurer()

	assert_eq(session.adventurers.size(), 2)
	var recruit: Dictionary = session.adventurers[1]
	assert_eq(recruit.id, "warrior_002")
	assert_eq(recruit.name, "Warrior 2")
	assert_eq(recruit["class"], "warrior")
	assert_eq(recruit.availability_status, "available")
	assert_true(session.get_available_adventurers().has(recruit))


func test_recruit_adventurer_never_collides_with_an_earlier_recruit() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.recruit_adventurer()

	session.recruit_adventurer()

	assert_eq(session.adventurers.size(), 3)
	assert_eq(session.adventurers[2].id, "warrior_003")


func test_get_recruitment_candidates_returns_the_three_fixed_warrior_candidates() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var candidates: Array[Dictionary] = session.get_recruitment_candidates()

	assert_eq(candidates.size(), 3)
	var ids: Array = []
	for candidate in candidates:
		ids.append(candidate.id)
	assert_eq(ids, ["warrior_002", "warrior_003", "warrior_004"])
	for candidate in candidates:
		assert_eq(candidate["class"], "warrior")
		assert_eq(candidate.level, 1, "A recruitment candidate starts at level 1")
		assert_eq(candidate.availability_status, "available")
		assert_eq(candidate.cost, 10, "Every fixed candidate costs 10 gold")


func test_get_recruitment_candidates_returns_a_copy_that_cannot_mutate_the_catalog() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var candidates: Array[Dictionary] = session.get_recruitment_candidates()
	candidates[0].name = "Mutated"

	var second_candidates: Array[Dictionary] = session.get_recruitment_candidates()
	assert_eq(
		second_candidates[0].name,
		"Warrior 2",
		"Mutating a returned candidate must not affect the catalog"
	)


func test_reset_restores_all_three_recruitment_candidates() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 10
	session.purchase_recruit("warrior_002")

	session.reset()

	var candidates: Array[Dictionary] = session.get_recruitment_candidates()
	var ids: Array = []
	for candidate in candidates:
		ids.append(candidate.id)
	assert_eq(ids, ["warrior_002", "warrior_003", "warrior_004"], "reset() must restore every purchased candidate")


func test_purchase_recruit_fails_without_enough_gold_and_changes_nothing() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_false(session.purchase_recruit("warrior_002"))

	assert_eq(session.gold, 0)
	assert_eq(session.get_recruitment_candidates().size(), 3)
	assert_eq(session.adventurers.size(), 1)


func test_purchase_recruit_fails_for_an_unknown_candidate_id() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 10

	assert_false(session.purchase_recruit("no_such_candidate"))

	assert_eq(session.gold, 10)
	assert_eq(session.get_recruitment_candidates().size(), 3)
	assert_eq(session.adventurers.size(), 1)


func test_purchase_recruit_fails_for_an_already_purchased_candidate() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 20
	session.purchase_recruit("warrior_002")

	assert_false(session.purchase_recruit("warrior_002"))

	assert_eq(session.gold, 10, "Only the first purchase should deduct gold")
	assert_eq(session.adventurers.size(), 2, "A repeated purchase must not append a second adventurer")


func test_purchase_recruit_deducts_gold_removes_the_candidate_and_adds_the_adventurer() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 10

	assert_true(session.purchase_recruit("warrior_002"))

	assert_eq(session.gold, 0, "The exact candidate cost must be deducted")
	var remaining_ids: Array = []
	for candidate in session.get_recruitment_candidates():
		remaining_ids.append(candidate.id)
	assert_eq(
		remaining_ids,
		["warrior_003", "warrior_004"],
		"Only the purchased candidate should be removed from the catalog"
	)

	assert_eq(session.adventurers.size(), 2)
	var recruit: Dictionary = session.adventurers[1]
	assert_eq(recruit.id, "warrior_002")
	assert_eq(recruit["class"], "warrior")
	assert_eq(recruit.level, 1)
	assert_eq(recruit.availability_status, "available")
	assert_false(recruit.has("cost"), "The adventurer record should not carry a purchase cost")
