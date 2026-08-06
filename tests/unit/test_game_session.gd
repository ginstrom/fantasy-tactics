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
	assert_eq(session.parties.size(), 1)
	assert_eq(session.get_selected_party().id, GameSessionScript.FIRST_PARTY_ID)


func test_public_ui_eligibility_queries_report_current_state_without_mutating_it() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_true(session.is_adventurer_available(GameSessionScript.WARRIOR_ID))
	assert_false(session.is_adventurer_available("missing"))
	assert_true(session.has_recruitment_candidate("warrior_002"))
	assert_false(session.is_party_deployable(GameSessionScript.FIRST_PARTY_ID))
	session.create_party()
	session.assign_adventurer_to_selected_party(GameSessionScript.WARRIOR_ID)
	assert_true(session.is_party_deployable(GameSessionScript.FIRST_PARTY_ID))
	session.deploy_party(GameSessionScript.FIRST_PARTY_ID)
	assert_false(session.is_party_deployable(GameSessionScript.FIRST_PARTY_ID))
	session.gold = 10
	session.purchase_recruit("warrior_002")
	assert_false(session.has_recruitment_candidate("warrior_002"))


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


func test_get_expedition_includes_kill_and_clear_xp_for_the_goblin_camp() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var record: Dictionary = session.get_expedition(GameSessionScript.GOBLIN_CAMP_ID)

	assert_eq(record.kill_xp, 5, "A goblin kill should award 5 XP")
	assert_eq(record.clear_xp, 10, "Clearing the goblin camp should award 10 XP")


func test_get_expedition_includes_kill_and_clear_xp_for_the_orc_outpost() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var record: Dictionary = session.get_expedition(GameSessionScript.ORC_OUTPOST_ID)

	assert_eq(record.kill_xp, 10, "An orc kill should award 10 XP")
	assert_eq(record.clear_xp, 20, "Clearing the orc outpost should award 20 XP")


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


func test_default_warrior_has_level_and_availability() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var warrior: Dictionary = session.adventurers[0]

	assert_eq(warrior.name, "Warrior")
	assert_eq(warrior["class"], "warrior")
	assert_eq(warrior.level, 1, "A fresh Warrior starts at level 1")
	assert_eq(warrior.availability_status, "available", "A fresh Warrior starts available for a party")


## Task 1 (progression domain): a new campaign's default Warrior starts with a
## complete, validated progression state rather than the old TBD placeholders.
func test_default_warrior_starts_with_a_complete_progression_state() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var warrior: Dictionary = session.get_adventurer(GameSessionScript.WARRIOR_ID)

	assert_eq(warrior.progression.xp, 0.0, "XP is stored as a float")
	assert_eq(warrior.level, 1)
	assert_eq(warrior.stats.attack, 60)
	assert_eq(warrior.progression.skill_points, 0, "A fresh Warrior has no unspent points")
	assert_eq(warrior.progression.perks, [], "A fresh Warrior has chosen no perks")
	assert_eq(warrior.stats.max_health, 3)


func test_get_adventurer_returns_a_copy_whose_nested_progression_cannot_mutate_session_state() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var warrior: Dictionary = session.get_adventurer(GameSessionScript.WARRIOR_ID)
	warrior.progression.xp = 999.0
	warrior.stats.attack = 999

	var second_copy: Dictionary = session.get_adventurer(GameSessionScript.WARRIOR_ID)
	assert_eq(second_copy.progression.xp, 0.0, "Mutating a returned copy's nested progression must not affect session state")
	assert_eq(second_copy.stats.attack, 60, "Mutating a returned copy's nested stats must not affect session state")


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


func test_get_encamped_parties_excludes_a_deployed_party() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.parties.append(
		_party("deployed_party", ["warrior_001"], GameSessionScript.STARTING_SETTLEMENT_ID, true)
	)

	assert_eq(session.get_encamped_parties(), [])


func test_get_encamped_parties_excludes_a_party_outside_the_starting_settlement() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.parties.append(
		_party("away_party", ["warrior_001"], GameSessionScript.GOBLIN_CAMP_ID, false)
	)

	assert_eq(session.get_encamped_parties(), [])


func test_get_encamped_parties_includes_a_full_but_encamped_party_with_no_available_members() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.adventurers.append(_adventurer("scout_001", "on_expedition"))
	session.parties.append(
		_party("busy_party", ["scout_001"], GameSessionScript.STARTING_SETTLEMENT_ID, false)
	)

	var encamped: Array[Dictionary] = session.get_encamped_parties()

	assert_eq(
		encamped.size(), 1, "A full-but-encamped party is still a valid unit-assignment target"
	)
	assert_eq(encamped[0].id, "busy_party")


func test_get_encamped_parties_returns_a_copy_that_cannot_mutate_the_catalog() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()

	var encamped: Array[Dictionary] = session.get_encamped_parties()
	encamped[0].name = "Mutated"

	assert_eq(
		session.get_selected_party().name,
		"Party 1",
		"Mutating a returned encamped party copy must not affect session state"
	)


func test_assign_adventurer_to_party_rejects_a_deployed_party() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.parties.append(
		_party("deployed_party", [] as Array[String], GameSessionScript.STARTING_SETTLEMENT_ID, true)
	)

	assert_false(session.assign_adventurer_to_party("deployed_party", "warrior_001"))
	assert_eq(session.get_party("deployed_party").member_ids, [] as Array[String])


func test_assign_adventurer_to_party_rejects_a_party_outside_the_starting_settlement() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.parties.append(
		_party("away_party", [] as Array[String], GameSessionScript.GOBLIN_CAMP_ID, false)
	)

	assert_false(session.assign_adventurer_to_party("away_party", "warrior_001"))
	assert_eq(session.get_party("away_party").member_ids, [] as Array[String])


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


## warrior_002 through warrior_004 are live, unpurchased recruitment
## candidates on a fresh session (see RECRUITMENT_CANDIDATE_TEMPLATES), so a
## fresh id must skip all three rather than mint a duplicate of one still on
## offer in Recruitment.
func test_recruit_adventurer_appends_a_new_available_adventurer_with_a_fresh_id() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.recruit_adventurer()

	assert_eq(session.adventurers.size(), 2)
	var recruit: Dictionary = session.adventurers[1]
	assert_eq(recruit.id, "warrior_005")
	assert_eq(recruit.name, "Warrior 5")
	assert_eq(recruit["class"], "warrior")
	assert_eq(recruit.availability_status, "available")
	assert_true(session.get_available_adventurers().has(recruit))


func test_recruit_adventurer_never_collides_with_an_earlier_recruit() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.recruit_adventurer()

	session.recruit_adventurer()

	assert_eq(session.adventurers.size(), 3)
	assert_eq(session.adventurers[2].id, "warrior_006")


## Reproduces the exact reported failure: after a partial purchase leaves
## some fixed candidates (warrior_003/warrior_004) still live, a debug
## recruit must not mint an id any of them are still offering, nor one an
## earlier debug recruit already used.
func test_recruit_adventurer_after_a_purchase_never_collides_with_a_live_candidate() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 10
	session.purchase_recruit("warrior_002")

	session.recruit_adventurer()

	var recruited: Dictionary = session.adventurers[session.adventurers.size() - 1]
	assert_eq(
		recruited.id,
		"warrior_005",
		"The debug recruit must skip the still-live warrior_003/warrior_004 candidates"
	)
	var live_candidate_ids: Array = []
	for candidate in session.get_recruitment_candidates():
		live_candidate_ids.append(candidate.id)
	assert_false(
		live_candidate_ids.has(recruited.id),
		"A debug recruit must never mint an id a still-live candidate is offering"
	)
	var all_ids: Array = []
	for adventurer in session.adventurers:
		all_ids.append(adventurer.id)
	var seen_ids: Dictionary = {}
	for id in all_ids:
		assert_false(seen_ids.has(id), "Adventurer ids must be unique; found a duplicate: %s" % id)
		seen_ids[id] = true


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


## Guards the other direction of the same id-collision hazard: if a debug
## recruit (or any other path) already put an adventurer with this exact id
## on the roster, buying the same-id candidate must be refused outright
## rather than appending a second, permanently-unassignable record.
func test_purchase_recruit_refuses_when_an_adventurer_already_holds_that_id() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 10
	session.adventurers.append(_adventurer("warrior_002", "available"))

	assert_false(session.purchase_recruit("warrior_002"))

	assert_eq(session.gold, 10, "A refused purchase must not deduct gold")
	assert_eq(
		session.get_recruitment_candidates().size(),
		3,
		"A refused purchase must not remove the candidate from the catalog"
	)
	assert_eq(session.adventurers.size(), 2, "A refused purchase must not append a second adventurer")


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


## Task 1: progression domain (award_party_xp, spend_attack_points,
## choose_perk) and the derived effective-hit/health/move calculations that
## GameSession centralizes for later battle and UI tasks to call into.

func test_award_party_xp_divides_a_five_point_award_evenly_between_two_members() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.recruit_adventurer()
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.assign_adventurer_to_selected_party("warrior_005")

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 5.0)

	assert_eq(session.get_adventurer("warrior_001").progression.xp, 2.5)
	assert_eq(session.get_adventurer("warrior_005").progression.xp, 2.5)


func test_award_party_xp_ignores_an_unknown_party() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var result: Array[String] = session.award_party_xp("no_such_party", 5.0)

	assert_eq(result, [] as Array[String])
	assert_eq(session.get_adventurer("warrior_001").progression.xp, 0.0)


func test_award_party_xp_ignores_an_empty_party() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()

	var result: Array[String] = session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 5.0)

	assert_eq(result, [] as Array[String])
	assert_eq(session.get_adventurer("warrior_001").progression.xp, 0.0, "An empty party must not receive XP")


func test_award_party_xp_returns_the_ids_that_crossed_a_level_threshold() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")

	var leveled_up: Array[String] = session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 20.0)

	assert_eq(leveled_up, ["warrior_001"])
	assert_eq(session.get_adventurer("warrior_001").level, 2)


func test_award_party_xp_below_the_next_threshold_does_not_level_up() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")

	var leveled_up: Array[String] = session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 19.0)

	assert_eq(leveled_up, [] as Array[String])
	assert_eq(session.get_adventurer("warrior_001").level, 1)


func test_twenty_cumulative_xp_reaches_level_two() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 20.0)

	assert_eq(session.get_adventurer("warrior_001").level, 2)


func test_fifty_cumulative_xp_reaches_level_three() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 20.0)
	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 30.0)

	assert_eq(session.get_adventurer("warrior_001").level, 3)


func test_an_oversized_award_resolves_multiple_levels_in_one_call() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 50.0)

	assert_eq(session.get_adventurer("warrior_001").level, 3, "50 XP in one award should resolve straight to level 3")


func test_each_level_gained_adds_one_max_health_and_ten_skill_points() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 20.0)

	var warrior: Dictionary = session.get_adventurer("warrior_001")
	assert_eq(warrior.stats.max_health, 4, "Leveling once should add exactly one max health")
	assert_eq(warrior.progression.skill_points, 10, "Leveling once should add exactly ten skill points")


func test_only_levels_divisible_by_three_require_a_perk_choice() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")

	assert_false(session.is_perk_choice_pending("warrior_001"), "Level 1 has no pending perk choice")

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 20.0)
	assert_false(session.is_perk_choice_pending("warrior_001"), "Level 2 does not require a perk choice")

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 30.0)
	assert_true(session.is_perk_choice_pending("warrior_001"), "Level 3 requires a perk choice")


func test_spend_attack_points_rejects_non_positive_overspent_and_missing_adventurer() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_false(session.spend_attack_points("warrior_001", 0), "A non-positive amount must be rejected")
	assert_false(session.spend_attack_points("warrior_001", -1), "A negative amount must be rejected")
	assert_false(session.spend_attack_points("warrior_001", 5), "A fresh Warrior has zero points to overspend")
	assert_false(session.spend_attack_points("missing", 5), "An unknown adventurer id must be rejected")
	assert_eq(session.get_adventurer("warrior_001").stats.attack, 60, "A rejected spend must not change Attack")


func test_spend_attack_points_decrements_points_and_raises_raw_attack() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 20.0)

	assert_true(session.spend_attack_points("warrior_001", 4))

	var warrior: Dictionary = session.get_adventurer("warrior_001")
	assert_eq(warrior.stats.attack, 64, "Spending 4 points should add 4 to raw Attack")
	assert_eq(warrior.progression.skill_points, 6, "Spending 4 of 10 points should leave 6 unspent")


func test_choose_perk_accepts_bonus_move_only_once_and_only_when_pending() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")

	assert_false(
		session.choose_perk("warrior_001", "bonus_move"),
		"A perk cannot be chosen before it is pending"
	)

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 50.0)
	assert_true(session.is_perk_choice_pending("warrior_001"))

	assert_true(session.choose_perk("warrior_001", "bonus_move"))
	assert_eq(session.get_adventurer("warrior_001").progression.perks, ["bonus_move"])
	assert_false(session.is_perk_choice_pending("warrior_001"), "Choosing the perk resolves the pending choice")

	assert_false(
		session.choose_perk("warrior_001", "bonus_move"),
		"The same perk cannot be chosen a second time"
	)
	assert_eq(session.get_adventurer("warrior_001").progression.perks, ["bonus_move"])


func test_choose_perk_rejects_an_unknown_perk_id() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 50.0)

	assert_false(session.choose_perk("warrior_001", "no_such_perk"))
	assert_eq(session.get_adventurer("warrior_001").progression.perks, [])


func test_effective_hit_chance_scales_linearly_with_raw_attack_below_the_cap() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.get_effective_hit_chance("warrior_001"), 0.6, "60 raw Attack should be 0.6 effective hit chance")


func test_effective_hit_chance_caps_at_ninety_five_percent_while_raw_attack_exceeds_ninety_five() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 140.0)

	session.spend_attack_points("warrior_001", 40)

	var warrior: Dictionary = session.get_adventurer("warrior_001")
	assert_eq(warrior.stats.attack, 100, "Raw Attack itself is not capped")
	assert_eq(
		session.get_effective_hit_chance("warrior_001"),
		0.95,
		"Effective hit chance is capped at 0.95 even though raw Attack exceeds 95"
	)


func test_get_effective_max_health_reflects_leveling() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")

	assert_eq(session.get_effective_max_health("warrior_001"), 3)

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 20.0)

	assert_eq(session.get_effective_max_health("warrior_001"), 4)


func test_get_effective_move_range_adds_the_bonus_move_perk() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")

	assert_eq(session.get_effective_move_range("warrior_001"), 3)

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 50.0)
	session.choose_perk("warrior_001", "bonus_move")

	assert_eq(session.get_effective_move_range("warrior_001"), 4, "bonus_move grants one extra tile of movement")
