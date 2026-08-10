extends GutTest

const GameSessionScript := preload("res://scripts/autoload/game_session.gd")


func _party(party_id: String, member_ids: Array[String], location_id: String, deployed: bool) -> Dictionary:
	return {
		"id": party_id,
		"member_ids": member_ids,
		"location_id": location_id,
		"world_position": GameSessionScript.STARTING_SETTLEMENT_WORLD_POSITION,
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


func after_each() -> void:
	GameSession.reset_injectable_rolls()


func before_each() -> void:
	GameSession.reset()


func test_new_session_has_one_unassigned_warrior_and_no_party() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.adventurers, [session.get_default_warrior()])
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
	assert_eq(session.get_deployed_party_position(), GameSessionScript.STARTING_SETTLEMENT_WORLD_POSITION)
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

	assert_eq(session.get_available_adventurers(), [session.get_default_warrior()])
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
	var route: Array[Vector2i] = [
		GameSessionScript.STARTING_SETTLEMENT_WORLD_POSITION + Vector2i(1, 0),
		GameSessionScript.STARTING_SETTLEMENT_WORLD_POSITION + Vector2i(2, 0),
	]

	assert_true(session.set_deployed_party_route(route))

	assert_eq(session.get_deployed_party_route(), route)
	assert_eq(
		session.get_deployed_party_position(),
		GameSessionScript.STARTING_SETTLEMENT_WORLD_POSITION,
		"Saving a route must not move the party"
	)


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
	var step_one: Vector2i = GameSessionScript.STARTING_SETTLEMENT_WORLD_POSITION + Vector2i(1, 0)
	var step_two: Vector2i = GameSessionScript.STARTING_SETTLEMENT_WORLD_POSITION + Vector2i(2, 0)
	session.set_deployed_party_route([step_one, step_two] as Array[Vector2i])

	var moved: bool = session.take_next_route_step()

	assert_true(moved)
	assert_eq(session.get_deployed_party_position(), step_one)
	assert_eq(session.get_deployed_party_route(), [step_two])
	assert_true(session.get_selected_party().movement_spent)


func test_take_next_route_step_refuses_a_second_step_in_the_same_turn() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.depart_selected_party()
	var step_one: Vector2i = GameSessionScript.STARTING_SETTLEMENT_WORLD_POSITION + Vector2i(1, 0)
	var step_two: Vector2i = GameSessionScript.STARTING_SETTLEMENT_WORLD_POSITION + Vector2i(2, 0)
	session.set_deployed_party_route([step_one, step_two] as Array[Vector2i])
	session.take_next_route_step()

	var moved_again: bool = session.take_next_route_step()

	assert_false(moved_again)
	assert_eq(session.get_deployed_party_position(), step_one)


func test_route_is_empty_after_the_final_step_completes_it() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.depart_selected_party()
	session.set_deployed_party_route(
		[GameSessionScript.STARTING_SETTLEMENT_WORLD_POSITION + Vector2i(1, 0)] as Array[Vector2i]
	)

	session.take_next_route_step()

	assert_eq(session.get_deployed_party_route(), [] as Array[Vector2i], "Arrival should clear the route")


func test_end_world_turn_auto_steps_when_movement_is_unused() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.depart_selected_party()
	var step_one: Vector2i = GameSessionScript.STARTING_SETTLEMENT_WORLD_POSITION + Vector2i(1, 0)
	session.set_deployed_party_route([step_one] as Array[Vector2i])

	var auto_moved: bool = session.end_world_turn()

	assert_true(auto_moved)
	assert_eq(session.get_deployed_party_position(), step_one)
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
	var step_one: Vector2i = GameSessionScript.STARTING_SETTLEMENT_WORLD_POSITION + Vector2i(1, 0)
	var step_two: Vector2i = GameSessionScript.STARTING_SETTLEMENT_WORLD_POSITION + Vector2i(2, 0)
	session.set_deployed_party_route([step_one, step_two] as Array[Vector2i])
	session.take_next_route_step()

	var auto_moved: bool = session.end_world_turn()

	assert_false(auto_moved)
	assert_eq(
		session.get_deployed_party_position(),
		step_one,
		"End Turn must not add a second move after a manual step"
	)
	assert_eq(session.world_turn, 2)


func test_returning_home_clears_the_route() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.depart_selected_party()
	session.set_deployed_party_route(
		[GameSessionScript.STARTING_SETTLEMENT_WORLD_POSITION + Vector2i(1, 0)] as Array[Vector2i]
	)

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

	assert_eq(session.adventurers, [session.get_default_warrior()])


func test_orc_outpost_id_constant_is_orc_outpost() -> void:
	assert_eq(GameSessionScript.ORC_OUTPOST_ID, "orc_outpost")


func test_get_expedition_returns_the_documented_goblin_camp_record() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var record: Dictionary = session.get_expedition(GameSessionScript.GOBLIN_CAMP_ID)

	assert_eq(record.position, Vector2i(4, 4))
	assert_eq(record.enemy.max_health, 13)
	assert_eq(record.enemy.attack_damage, 2)
	assert_eq(record.enemy.hit_chance, 0.3)
	assert_eq(record.enemy.attack_name_key, "battle.enemy.goblin.attack")


func test_get_expedition_returns_the_documented_orc_outpost_record() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var record: Dictionary = session.get_expedition(GameSessionScript.ORC_OUTPOST_ID)

	assert_eq(record.position, Vector2i(4, 0))
	assert_eq(record.enemy.max_health, 22)
	assert_eq(record.enemy.attack_damage, 3)
	assert_eq(record.enemy.hit_chance, 0.5)
	assert_eq(record.enemy.attack_name_key, "battle.enemy.orc.attack")


func test_get_expedition_includes_clear_xp_for_the_goblin_camp() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var record: Dictionary = session.get_expedition(GameSessionScript.GOBLIN_CAMP_ID)

	assert_eq(record.clear_xp, 10, "Clearing the goblin camp should award 10 XP")


func test_get_expedition_includes_clear_xp_for_the_orc_outpost() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var record: Dictionary = session.get_expedition(GameSessionScript.ORC_OUTPOST_ID)

	assert_eq(record.clear_xp, 20, "Clearing the orc outpost should award 20 XP")


func test_get_expedition_includes_the_enemy_count_for_the_goblin_camp() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var record: Dictionary = session.get_expedition(GameSessionScript.GOBLIN_CAMP_ID)

	assert_eq(record.enemy.count, 1, "The goblin camp is a one-star site: a single goblin")


func test_get_expedition_includes_the_enemy_count_for_the_orc_outpost() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var record: Dictionary = session.get_expedition(GameSessionScript.ORC_OUTPOST_ID)

	assert_eq(record.enemy.count, 1, "The orc outpost's documented template default is a single orc")


## Task: star-tier enemy composition. A one-star site has only one possible
## composition, so it must never consult the roll callable at all.
func test_one_star_site_always_resolves_to_a_single_goblin_regardless_of_the_roll() -> void:
	GameSession.reset()
	GameSession.enemy_composition_roll = func(_option_count: int) -> int:
		fail_test("A one-star site must not roll for its composition")
		return 0

	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)

	var record: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	assert_eq(record.enemy.count, 1)
	assert_eq(record.enemy.name_key, "battle.enemy.goblin")


func test_two_star_site_forced_to_option_zero_resolves_to_two_goblins() -> void:
	GameSession.reset()
	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 0

	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)

	var record: Dictionary = GameSession.get_expedition(GameSession.ORC_OUTPOST_ID)
	assert_eq(record.enemy.count, 2)
	assert_eq(record.enemy.name_key, "battle.enemy.goblin")


func test_two_star_site_forced_to_option_one_resolves_to_one_orc() -> void:
	GameSession.reset()
	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 1

	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)

	var record: Dictionary = GameSession.get_expedition(GameSession.ORC_OUTPOST_ID)
	assert_eq(record.enemy.count, 1)
	assert_eq(record.enemy.name_key, "battle.enemy.orc")


func test_reentering_an_active_instance_rerolls_its_composition() -> void:
	GameSession.reset()
	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 0
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	assert_eq(GameSession.get_expedition(GameSession.ORC_OUTPOST_ID).enemy.count, 2)

	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 1
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)

	assert_eq(GameSession.get_expedition(GameSession.ORC_OUTPOST_ID).enemy.count, 1)


func test_three_star_tier_offers_kobolds_goblins_orcs_or_hobgoblins() -> void:
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][0].count_min, 4)
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][0].count_max, 8)
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][0].enemy.name_key, "battle.enemy.kobold")
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][1].count_min, 3)
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][1].count_max, 6)
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][1].enemy.name_key, "battle.enemy.goblin")
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][2].count_min, 2)
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][2].count_max, 4)
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][2].enemy.name_key, "battle.enemy.orc")
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][3].count_min, 1)
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][3].count_max, 3)
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][3].enemy.name_key, "battle.enemy.hobgoblin")


func test_tier_one_and_two_compositions_still_use_their_original_fixed_counts() -> void:
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[1][0].count_min, 1)
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[1][0].count_max, 1)
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[2][0].count_min, 2)
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[2][0].count_max, 2)
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[2][1].count_min, 1)
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[2][1].count_max, 1)


func test_resolve_enemy_composition_rolls_the_kobold_count_within_its_range() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.enemy_composition_roll = func(_option_count: int) -> int: return 0
	session.enemy_count_roll = func(min_value: int, max_value: int) -> int:
		assert_eq(min_value, 4)
		assert_eq(max_value, 8)
		return 6
	var enemy: Dictionary = session._resolve_enemy_composition(3)
	assert_eq(enemy.count, 6)
	assert_eq(enemy.name_key, "battle.enemy.kobold")


func test_resolve_enemy_composition_rolls_the_hobgoblin_count_within_its_range() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.enemy_composition_roll = func(_option_count: int) -> int: return 3
	session.enemy_count_roll = func(min_value: int, max_value: int) -> int:
		assert_eq(min_value, 1)
		assert_eq(max_value, 3)
		return 2
	var enemy: Dictionary = session._resolve_enemy_composition(3)
	assert_eq(enemy.count, 2)
	assert_eq(enemy.name_key, "battle.enemy.hobgoblin")


func test_ruined_fortress_is_a_three_star_site_at_its_documented_position() -> void:
	var record: Dictionary = GameSession.get_expedition(GameSession.RUINED_FORTRESS_ID)
	assert_eq(record.position, Vector2i(0, 4))
	assert_eq(record.difficulty, 3)
	assert_eq(record.clear_xp, 30)
	assert_eq(record.name_key, "expedition.ruined_fortress.name")


func test_ruined_fortress_is_not_seeded_as_an_active_encounter_on_a_fresh_campaign() -> void:
	GameSession.reset()
	for instance in GameSession.active_encounters:
		assert_ne(instance.template_id, GameSession.RUINED_FORTRESS_ID)
	assert_eq(GameSession.active_encounters.size(), 2, "A fresh campaign still starts with exactly the Goblin Camp and Orc Outpost")


func test_get_expedition_returns_an_empty_dictionary_for_an_unknown_id() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.get_expedition("missing"), {})


func test_get_expedition_returns_a_record_that_can_be_mutated_without_affecting_the_catalog() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var record: Dictionary = session.get_expedition(GameSessionScript.GOBLIN_CAMP_ID)
	record.position = Vector2i(99, 99)
	record.enemy.max_health = 999

	var second_record: Dictionary = session.get_expedition(GameSessionScript.GOBLIN_CAMP_ID)
	assert_eq(second_record.position, Vector2i(4, 4), "Mutating a returned record must not affect the catalog")
	assert_eq(
		second_record.enemy.max_health,
		13,
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
	session.battle_reward = 5

	session.reset()

	assert_eq(session.gold, 0)
	assert_eq(session.pending_reward, 0)
	assert_eq(session.battle_reward, 0)


func test_completing_the_entered_goblin_camp_queues_its_reward_without_paying_gold() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	session.loot_gear_roll = func() -> float: return 1.0
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)

	session.complete_current_encounter()

	assert_eq(session.battle_reward, 1, "Victory should queue the goblin camp's rolled reward in the battle store")
	assert_eq(session.gold, 0, "Completing an encounter must not bank gold directly")
	assert_true(session.is_encounter_complete(GameSessionScript.GOBLIN_CAMP_ID))


func test_deposit_pending_reward_pays_once_then_returns_zero_on_a_second_call() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	session.loot_gear_roll = func() -> float: return 1.0
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.merge_battle_loot_into_party()

	var deposited: int = session.deposit_pending_reward()

	assert_eq(deposited, 1)
	assert_eq(session.gold, 1)
	assert_eq(session.pending_reward, 0)

	var second_deposit: int = session.deposit_pending_reward()

	assert_eq(second_deposit, 0, "A second deposit must not pay again")
	assert_eq(session.gold, 1, "Gold must not change on a second deposit")


func test_chaining_two_victories_without_depositing_accumulates_both_rewards() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	session.loot_gear_roll = func() -> float: return 1.0
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.merge_battle_loot_into_party()
	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)

	session.complete_current_encounter()
	session.merge_battle_loot_into_party()

	assert_eq(
		session.pending_reward,
		3,
		"Both rewards should accumulate when banking happens after both victories"
	)
	assert_true(session.is_encounter_complete(GameSessionScript.GOBLIN_CAMP_ID))
	assert_true(session.is_encounter_complete(GameSessionScript.ORC_OUTPOST_ID))


func test_depositing_after_chained_victories_banks_the_combined_reward() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	session.loot_gear_roll = func() -> float: return 1.0
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.merge_battle_loot_into_party()
	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)
	session.complete_current_encounter()
	session.merge_battle_loot_into_party()

	var deposited: int = session.deposit_pending_reward()

	assert_eq(deposited, 3)
	assert_eq(session.gold, 3)
	assert_eq(session.pending_reward, 0)


func test_completing_an_already_completed_encounter_does_not_requeue_its_reward() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	session.loot_gear_roll = func() -> float: return 1.0
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.merge_battle_loot_into_party()
	session.deposit_pending_reward()
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)

	session.complete_current_encounter()

	assert_eq(
		session.battle_reward,
		0,
		"Re-completing an already-completed site must not requeue its reward"
	)
	assert_eq(session.gold, 1, "Gold already banked must be unaffected by re-completing a finished site")


func test_completing_the_goblin_camp_queues_gold_a_mana_crystal_and_no_gear_when_the_gear_roll_misses() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	session.loot_gear_roll = func() -> float: return 1.0
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)

	session.complete_current_encounter()

	assert_eq(session.battle_reward, 1, "One goblin kill: randi_range(1, 6) stubbed to the min (1) times multiplier 1")
	assert_eq(session.battle_mana_crystals, {1: 1}, "One goblin kill grants one tier-1 mana crystal")
	assert_eq(session.battle_gear, {}, "A gear roll of 1.0 must never clear the 25% drop chance")


func test_completing_the_goblin_camp_queues_gear_when_the_gear_roll_hits() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	session.loot_gear_roll = func() -> float: return 0.0
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)

	session.complete_current_encounter()

	assert_eq(session.battle_gear, {"shortsword_iron": 1}, "A gear roll of 0.0 must always clear the 25% drop chance")


func test_completing_the_orc_outpost_applies_the_documented_gold_multiplier() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	session.loot_gear_roll = func() -> float: return 1.0
	# The orc outpost is a two-star site: force its composition roll to option
	# 1 (a single orc) rather than leaving it to real randomness, which would
	# make this test flaky against the other valid composition (two goblins).
	session.enemy_composition_roll = func(_option_count: int) -> int: return 1
	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)

	session.complete_current_encounter()

	assert_eq(session.battle_reward, 2, "One orc kill: randi_range(1, 5) stubbed to the min (1) times multiplier 2")
	assert_eq(session.battle_mana_crystals, {2: 1}, "One orc kill grants one tier-2 mana crystal")


func test_completing_a_two_kill_encounter_rolls_loot_once_per_kill() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	session.loot_gear_roll = func() -> float: return 0.0
	session.enemy_composition_roll = func(_option_count: int) -> int: return 0
	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)

	session.complete_current_encounter()

	assert_eq(session.battle_reward, 2, "Two goblin kills: 1 gold each, multiplier 1")
	assert_eq(session.battle_mana_crystals, {1: 2}, "Two goblin kills grant two tier-1 mana crystals")
	assert_eq(session.battle_gear, {"shortsword_iron": 2}, "A guaranteed-hit gear roll fires once per kill")


func test_completing_an_encounter_adds_a_gold_bonus_scaled_by_star_difficulty() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(_min_value: int, max_value: int) -> int: return max_value
	session.loot_gear_roll = func() -> float: return 1.0
	# Force a single-orc composition (rather than two goblins) so the kill
	# loot side of this total stays deterministic.
	session.enemy_composition_roll = func(_option_count: int) -> int: return 1
	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)

	session.complete_current_encounter()

	# Kill gold: one orc, randi_range(1, 5) stubbed to max (5) * multiplier 2 = 10.
	# Encounter bonus: randi_range(0, 5) stubbed to max (5) * difficulty 2 = 10.
	assert_eq(session.battle_reward, 20, "Kill gold (10) plus the encounter bonus (10) at 2-star difficulty")


func test_recompleting_an_already_completed_encounter_does_not_requeue_the_bonus() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(_min_value: int, max_value: int) -> int: return max_value
	session.loot_gear_roll = func() -> float: return 1.0
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.merge_battle_loot_into_party()
	session.deposit_pending_reward()
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)

	session.complete_current_encounter()

	assert_eq(
		session.battle_reward, 0,
		"Re-completing an already-completed site must not requeue its gold bonus either"
	)


func test_deposit_pending_reward_banks_gold_mana_crystals_and_gear() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	session.loot_gear_roll = func() -> float: return 0.0
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	session.merge_battle_loot_into_party()

	session.deposit_pending_reward()

	assert_eq(session.gold, 1)
	assert_eq(session.mana_crystals, {1: 1})
	assert_eq(session.banked_gear, {"shortsword_iron": 1})
	assert_eq(session.pending_mana_crystals, {})
	assert_eq(session.pending_gear, {})


func test_merge_battle_loot_into_party_moves_the_battle_store_into_the_partys_own() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.battle_reward = 5
	session.battle_mana_crystals = {1: 2}
	session.battle_gear = {"dagger_iron": 1}
	session.pending_reward = 10
	session.pending_mana_crystals = {1: 1}
	session.pending_gear = {"buckler_wood": 1}

	session.merge_battle_loot_into_party()

	assert_eq(session.pending_reward, 15)
	assert_eq(session.pending_mana_crystals, {1: 3})
	assert_eq(session.pending_gear, {"dagger_iron": 1, "buckler_wood": 1})
	assert_eq(session.battle_reward, 0)
	assert_eq(session.battle_mana_crystals, {})
	assert_eq(session.battle_gear, {})


func test_merge_battle_loot_into_party_is_a_no_op_when_the_battle_store_is_empty() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.pending_reward = 10
	session.pending_mana_crystals = {1: 1}
	session.pending_gear = {"buckler_wood": 1}

	session.merge_battle_loot_into_party()

	assert_eq(session.pending_reward, 10)
	assert_eq(session.pending_mana_crystals, {1: 1})
	assert_eq(session.pending_gear, {"buckler_wood": 1})


func test_has_unsettled_battle_loot_is_false_when_the_battle_store_is_empty() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_false(session.has_unsettled_battle_loot())


func test_has_unsettled_battle_loot_is_true_for_a_nonzero_battle_reward() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.battle_reward = 1

	assert_true(session.has_unsettled_battle_loot())


func test_has_unsettled_battle_loot_is_true_for_nonempty_battle_gear() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.battle_gear = {"dagger_iron": 1}

	assert_true(session.has_unsettled_battle_loot())


func test_has_unsettled_battle_loot_is_true_for_nonempty_battle_mana_crystals() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.battle_mana_crystals = {1: 1}

	assert_true(session.has_unsettled_battle_loot())


func test_has_unsettled_battle_loot_is_false_after_merging_it_into_the_party() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.battle_reward = 5
	session.battle_gear = {"dagger_iron": 1}
	session.battle_mana_crystals = {1: 1}

	session.merge_battle_loot_into_party()

	assert_false(session.has_unsettled_battle_loot())


func test_reset_clears_loot_state() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.mana_crystals = {1: 3}
	session.banked_gear = {"shortsword_iron": 2}
	session.pending_mana_crystals = {1: 1}
	session.pending_gear = {"dagger_iron": 1}
	session.battle_mana_crystals = {1: 1}
	session.battle_gear = {"dagger_iron": 1}

	session.reset()

	assert_eq(session.mana_crystals, {})
	assert_eq(session.banked_gear, {})
	assert_eq(session.pending_mana_crystals, {})
	assert_eq(session.pending_gear, {})
	assert_eq(session.battle_mana_crystals, {})
	assert_eq(session.battle_gear, {})


func test_abandoning_the_entered_orc_outpost_leaves_zero_gold_and_pending_reward() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)

	session.abandon_current_encounter()

	assert_eq(session.gold, 0)
	assert_eq(session.pending_reward, 0)
	assert_eq(session.battle_reward, 0)
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
	assert_eq(warrior.stats.max_health, 10)


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


func test_create_party_uses_the_given_name() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.create_party("Alpha Party")

	assert_eq(session.parties[0].name, "Alpha Party")


func test_create_party_defaults_to_party_1_when_no_name_is_given() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.create_party()

	assert_eq(session.parties[0].name, "Party 1")


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


## Only warrior_002 is a live, unpurchased recruitment offer on a fresh
## session (see the reset()-seeds-one-offer tests below), so a fresh debug
## recruit id only needs to skip that one.
func test_recruit_adventurer_appends_a_new_available_adventurer_with_a_fresh_id() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.recruit_adventurer()

	assert_eq(session.adventurers.size(), 2)
	var recruit: Dictionary = session.adventurers[1]
	assert_eq(recruit.id, "warrior_003")
	assert_eq(recruit.name, "Warrior 3")
	assert_eq(recruit["class"], "warrior")
	assert_eq(recruit.availability_status, "available")
	assert_true(session.get_available_adventurers().has(recruit))


func test_recruit_adventurer_never_collides_with_an_earlier_recruit() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.recruit_adventurer()

	session.recruit_adventurer()

	assert_eq(session.adventurers.size(), 3)
	assert_eq(session.adventurers[2].id, "warrior_004")


## Reproduces the original reported hazard, adapted to the vacancy-timed
## catalog: a debug recruit must not mint an id any still-live recruitment
## offer is using, nor one an earlier debug recruit already used. Manually
## seeds an extra live offer (as if a vacancy refill had already fired) to
## exercise the skip without waiting on a real 30-turn clock.
func test_recruit_adventurer_never_collides_with_a_live_candidate() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.recruitment_candidates.append(_recruitment_candidate("warrior_003"))

	session.recruit_adventurer()

	var recruited: Dictionary = session.adventurers[session.adventurers.size() - 1]
	assert_eq(
		recruited.id,
		"warrior_004",
		"The debug recruit must skip both the seeded warrior_002 and the still-live warrior_003 offer"
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


func _recruitment_candidate(candidate_id: String) -> Dictionary:
	var candidate: Dictionary = GameSessionScript.RECRUITMENT_CANDIDATE_TEMPLATES[0].duplicate(true)
	candidate.id = candidate_id
	return candidate


func test_get_recruitment_candidates_returns_the_one_seeded_warrior_candidate() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var candidates: Array[Dictionary] = session.get_recruitment_candidates()

	assert_eq(candidates.size(), 1, "A fresh campaign seeds exactly one recruitable Warrior")
	assert_eq(candidates[0].id, "warrior_002")
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


func test_reset_restores_the_single_seeded_recruitment_candidate() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 10
	session.purchase_recruit("warrior_002")

	session.reset()

	var candidates: Array[Dictionary] = session.get_recruitment_candidates()
	var ids: Array = []
	for candidate in candidates:
		ids.append(candidate.id)
	assert_eq(ids, ["warrior_002"], "reset() must restore exactly the one seeded offer")


func test_purchase_recruit_fails_without_enough_gold_and_changes_nothing() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_false(session.purchase_recruit("warrior_002"))

	assert_eq(session.gold, 0)
	assert_eq(session.get_recruitment_candidates().size(), 1)
	assert_eq(session.adventurers.size(), 1)


func test_purchase_recruit_fails_for_an_unknown_candidate_id() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 10

	assert_false(session.purchase_recruit("no_such_candidate"))

	assert_eq(session.gold, 10)
	assert_eq(session.get_recruitment_candidates().size(), 1)
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
		1,
		"A refused purchase must not remove the candidate from the catalog"
	)
	assert_eq(session.adventurers.size(), 2, "A refused purchase must not append a second adventurer")


func test_purchase_recruit_deducts_gold_removes_the_candidate_and_adds_the_adventurer() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 10

	assert_true(session.purchase_recruit("warrior_002"))

	assert_eq(session.gold, 0, "The exact candidate cost must be deducted")
	assert_eq(
		session.get_recruitment_candidates(),
		[] as Array[Dictionary],
		"The purchased candidate should be removed from the catalog, leaving no other offers seeded"
	)

	assert_eq(session.adventurers.size(), 2)
	var recruit: Dictionary = session.adventurers[1]
	assert_eq(recruit.id, "warrior_002")
	assert_eq(recruit["class"], "warrior")
	assert_eq(recruit.level, 1)
	assert_eq(recruit.availability_status, "available")
	assert_false(recruit.has("cost"), "The adventurer record should not carry a purchase cost")


## Regression test: RECRUITMENT_CANDIDATE_TEMPLATES used to seed purchased
## and refilled recruits with genuinely empty "stats": {} / "progression": {}
## dicts (only the roster's starting Warrior, DEFAULT_WARRIOR, had real
## values). GDScript aborts the enclosing function on a missing-dictionary-
## key read rather than raising a catchable exception, so a purchased
## recruit's stats/progression reads would silently abort mid-function
## (get_effective_max_health, _award_adventurer_xp — losing that share of XP
## for good — and unit_details.gd's display all broke this way; a deployed
## party whose first member was such a recruit could not even act in
## battle). This single test covers all of those failure modes at the
## domain-data level: a purchased recruit must carry the same real baseline
## stats/progression as DEFAULT_WARRIOR, and must actually accumulate
## awarded party XP rather than silently dropping it.
func test_purchased_recruit_has_real_stats_and_progression_and_can_receive_xp() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 10
	assert_true(session.purchase_recruit("warrior_002"))

	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_002")
	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 5.0)

	var recruit: Dictionary = session.get_adventurer("warrior_002")
	assert_eq(
		recruit.stats.max_health,
		session.get_default_warrior().stats.max_health,
		"A purchased recruit must start with the Warrior baseline max health, not a missing key"
	)
	assert_eq(
		recruit.stats.attack,
		session.get_default_warrior().stats.attack,
		"A purchased recruit must start with the Warrior baseline Attack, not a missing key"
	)
	assert_eq(recruit.progression.xp, 5.0, "Awarded party XP must be stored, not silently dropped")
	assert_eq(
		recruit.progression.skill_points,
		session.get_default_warrior().progression.skill_points,
		"A purchased recruit must start with real (zero) unspent skill points, not a missing key"
	)


## Task 1: progression domain (award_party_xp, spend_attack_points,
## choose_perk) and the derived effective-hit/health/move calculations that
## GameSession centralizes for later battle and UI tasks to call into.

func test_award_party_xp_divides_a_five_point_award_evenly_between_two_members() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.recruit_adventurer()
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.assign_adventurer_to_selected_party("warrior_003")

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 5.0)

	assert_eq(session.get_adventurer("warrior_001").progression.xp, 2.5)
	assert_eq(session.get_adventurer("warrior_003").progression.xp, 2.5)


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
	assert_eq(warrior.stats.max_health, 20, "Leveling once should add exactly ten max health")
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

	assert_eq(session.get_effective_max_health("warrior_001"), 10)

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 20.0)

	assert_eq(session.get_effective_max_health("warrior_001"), 20)


func test_get_effective_move_range_adds_the_bonus_move_perk() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")

	assert_eq(session.get_effective_move_range("warrior_001"), 3)

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 50.0)
	session.choose_perk("warrior_001", "bonus_move")

	assert_eq(session.get_effective_move_range("warrior_001"), 4, "bonus_move grants one extra tile of movement")


## Task 4 (vacancy-timed population): a fresh campaign is sparse, and every
## cleared/hired slot refills only after its own category's wait, capped, and
## only using freshly-minted ids. See docs/plans/2026-08-06-campaign-
## progression-and-population/design.md's "Approved rules".

func test_reset_seeds_two_active_encounters_with_display_difficulty() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var active: Array[Dictionary] = session.get_active_encounters()

	assert_eq(active.size(), 2, "A fresh campaign starts with exactly two active encounter sites")

	# First: Goblin Camp
	assert_eq(active[0].id, GameSessionScript.GOBLIN_CAMP_ID, "First active instance should be Goblin Camp")
	assert_eq(active[0].template_id, GameSessionScript.GOBLIN_CAMP_ID)
	assert_eq(active[0].position, Vector2i(4, 4))
	assert_eq(active[0].difficulty, 1, "Goblin Camp should have difficulty 1")

	# Second: Orc Outpost
	assert_eq(active[1].id, GameSessionScript.ORC_OUTPOST_ID, "Second active instance should be Orc Outpost")
	assert_eq(active[1].template_id, GameSessionScript.ORC_OUTPOST_ID)
	assert_eq(active[1].position, Vector2i(4, 0))
	assert_eq(active[1].difficulty, 2, "Orc Outpost should have difficulty 2")


func test_reset_seeds_goblin_camp_first_among_two_encounters() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var active: Array[Dictionary] = session.get_active_encounters()

	assert_eq(active.size(), 2, "A fresh campaign starts with exactly two active encounter sites")
	assert_eq(active[0].id, GameSessionScript.GOBLIN_CAMP_ID, "Goblin Camp should be first in the stable seeding order")
	assert_eq(active[0].template_id, GameSessionScript.GOBLIN_CAMP_ID)
	assert_eq(active[0].position, Vector2i(4, 4))


func test_reset_seeds_exactly_one_active_warrior_recruitment_offer() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var candidates: Array[Dictionary] = session.get_recruitment_candidates()

	assert_eq(candidates.size(), 1, "A fresh campaign starts with exactly one recruitable Warrior")
	assert_eq(candidates[0].id, "warrior_002")


func test_reset_starts_with_zero_vacancy_clocks_running() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.encounter_vacancies, [] as Array[Dictionary])
	assert_eq(session.recruitment_vacancies, [] as Array[Dictionary])


func test_get_active_encounters_returns_a_copy_that_cannot_mutate_the_session() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var active: Array[Dictionary] = session.get_active_encounters()
	active[0].position = Vector2i(0, 0)

	assert_eq(
		session.get_active_encounters()[0].position,
		Vector2i(4, 4),
		"Mutating a returned active-encounter copy must not affect session state"
	)


## --- Encounter vacancy timing (design.md: 15-turn refill under a 2-site cap) ---

func test_clearing_goblin_camp_leaves_orc_outpost_active_and_starts_one_vacancy_timer() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	# Force the base result so this test keeps validating "one vacancy clock
	# starts at the documented base delay" rather than the jitter range
	# _resolve_vacancy_delay() now resolves (see vacancy_delay_roll).
	session.vacancy_delay_roll = func(_minimum: int, _maximum: int) -> int: return session.ENCOUNTER_VACANCY_TURNS

	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()

	var active: Array[Dictionary] = session.get_active_encounters()
	assert_eq(active.size(), 1, "Clearing Goblin Camp should leave exactly one active encounter")
	assert_eq(active[0].id, GameSessionScript.ORC_OUTPOST_ID, "The remaining active encounter should be Orc Outpost")
	assert_eq(session.encounter_vacancies.size(), 1, "Clearing Goblin Camp starts exactly one vacancy clock")
	assert_eq(session.encounter_vacancies[0].turns_remaining, session.ENCOUNTER_VACANCY_TURNS, "Vacancy clock should be 15 turns")


func test_clearing_the_active_encounter_removes_it_and_starts_one_vacancy_clock() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	# Force the base result -- see the sibling test above for why.
	session.vacancy_delay_roll = func(_minimum: int, _maximum: int) -> int: return session.ENCOUNTER_VACANCY_TURNS

	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()

	var active: Array[Dictionary] = session.get_active_encounters()
	assert_eq(active.size(), 1, "Clearing one of two sites leaves one active")
	assert_eq(active[0].id, GameSessionScript.ORC_OUTPOST_ID, "The remaining site should be Orc Outpost")
	assert_eq(session.encounter_vacancies.size(), 1, "Clearing a site starts exactly one vacancy clock")
	assert_eq(session.encounter_vacancies[0].turns_remaining, session.ENCOUNTER_VACANCY_TURNS)


## Given verbatim by the plan brief: proves _resolve_vacancy_delay() (Step 2)
## calls vacancy_delay_roll exactly once, with the documented inclusive
## encounter jitter bounds (base 15 +/- 5 => [10, 20]), and stores whatever
## it returns -- here the forced minimum -- as the vacancy's turns_remaining.
func test_encounter_vacancy_rolls_the_inclusive_base_plus_or_minus_jitter_once() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	# A single-element Array, not a plain int: GDScript lambdas capture
	# enclosing locals by value, so a plain "var calls := 0" mutated inside
	# the Callable would never be visible out here. The Array is captured by
	# reference to the same underlying object, so mutating its contents is.
	var calls := [0]
	session.vacancy_delay_roll = func(minimum: int, maximum: int) -> int:
		calls[0] += 1
		assert_eq(minimum, 10)
		assert_eq(maximum, 20)
		return minimum

	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()

	assert_eq(calls[0], 1)
	assert_eq(session.encounter_vacancies[0].turns_remaining, 10)


## Mirrors the encounter test above for the recruitment category (base 30
## +/- 5 => [25, 35]), forcing the upper bound instead of the lower one.
func test_recruitment_vacancy_rolls_the_inclusive_base_plus_or_minus_jitter_once() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	# See test_encounter_vacancy_rolls_the_inclusive_base_plus_or_minus_jitter_once
	# for why this is an Array rather than a plain int.
	var calls := [0]
	session.vacancy_delay_roll = func(minimum: int, maximum: int) -> int:
		calls[0] += 1
		assert_eq(minimum, 25)
		assert_eq(maximum, 35)
		return maximum
	session.gold = 10

	session.purchase_recruit("warrior_002")

	assert_eq(calls[0], 1)
	assert_eq(session.recruitment_vacancies[0].turns_remaining, 35)


## A forced roll landing back on the base value (not just an extreme) must
## still be the number actually stored -- proves _resolve_vacancy_delay()
## stores the roll's return value verbatim rather than, say, always adding
## the jitter offset.
func test_encounter_vacancy_stores_the_base_delay_when_the_roll_returns_it() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.vacancy_delay_roll = func(_minimum: int, _maximum: int) -> int: return 15

	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()

	assert_eq(session.encounter_vacancies[0].turns_remaining, 15)


func test_recruitment_vacancy_stores_the_base_delay_when_the_roll_returns_it() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.vacancy_delay_roll = func(_minimum: int, _maximum: int) -> int: return 30
	session.gold = 10

	session.purchase_recruit("warrior_002")

	assert_eq(session.recruitment_vacancies[0].turns_remaining, 30)


## The delay is resolved once, at vacancy-open time, not rerolled on every
## tick -- _advance_encounter_vacancies() must only decrement turns_remaining,
## never call vacancy_delay_roll again while a vacancy is pending.
func test_encounter_vacancy_only_rolls_once_while_ticking_across_several_turns() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	# See test_encounter_vacancy_rolls_the_inclusive_base_plus_or_minus_jitter_once
	# for why this is an Array rather than a plain int.
	var calls := [0]
	session.vacancy_delay_roll = func(_minimum: int, _maximum: int) -> int:
		calls[0] += 1
		return 15

	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	assert_eq(calls[0], 1, "Opening the vacancy resolves the delay exactly once")

	for i in 5:
		session.end_world_turn()

	assert_eq(calls[0], 1, "Ticking down an already-open vacancy must not reroll its delay")


func test_encounter_vacancy_does_not_refill_before_turn_fifteen() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	# Force the base result so this test keeps validating tick/refill timing
	# rather than the jitter range _resolve_vacancy_delay() now resolves (see
	# vacancy_delay_roll and its dedicated jitter tests above).
	session.vacancy_delay_roll = func(_minimum: int, _maximum: int) -> int: return session.ENCOUNTER_VACANCY_TURNS
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()

	for i in session.ENCOUNTER_VACANCY_TURNS - 1:
		session.end_world_turn()

	var active: Array[Dictionary] = session.get_active_encounters()
	assert_eq(
		active.size(),
		1,
		"14 turns after clearing Goblin Camp must not yet refill; only Orc Outpost remains"
	)
	assert_eq(active[0].id, GameSessionScript.ORC_OUTPOST_ID, "Orc Outpost should still be active")
	assert_eq(session.encounter_vacancies.size(), 1, "The clock must still be pending")


func test_encounter_vacancy_refills_exactly_at_turn_fifteen() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	# Force the base result -- see test_encounter_vacancy_does_not_refill_before_turn_fifteen.
	session.vacancy_delay_roll = func(_minimum: int, _maximum: int) -> int: return session.ENCOUNTER_VACANCY_TURNS
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	# Force the weighted refill toward goblin_camp (the tier-1 candidate) so
	# this test stays deterministic rather than depending on
	# _choose_encounter_template()'s real randomness (see star_weight_roll).
	session.star_weight_roll = func(_total_weight: int) -> int: return 0

	for i in session.ENCOUNTER_VACANCY_TURNS:
		session.end_world_turn()

	var active: Array[Dictionary] = session.get_active_encounters()
	assert_eq(active.size(), 2, "The 15th turn after clearing should refill one site; Orc Outpost + new Goblin Camp")
	assert_eq(session.encounter_vacancies, [] as Array[Dictionary], "A fired clock is consumed, not rescheduled")
	assert_true(
		session.completed_encounters.has(GameSessionScript.GOBLIN_CAMP_ID),
		"The cleared site must never reopen"
	)
	# Check that we have Orc Outpost and a new Goblin Camp instance
	var has_orc_outpost: bool = false
	var has_new_goblin_instance: bool = false
	for instance in active:
		if instance.id == GameSessionScript.ORC_OUTPOST_ID:
			has_orc_outpost = true
		elif instance.template_id == GameSessionScript.GOBLIN_CAMP_ID and instance.id != GameSessionScript.GOBLIN_CAMP_ID:
			has_new_goblin_instance = true
	assert_true(has_orc_outpost, "Orc Outpost should still be active")
	assert_true(has_new_goblin_instance, "A new Goblin Camp instance should be spawned")


## Regression test: a refill used to pick a template's documented static
## position whenever that position was not held by a *currently active*
## instance — but a cleared instance is removed from active_encounters
## immediately. Since reset() now seeds _used_encounter_template_ids with
## both template ids, a refilled template's template_previously_spawned flag
## is true on the very first refill, forcing _choose_encounter_position to
## search for an alternative rather than respawning on the exact cleared
## tile (which design.md's approved rules explicitly forbid).
func test_encounter_refill_does_not_reuse_the_original_cleared_tile() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	# Record Goblin Camp's original position before clearing it
	var original_goblin_position: Vector2i = Vector2i(4, 4)
	var goblin_instance_id: String = GameSessionScript.GOBLIN_CAMP_ID

	# Clear Goblin Camp and wait for refill. The new instance must not spawn
	# at (4, 4) even though that position is now empty, because Goblin Camp
	# is marked as previously-spawned in _used_encounter_template_ids.
	# Force the base delay so this test's turn loop still lands on the exact
	# refill turn rather than depending on the jitter range
	# _resolve_vacancy_delay() now resolves (see vacancy_delay_roll).
	session.vacancy_delay_roll = func(_minimum: int, _maximum: int) -> int: return session.ENCOUNTER_VACANCY_TURNS
	session.enter_encounter(goblin_instance_id)
	session.complete_current_encounter()
	# Force the weighted refill toward goblin_camp (the tier-1 candidate) so
	# this test stays deterministic rather than depending on
	# _choose_encounter_template()'s real randomness (see star_weight_roll).
	session.star_weight_roll = func(_total_weight: int) -> int: return 0
	for i in session.ENCOUNTER_VACANCY_TURNS:
		session.end_world_turn()

	var active: Array[Dictionary] = session.get_active_encounters()
	assert_eq(active.size(), 2, "After refill: Orc Outpost + new Goblin Camp instance")

	# Find the new Goblin Camp instance and verify its position differs from the original
	var new_goblin_position: Vector2i = Vector2i(-1, -1)
	for instance in active:
		if instance.template_id == GameSessionScript.GOBLIN_CAMP_ID and instance.id != goblin_instance_id:
			new_goblin_position = instance.position
			break

	assert_ne(
		new_goblin_position,
		original_goblin_position,
		"A refilled template must not respawn on the exact tile it was just cleared from"
	)
	assert_ne(
		new_goblin_position,
		Vector2i(-1, -1),
		"A new Goblin Camp instance should have been spawned at a valid position"
	)


## Regression test: the fallback scan inside _choose_encounter_position only
## fires once a refilled template's documented position is unusable (occupied
## or, as here, previously spawned). Both templates are marked
## previously-spawned from turn one (reset() seeds _used_encounter_template_ids
## with both ids), so a refill's fallback scan fires on the very first
## vacancy, not just after every template has cycled once. A naive ascending,
## row-major scan starting at (0, 0) would hand back (1, 0) — one tile from
## STARTING_SETTLEMENT_WORLD_POSITION at (0, 0) — even though both documented
## encounter positions, (4, 4) and (4, 0), sit at the far side of the grid.
## The scan must instead search far-corner-first so a refilled site keeps
## landing away from the map's center — where the Encampment now sits —
## rather than immediately adjacent to it.
func test_encounter_refill_fallback_scan_avoids_near_settlement_positions() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	# Clear Orc Outpost; Goblin Camp remains active at its documented (4, 4),
	# occupying the far corner the scan should otherwise prefer first and
	# forcing it to keep searching rather than trivially reusing (4, 4).
	# Force the base delay -- see test_encounter_refill_does_not_reuse_the_original_cleared_tile.
	session.vacancy_delay_roll = func(_minimum: int, _maximum: int) -> int: return session.ENCOUNTER_VACANCY_TURNS
	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)
	session.complete_current_encounter()
	# Force the weighted refill toward orc_outpost (the tier-2 candidate, first
	# in ENCOUNTER_TEMPLATE_ORDER once goblin_camp is excluded as already
	# active) so this test stays deterministic rather than depending on
	# _choose_encounter_template()'s real randomness (see star_weight_roll).
	session.star_weight_roll = func(_total_weight: int) -> int: return 0
	for i in session.ENCOUNTER_VACANCY_TURNS:
		session.end_world_turn()

	var active: Array[Dictionary] = session.get_active_encounters()
	var new_orc_position: Vector2i = Vector2i(-1, -1)
	for instance in active:
		if instance.template_id == GameSessionScript.ORC_OUTPOST_ID:
			new_orc_position = instance.position
			break

	assert_eq(
		new_orc_position,
		Vector2i(6, 6),
		"A far-corner-first fallback scan should land the refill at the far corner it starts from"
	)
	assert_ne(
		new_orc_position,
		Vector2i(4, 3),
		"The refill must not land one tile from the settlement"
	)
	assert_ne(
		new_orc_position,
		Vector2i(3, 4),
		"The refill must not land one tile from the settlement"
	)


func test_encounter_refill_is_capped_at_two_active_sites_with_no_catch_up() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	# We already start with two active sites (Goblin Camp and Orc Outpost),
	# so we just need to add a pending clock about to fire to test the cap.
	# The organic single-party flow cannot reach two simultaneously-pending
	# clocks in one battle (clearing always frees a slot before a second
	# clearing can happen), so this exercises the guard the same way the
	# game's own longer-run state eventually could.
	assert_eq(session.get_active_encounters().size(), 2)
	session.encounter_vacancies.append({"turns_remaining": 1})

	session.end_world_turn()

	assert_eq(
		session.get_active_encounters().size(),
		2,
		"A refill must never push active encounters above the cap"
	)
	assert_eq(
		session.encounter_vacancies,
		[] as Array[Dictionary],
		"A clock blocked by the cap is discarded, not rescheduled or caught up later"
	)

	for i in 5:
		session.end_world_turn()
	assert_eq(session.get_active_encounters().size(), 2, "A capped, discarded vacancy must never catch up")


func test_no_new_encounter_vacancy_clock_starts_while_already_at_capacity() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	# We already start with two active sites (Goblin Camp and Orc Outpost)
	assert_eq(session.get_active_encounters().size(), 2, "Both slots are active before this event")

	session._start_encounter_vacancy()

	assert_eq(
		session.encounter_vacancies,
		[] as Array[Dictionary],
		"No new cooldown starts while the category is already at capacity"
	)


## --- Recruitment vacancy timing (design.md: 30-turn refill under a 4-offer cap) ---

func test_a_successful_purchase_starts_one_thirty_turn_recruitment_vacancy_clock() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	# Force the base result so this test keeps validating "a purchase starts
	# one vacancy clock at the documented base delay" rather than the jitter
	# range _resolve_vacancy_delay() now resolves (see vacancy_delay_roll and
	# its dedicated jitter tests above).
	session.vacancy_delay_roll = func(_minimum: int, _maximum: int) -> int: return session.RECRUITMENT_VACANCY_TURNS
	session.gold = 10

	session.purchase_recruit("warrior_002")

	assert_eq(session.recruitment_vacancies.size(), 1)
	assert_eq(session.recruitment_vacancies[0].turns_remaining, session.RECRUITMENT_VACANCY_TURNS)


func test_a_failed_purchase_starts_no_recruitment_vacancy_clock() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_false(session.purchase_recruit("warrior_002"), "Zero gold should reject the purchase")

	assert_eq(session.recruitment_vacancies, [] as Array[Dictionary])


func test_recruitment_vacancy_does_not_refill_before_turn_thirty() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	# Force the base result -- see test_a_successful_purchase_starts_one_thirty_turn_recruitment_vacancy_clock.
	session.vacancy_delay_roll = func(_minimum: int, _maximum: int) -> int: return session.RECRUITMENT_VACANCY_TURNS
	session.gold = 10
	session.purchase_recruit("warrior_002")

	for i in session.RECRUITMENT_VACANCY_TURNS - 1:
		session.end_world_turn()

	assert_eq(session.get_recruitment_candidates(), [] as Array[Dictionary])
	assert_eq(session.recruitment_vacancies.size(), 1)


func test_recruitment_vacancy_refills_exactly_at_turn_thirty_under_the_cap() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	# Force the base result -- see test_a_successful_purchase_starts_one_thirty_turn_recruitment_vacancy_clock.
	session.vacancy_delay_roll = func(_minimum: int, _maximum: int) -> int: return session.RECRUITMENT_VACANCY_TURNS
	session.gold = 10
	session.purchase_recruit("warrior_002")

	for i in session.RECRUITMENT_VACANCY_TURNS:
		session.end_world_turn()

	var candidates: Array[Dictionary] = session.get_recruitment_candidates()
	assert_eq(candidates.size(), 1, "Turn 30 after the purchase should refill exactly one new offer")
	assert_eq(candidates[0].id, "warrior_003", "Deterministic refill picks the next fixed template in order")
	assert_eq(session.recruitment_vacancies, [] as Array[Dictionary], "A fired clock is consumed, not rescheduled")


func test_recruitment_refill_is_capped_at_four_offers_with_no_catch_up() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.recruitment_candidates = [
		_recruitment_candidate("warrior_002"),
		_recruitment_candidate("warrior_003"),
		_recruitment_candidate("warrior_004"),
		_recruitment_candidate("warrior_010"),
	] as Array[Dictionary]
	assert_eq(session.get_recruitment_candidates().size(), 4)
	session.recruitment_vacancies.append({"turns_remaining": 1})

	session.end_world_turn()

	assert_eq(
		session.get_recruitment_candidates().size(),
		4,
		"A refill must never push active offers above the cap"
	)
	assert_eq(
		session.recruitment_vacancies,
		[] as Array[Dictionary],
		"A clock blocked by the cap is discarded, not rescheduled or caught up later"
	)

	for i in 5:
		session.end_world_turn()
	assert_eq(session.get_recruitment_candidates().size(), 4, "A capped, discarded vacancy must never catch up")


func test_no_new_recruitment_vacancy_clock_starts_while_already_at_capacity() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.recruitment_candidates = [
		_recruitment_candidate("warrior_002"),
		_recruitment_candidate("warrior_003"),
		_recruitment_candidate("warrior_004"),
		_recruitment_candidate("warrior_010"),
	] as Array[Dictionary]

	session._start_recruitment_vacancy()

	assert_eq(
		session.recruitment_vacancies,
		[] as Array[Dictionary],
		"No new cooldown starts while the category is already at capacity"
	)


## --- Generated-id collision safety ---

func test_generated_encounter_instance_ids_never_collide_with_historical_ones() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.completed_encounters.append("encounter_001")
	# Force the base delay so this test's turn loop still lands on the exact
	# refill turn rather than depending on the jitter range
	# _resolve_vacancy_delay() now resolves (see vacancy_delay_roll).
	session.vacancy_delay_roll = func(_minimum: int, _maximum: int) -> int: return session.ENCOUNTER_VACANCY_TURNS

	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)
	session.complete_current_encounter()
	# Force the weighted refill toward the lowest star tier (goblin_camp is the
	# only tier-1 candidate once Orc Outpost is excluded as already active) so
	# this id-collision test stays deterministic rather than depending on
	# _choose_encounter_template()'s real randomness (see star_weight_roll).
	session.star_weight_roll = func(_total_weight: int) -> int: return 0
	for i in session.ENCOUNTER_VACANCY_TURNS:
		session.end_world_turn()

	var active: Array[Dictionary] = session.get_active_encounters()
	assert_eq(active.size(), 2, "After clearing Goblin Camp and refilling: Orc Outpost + new Goblin Camp instance")

	# Find the new Goblin Camp instance (should be a generated id)
	var new_goblin_id: String = ""
	for instance in active:
		if instance.template_id == GameSessionScript.GOBLIN_CAMP_ID and instance.id != GameSessionScript.GOBLIN_CAMP_ID:
			new_goblin_id = instance.id
			break

	assert_ne(
		new_goblin_id,
		"encounter_001",
		"A freshly minted instance id must skip one already recorded as historically cleared"
	)
	assert_ne(new_goblin_id, "", "A new Goblin Camp instance should have been generated")


func test_generated_recruitment_offer_ids_never_collide_with_the_roster_or_live_offers() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	# Exhaust every fixed template (warrior_002/003/004) as roster members, so
	# the overflow mint path must synthesize a fresh id.
	session.adventurers.append(_adventurer("warrior_002", "available"))
	session.adventurers.append(_adventurer("warrior_003", "available"))
	session.adventurers.append(_adventurer("warrior_004", "available"))
	session.recruitment_candidates = [] as Array[Dictionary]
	session.recruitment_vacancies.append({"turns_remaining": 1})

	session.end_world_turn()

	var candidates: Array[Dictionary] = session.get_recruitment_candidates()
	assert_eq(candidates.size(), 1, "The overflow mint path must still deliver exactly one new offer")
	var new_id: String = candidates[0].id
	assert_false(
		["warrior_002", "warrior_003", "warrior_004"].has(new_id),
		"The overflow id must not reuse an already-claimed fixed template id"
	)
	var all_ids: Array = []
	for adventurer in session.adventurers:
		all_ids.append(adventurer.id)
	assert_false(all_ids.has(new_id), "A generated offer id must never collide with a roster adventurer")


## Task 1 (guild hall domain): party-size cap driven by guild hall level, with
## an upgrade rule and enforcement in assign_adventurer_to_party().

func test_new_session_starts_at_guild_hall_level_one() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.guild_hall_level, 1)


func test_reset_restores_guild_hall_level_to_one() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.guild_hall_level = 2

	session.reset()

	assert_eq(session.guild_hall_level, 1)


func test_get_max_party_size_returns_four_at_level_one() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.get_max_party_size(), 4)


func test_get_max_party_size_returns_five_at_level_two() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.guild_hall_level = 2

	assert_eq(session.get_max_party_size(), 5)


func test_upgrade_guild_hall_with_fifty_gold_succeeds() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 50

	assert_true(session.upgrade_guild_hall())

	assert_eq(session.guild_hall_level, 2)
	assert_eq(session.gold, 0)
	assert_eq(session.get_max_party_size(), 5)


func test_upgrade_guild_hall_with_forty_nine_gold_fails() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 49

	assert_false(session.upgrade_guild_hall())

	assert_eq(session.guild_hall_level, 1)
	assert_eq(session.gold, 49)


func test_upgrade_guild_hall_at_max_level_returns_false() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 100
	session.upgrade_guild_hall()

	assert_false(session.upgrade_guild_hall())

	assert_eq(session.gold, 50, "Gold should not be deducted on a failed upgrade after first success")
	assert_eq(session.guild_hall_level, 2)


func test_can_upgrade_guild_hall_is_false_with_no_gold() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_false(session.can_upgrade_guild_hall())


func test_can_upgrade_guild_hall_is_true_with_fifty_gold() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 50

	assert_true(session.can_upgrade_guild_hall())


func test_can_upgrade_guild_hall_is_false_at_max_level() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 50
	session.upgrade_guild_hall()

	assert_false(session.can_upgrade_guild_hall())


func test_assign_adventurer_to_party_rejects_fifth_member_at_level_one() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.adventurers.append(_adventurer("test_001", "available"))
	session.adventurers.append(_adventurer("test_002", "available"))
	session.adventurers.append(_adventurer("test_003", "available"))

	session.adventurers.append(_adventurer("test_004", "available"))

	assert_true(session.assign_adventurer_to_selected_party("test_001"))
	assert_true(session.assign_adventurer_to_selected_party("test_002"))
	assert_true(session.assign_adventurer_to_selected_party("test_003"))
	assert_false(session.assign_adventurer_to_selected_party("test_004"), "Fifth member must be rejected at level 1")

	assert_eq(session.get_selected_party().member_ids.size(), 4)


func test_assign_adventurer_to_party_accepts_fifth_member_after_upgrade() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.adventurers.append(_adventurer("test_001", "available"))
	session.adventurers.append(_adventurer("test_002", "available"))
	session.adventurers.append(_adventurer("test_003", "available"))
	session.adventurers.append(_adventurer("test_004", "available"))

	assert_true(session.assign_adventurer_to_selected_party("test_001"))
	assert_true(session.assign_adventurer_to_selected_party("test_002"))
	assert_true(session.assign_adventurer_to_selected_party("test_003"))
	session.gold = 50
	session.upgrade_guild_hall()

	assert_true(session.assign_adventurer_to_selected_party("test_004"), "Fifth member must be accepted after upgrade")

	assert_eq(session.get_selected_party().member_ids.size(), 5)


## _load_balance_config() is what wires GameConfig into the balance vars, and
## it only runs from _ready(). Comparing the already-loaded singleton against
## GameConfig would be tautological (the hardcoded initializers happen to equal
## the shipped JSON today), so instead build a bare session that never entered
## the tree, poison the migrated vars with an impossible sentinel, and prove
## the call itself overwrites each one from the config.
func test_load_balance_config_populates_every_section_from_game_config() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	const SENTINEL := -12345
	session.BASE_MOVE_RANGE = SENTINEL
	session.PERK_LEVEL_INTERVAL = SENTINEL
	session.GUILD_HALL_UPGRADE_COST = SENTINEL
	session.ENCOUNTER_VACANCY_TURNS = SENTINEL
	session.EFFECTIVE_HIT_CHANCE_CAP = float(SENTINEL)

	session._load_balance_config()

	assert_eq(
		session.BASE_MOVE_RANGE,
		GameConfig.get_int("combat", "base_move_range", SENTINEL),
		"combat.base_move_range must come from GameConfig, not the hardcoded initializer"
	)
	assert_eq(
		session.PERK_LEVEL_INTERVAL,
		GameConfig.get_int("progression", "perk_level_interval", SENTINEL),
		"progression.perk_level_interval must come from GameConfig"
	)
	assert_eq(
		session.GUILD_HALL_UPGRADE_COST,
		GameConfig.get_int("guild_hall", "upgrade_cost", SENTINEL),
		"guild_hall.upgrade_cost must come from GameConfig"
	)
	assert_eq(
		session.ENCOUNTER_VACANCY_TURNS,
		GameConfig.get_int("population", "encounter_vacancy_turns", SENTINEL),
		"population.encounter_vacancy_turns must come from GameConfig"
	)
	assert_almost_eq(
		session.EFFECTIVE_HIT_CHANCE_CAP,
		GameConfig.get_float("combat", "effective_hit_chance_cap", float(SENTINEL)),
		0.0001,
		"combat.effective_hit_chance_cap must come from GameConfig"
	)
	assert_ne(session.BASE_MOVE_RANGE, SENTINEL, "The sentinel must have been overwritten, not left in place")


func test_weapons_catalog_has_the_documented_iron_and_steel_damage_and_price() -> void:
	assert_eq(GameSessionScript.WEAPONS.dagger_iron, {"name_key": "item.dagger_iron", "slot": "weapon", "damage_min": 1, "damage_max": 4, "price": 10})
	assert_eq(GameSessionScript.WEAPONS.dagger_steel, {"name_key": "item.dagger_steel", "slot": "weapon", "damage_min": 2, "damage_max": 5, "price": 30})
	assert_eq(GameSessionScript.WEAPONS.shortsword_iron, {"name_key": "item.shortsword_iron", "slot": "weapon", "damage_min": 1, "damage_max": 6, "price": 20})
	assert_eq(GameSessionScript.WEAPONS.shortsword_steel, {"name_key": "item.shortsword_steel", "slot": "weapon", "damage_min": 2, "damage_max": 7, "price": 60})
	assert_eq(GameSessionScript.WEAPONS.longsword_iron, {"name_key": "item.longsword_iron", "slot": "weapon", "damage_min": 1, "damage_max": 8, "price": 30})
	assert_eq(GameSessionScript.WEAPONS.longsword_steel, {"name_key": "item.longsword_steel", "slot": "weapon", "damage_min": 2, "damage_max": 9, "price": 90})
	assert_eq(GameSessionScript.WEAPONS.two_handed_sword_iron, {"name_key": "item.two_handed_sword_iron", "slot": "weapon", "damage_min": 1, "damage_max": 10, "price": 35})
	assert_eq(GameSessionScript.WEAPONS.two_handed_sword_steel, {"name_key": "item.two_handed_sword_steel", "slot": "weapon", "damage_min": 2, "damage_max": 11, "price": 105})


func test_armors_catalog_has_the_documented_defense_resistance_and_price() -> void:
	assert_eq(GameSessionScript.ARMORS.leather_armor, {"name_key": "item.leather_armor", "slot": "armor", "defense": 10, "resistance": 10, "price": 10})
	assert_eq(GameSessionScript.ARMORS.chainmail_armor, {"name_key": "item.chainmail_armor", "slot": "armor", "defense": 15, "resistance": 20, "price": 30})
	assert_eq(GameSessionScript.ARMORS.split_armor, {"name_key": "item.split_armor", "slot": "armor", "defense": 15, "resistance": 25, "price": 50})
	assert_eq(GameSessionScript.ARMORS.platemail_armor, {"name_key": "item.platemail_armor", "slot": "armor", "defense": 15, "resistance": 30, "price": 200})
	assert_eq(GameSessionScript.ARMORS.full_plate_armor, {"name_key": "item.full_plate_armor", "slot": "armor", "defense": 15, "resistance": 35, "price": 500})


func test_get_item_definition_finds_a_weapon_then_an_armor_then_returns_empty() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.get_item_definition("longsword_iron"), GameSessionScript.WEAPONS.longsword_iron)
	assert_eq(session.get_item_definition("leather_armor"), GameSessionScript.ARMORS.leather_armor)
	assert_eq(session.get_item_definition("no_such_item"), {})


func test_default_warrior_starts_with_an_iron_longsword_and_leather_armor() -> void:
	var warrior: Dictionary = GameSession.get_default_warrior()

	assert_eq(
		warrior.equipment,
		{
			"weapon": "longsword_iron", "weapon_inventory": ["longsword_iron"],
			"armor": "leather_armor", "armor_inventory": ["leather_armor"],
		}
	)


func test_effective_weapon_damage_range_and_name_come_from_the_equipped_weapon() -> void:
	assert_eq(GameSession.get_effective_weapon_damage_range(GameSession.WARRIOR_ID), Vector2i(1, 8))
	assert_eq(GameSession.get_effective_weapon_name(GameSession.WARRIOR_ID), "Iron Longsword")


func test_effective_armor_name_comes_from_the_equipped_armor() -> void:
	assert_eq(GameSession.get_effective_armor_name(GameSession.WARRIOR_ID), "Leather Armor")


func test_effective_armor_name_returns_empty_for_an_unknown_adventurer() -> void:
	assert_eq(GameSession.get_effective_armor_name("no_such_id"), "")


func test_effective_defense_and_resistance_come_from_the_equipped_armor() -> void:
	assert_eq(GameSession.get_effective_defense(GameSession.WARRIOR_ID), 10)
	assert_eq(GameSession.get_effective_resistance(GameSession.WARRIOR_ID), 10)


func test_effective_equipment_getters_return_zero_for_an_unknown_adventurer() -> void:
	assert_eq(GameSession.get_effective_weapon_damage_range("no_such_id"), Vector2i.ZERO)
	assert_eq(GameSession.get_effective_weapon_name("no_such_id"), "")
	assert_eq(GameSession.get_effective_defense("no_such_id"), 0)
	assert_eq(GameSession.get_effective_resistance("no_such_id"), 0)



func test_enemy_loot_tables_match_the_documented_gold_mana_crystal_tier_and_gear() -> void:
	assert_eq(GameSessionScript.ENEMY_LOOT_TABLES.kobold, {"gold_min": 0, "gold_max": 5, "gold_multiplier": 1, "mana_crystal_tier": 1, "gear_item_id": "dagger_iron"})
	assert_eq(GameSessionScript.ENEMY_LOOT_TABLES.goblin, {"gold_min": 1, "gold_max": 6, "gold_multiplier": 1, "mana_crystal_tier": 1, "gear_item_id": "shortsword_iron"})
	assert_eq(GameSessionScript.ENEMY_LOOT_TABLES.orc, {"gold_min": 1, "gold_max": 5, "gold_multiplier": 2, "mana_crystal_tier": 2, "gear_item_id": "longsword_iron"})
	assert_eq(GameSessionScript.ENEMY_LOOT_TABLES.hobgoblin, {"gold_min": 1, "gold_max": 4, "gold_multiplier": 3, "mana_crystal_tier": 2, "gear_item_id": "two_handed_sword_iron"})


func test_mana_crystal_values_match_the_documented_tiers() -> void:
	assert_eq(GameSessionScript.MANA_CRYSTAL_VALUES, {1: 5, 2: 15})


func test_goblin_and_orc_enemy_stats_carry_their_loot_id() -> void:
	assert_eq(GameSessionScript.GOBLIN_ENEMY_STATS.loot_id, "goblin")
	assert_eq(GameSessionScript.ORC_ENEMY_STATS.loot_id, "orc")


func test_goblin_and_orc_enemy_stats_carry_their_kill_xp() -> void:
	assert_eq(GameSessionScript.GOBLIN_ENEMY_STATS.kill_xp, 5)
	assert_eq(GameSessionScript.ORC_ENEMY_STATS.kill_xp, 10)


func test_kobold_enemy_stats_are_the_weakest_tier() -> void:
	assert_eq(GameSessionScript.KOBOLD_ENEMY_STATS.max_health, 6)
	assert_eq(GameSessionScript.KOBOLD_ENEMY_STATS.attack_damage, 1)
	assert_eq(GameSessionScript.KOBOLD_ENEMY_STATS.hit_chance, 0.25)
	assert_eq(GameSessionScript.KOBOLD_ENEMY_STATS.name_key, "battle.enemy.kobold")
	assert_eq(GameSessionScript.KOBOLD_ENEMY_STATS.attack_name_key, "battle.enemy.kobold.attack")
	assert_eq(GameSessionScript.KOBOLD_ENEMY_STATS.loot_id, "kobold")
	assert_eq(GameSessionScript.KOBOLD_ENEMY_STATS.kill_xp, 3)


func test_hobgoblin_enemy_stats_are_the_strongest_tier() -> void:
	assert_eq(GameSessionScript.HOBGOBLIN_ENEMY_STATS.max_health, 30)
	assert_eq(GameSessionScript.HOBGOBLIN_ENEMY_STATS.attack_damage, 4)
	assert_eq(GameSessionScript.HOBGOBLIN_ENEMY_STATS.hit_chance, 0.6)
	assert_eq(GameSessionScript.HOBGOBLIN_ENEMY_STATS.name_key, "battle.enemy.hobgoblin")
	assert_eq(GameSessionScript.HOBGOBLIN_ENEMY_STATS.attack_name_key, "battle.enemy.hobgoblin.attack")
	assert_eq(GameSessionScript.HOBGOBLIN_ENEMY_STATS.loot_id, "hobgoblin")
	assert_eq(GameSessionScript.HOBGOBLIN_ENEMY_STATS.kill_xp, 20)


func test_kobold_and_hobgoblin_loot_ids_already_have_loot_table_rows() -> void:
	assert_true(GameSessionScript.ENEMY_LOOT_TABLES.has(GameSessionScript.KOBOLD_ENEMY_STATS.loot_id))
	assert_true(GameSessionScript.ENEMY_LOOT_TABLES.has(GameSessionScript.HOBGOBLIN_ENEMY_STATS.loot_id))


func test_new_session_has_no_trading_post() -> void:
	assert_false(GameSession.has_trading_post)


func test_can_purchase_trading_post_requires_enough_gold_and_not_already_owning_one() -> void:
	assert_false(GameSession.can_purchase_trading_post(), "No gold, cannot afford it")

	GameSession.gold = GameSession.TRADING_POST_PURCHASE_COST
	assert_true(GameSession.can_purchase_trading_post())

	GameSession.purchase_trading_post()
	assert_false(GameSession.can_purchase_trading_post(), "Already owning one blocks a second purchase")


func test_purchase_trading_post_deducts_gold_and_sets_the_flag_once() -> void:
	GameSession.reset()
	GameSession.gold = GameSession.TRADING_POST_PURCHASE_COST

	var purchased: bool = GameSession.purchase_trading_post()

	assert_true(purchased)
	assert_true(GameSession.has_trading_post)
	assert_eq(GameSession.gold, 0)
	assert_false(GameSession.purchase_trading_post(), "A second purchase must fail")


func test_end_world_turn_adds_trading_post_income_only_once_purchased() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.end_world_turn()
	assert_eq(GameSession.gold, 0, "No income without a Trading Post")

	GameSession.gold = GameSession.TRADING_POST_PURCHASE_COST
	GameSession.purchase_trading_post()
	GameSession.end_world_turn()

	assert_eq(GameSession.gold, GameSession.TRADING_POST_INCOME_PER_TURN)


func test_get_item_sale_price_halves_gear_price_and_keeps_mana_crystal_value_full() -> void:
	assert_eq(GameSession.get_item_sale_price("shortsword_iron"), 10, "Half of 20")
	assert_eq(GameSession.get_item_sale_price("leather_armor"), 5, "Half of 10")
	assert_eq(GameSession.get_item_sale_price("mana_crystal_1"), 5)
	assert_eq(GameSession.get_item_sale_price("mana_crystal_2"), 15)
	assert_eq(GameSession.get_item_sale_price("no_such_item"), 0)


func test_build_loot_rows_builds_a_gear_row_and_a_mana_crystal_row() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var rows: Array[Dictionary] = session.build_loot_rows({"shortsword_iron": 3}, {1: 2})

	assert_eq(rows.size(), 2)
	assert_eq(rows[0], {"id": "shortsword_iron", "name": "Iron Shortsword", "type": "Weapon", "count": 3, "price": 10})
	assert_eq(
		rows[1],
		{"id": "mana_crystal_1", "name": "Mana Crystal (Tier 1)", "type": "Mana Crystal", "count": 2, "price": 5}
	)


func test_build_loot_rows_skips_zero_and_negative_counts() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var rows: Array[Dictionary] = session.build_loot_rows({"shortsword_iron": 0}, {1: -1})

	assert_eq(rows, [] as Array[Dictionary])


func test_sell_item_requires_a_trading_post_and_enough_stock() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"shortsword_iron": 1}

	assert_false(GameSession.sell_item("shortsword_iron"), "No Trading Post yet")

	GameSession.has_trading_post = true
	assert_false(GameSession.sell_item("shortsword_iron", 2), "Only 1 in stock")

	var sold: bool = GameSession.sell_item("shortsword_iron", 1)
	assert_true(sold)
	assert_eq(GameSession.banked_gear.shortsword_iron, 0)
	assert_eq(GameSession.gold, 10)


func test_sell_item_handles_mana_crystals() -> void:
	GameSession.reset()
	GameSession.has_trading_post = true
	GameSession.mana_crystals = {1: 2}

	var sold: bool = GameSession.sell_item("mana_crystal_1", 2)

	assert_true(sold)
	assert_eq(GameSession.mana_crystals[1], 0)
	assert_eq(GameSession.gold, 10)


func test_buy_item_requires_a_trading_post_and_enough_gold_then_banks_the_item() -> void:
	GameSession.reset()
	assert_false(GameSession.buy_item("dagger_iron"), "No Trading Post yet")

	GameSession.has_trading_post = true
	assert_false(GameSession.buy_item("dagger_iron"), "No gold yet")

	GameSession.gold = 10
	var bought: bool = GameSession.buy_item("dagger_iron")

	assert_true(bought)
	assert_eq(GameSession.gold, 0)
	assert_eq(GameSession.banked_gear.dagger_iron, 1)


func test_equip_item_from_bank_adds_the_new_item_and_activates_it_without_evicting_the_old_one() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"dagger_steel": 1}

	var equipped: bool = GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")

	assert_true(equipped)
	var equipment: Dictionary = GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment
	assert_eq(equipment.weapon, "dagger_steel", "The newly-equipped item becomes active")
	assert_eq(
		equipment.weapon_inventory, ["longsword_iron", "dagger_steel"],
		"The starting Iron Longsword stays carried, not evicted to the bank"
	)
	assert_eq(GameSession.banked_gear.dagger_steel, 0, "The new item leaves the bank")
	assert_eq(
		GameSession.banked_gear.get("longsword_iron", 0), 0,
		"The previously-active Iron Longsword must NOT reappear in the bank"
	)


func test_equipping_an_already_carried_item_reactivates_it_without_touching_the_bank() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"dagger_steel": 2}
	GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")
	# A second Steel Dagger sits in the bank; the unit already carries one.
	assert_eq(GameSession.banked_gear.dagger_steel, 1)
	# Switch back to the Iron Longsword (now inactive but still carried) via
	# activate_carried_item, not equip_item_from_bank -- the Iron Longsword
	# was never itself in the bank, so equip_item_from_bank would correctly
	# reject it here (see the "Requires item_id to currently be in
	# banked_gear" precondition below).
	GameSession.activate_carried_item(GameSession.WARRIOR_ID, "weapon", "longsword_iron")

	var equipped: bool = GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")

	assert_true(equipped)
	var equipment: Dictionary = GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment
	assert_eq(equipment.weapon, "dagger_steel", "Re-equipping re-activates the already-carried copy")
	assert_eq(
		equipment.weapon_inventory, ["longsword_iron", "dagger_steel"],
		"No duplicate entry — the unit already carried this exact item"
	)
	assert_eq(GameSession.banked_gear.dagger_steel, 1, "The spare bank copy is untouched, not consumed again")


func test_equip_item_from_bank_rejects_an_item_not_in_stock_or_an_unknown_adventurer() -> void:
	GameSession.reset()
	assert_false(GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel"), "Nothing in stock")

	GameSession.banked_gear = {"dagger_steel": 1}
	assert_false(GameSession.equip_item_from_bank("no_such_id", "dagger_steel"))
	assert_eq(GameSession.banked_gear.dagger_steel, 1, "A rejected equip must not touch the bank")


func test_equip_item_from_party_store_adds_and_activates_without_touching_the_bank() -> void:
	GameSession.reset()
	GameSession.pending_gear = {"dagger_steel": 1}

	var equipped: bool = GameSession.equip_item_from_party_store(GameSession.WARRIOR_ID, "dagger_steel")

	assert_true(equipped)
	var equipment: Dictionary = GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment
	assert_eq(equipment.weapon, "dagger_steel")
	assert_eq(equipment.weapon_inventory, ["longsword_iron", "dagger_steel"])
	assert_eq(
		GameSession.pending_gear, {"dagger_steel": 0},
		"The party store loses the item -- zero-count keys stay, matching banked_gear's own equip/sell pattern"
	)
	assert_eq(GameSession.banked_gear, {}, "The bank must never be touched by this method")


func test_equip_item_from_party_store_rejects_an_item_not_in_the_party_store() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"dagger_steel": 1}

	assert_false(
		GameSession.equip_item_from_party_store(GameSession.WARRIOR_ID, "dagger_steel"),
		"A bank copy does not satisfy the party store -- these are two separate pools"
	)
	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.weapon, "longsword_iron")


func test_activate_carried_item_switches_the_active_weapon_without_touching_the_bank() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"dagger_steel": 1}
	GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")

	var activated: bool = GameSession.activate_carried_item(GameSession.WARRIOR_ID, "weapon", "longsword_iron")

	assert_true(activated)
	var equipment: Dictionary = GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment
	assert_eq(equipment.weapon, "longsword_iron")
	assert_eq(
		equipment.weapon_inventory, ["longsword_iron", "dagger_steel"],
		"Activating a carried item must not change what's carried"
	)
	assert_eq(GameSession.banked_gear.get("dagger_steel", 0), 0, "No bank interaction")


func test_activate_carried_item_rejects_an_uncarried_item_an_unknown_slot_or_adventurer() -> void:
	GameSession.reset()

	assert_false(
		GameSession.activate_carried_item(GameSession.WARRIOR_ID, "weapon", "dagger_steel"),
		"Not carried"
	)
	assert_false(
		GameSession.activate_carried_item(GameSession.WARRIOR_ID, "shield", "longsword_iron"),
		"Unknown slot"
	)
	assert_false(
		GameSession.activate_carried_item("no_such_id", "weapon", "longsword_iron"),
		"Unknown adventurer"
	)
	assert_eq(
		GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.weapon, "longsword_iron",
		"Every rejected call must leave the active weapon untouched"
	)


func test_unequip_to_bank_removes_a_non_active_carried_item_and_banks_it() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"dagger_steel": 1}
	GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")
	# longsword_iron is now carried but inactive.

	var unequipped: bool = GameSession.unequip_to_bank(GameSession.WARRIOR_ID, "weapon", "longsword_iron")

	assert_true(unequipped)
	var equipment: Dictionary = GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment
	assert_eq(equipment.weapon_inventory, ["dagger_steel"])
	assert_eq(equipment.weapon, "dagger_steel", "The active item is unaffected")
	assert_eq(GameSession.banked_gear.longsword_iron, 1)


func test_unequip_to_bank_rejects_the_active_item_an_uncarried_item_or_an_unknown_adventurer() -> void:
	GameSession.reset()

	assert_false(
		GameSession.unequip_to_bank(GameSession.WARRIOR_ID, "weapon", "longsword_iron"),
		"Cannot unequip the only (and therefore active) carried weapon"
	)
	assert_false(
		GameSession.unequip_to_bank(GameSession.WARRIOR_ID, "weapon", "dagger_steel"),
		"Not carried"
	)
	assert_false(
		GameSession.unequip_to_bank("no_such_id", "weapon", "longsword_iron"),
		"Unknown adventurer"
	)
	assert_eq(
		GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.weapon_inventory, ["longsword_iron"],
		"Every rejected call must leave the inventory untouched"
	)
	assert_eq(GameSession.banked_gear, {}, "Nothing rejected should ever reach the bank")


func test_reset_clears_the_trading_post() -> void:
	GameSession.has_trading_post = true

	GameSession.reset()

	assert_false(GameSession.has_trading_post)


func test_player_power_is_adventurer_count_plus_guild_hall_level() -> void:
	GameSession.reset()
	assert_eq(GameSession._player_power(), 2, "One starting adventurer plus Guild Hall level 1")
	GameSession.recruit_adventurer()
	assert_eq(GameSession._player_power(), 3)
	GameSession.guild_hall_level = 2
	assert_eq(GameSession._player_power(), 4)


func test_star_tier_weight_matches_the_documented_table_at_starting_power() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	assert_eq(session._star_tier_weight(1, 2), 4)
	assert_eq(session._star_tier_weight(2, 2), 4)
	assert_eq(session._star_tier_weight(3, 2), 1)


func test_star_tier_weight_shifts_toward_higher_tiers_as_power_grows() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	assert_eq(session._star_tier_weight(1, 6), 1)
	assert_eq(session._star_tier_weight(2, 6), 8)
	assert_eq(session._star_tier_weight(3, 6), 4)


func test_star_tier_weight_never_drops_to_zero_no_matter_how_high_power_gets() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	assert_eq(session._star_tier_weight(1, 1000), 1)


func test_star_tier_weight_clamps_an_out_of_range_tier_instead_of_crashing() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	assert_eq(
		session._star_tier_weight(4, 2),
		session._star_tier_weight(3, 2),
		"An out-of-range tier should clamp down to the highest documented tier (3)"
	)


## At starting power (2), candidates [goblin_camp, ruined_fortress] (orc_outpost
## stays active) weight to [4, 1] -- a total of 5. Rolls 0-3 land on
## goblin_camp's bucket, roll 4 lands on ruined_fortress's.
func test_choose_encounter_template_maps_the_weighted_roll_onto_the_right_candidate() -> void:
	GameSession.reset()
	GameSession.active_encounters = [GameSession.active_encounters[1]]

	GameSession.star_weight_roll = func(_total_weight: int) -> int: return 0
	assert_eq(GameSession._choose_encounter_template(), GameSession.GOBLIN_CAMP_ID)

	GameSession.star_weight_roll = func(_total_weight: int) -> int: return 4
	assert_eq(GameSession._choose_encounter_template(), GameSession.RUINED_FORTRESS_ID)


func test_choose_encounter_template_never_offers_a_currently_active_template() -> void:
	GameSession.reset()
	# Both starting templates are active; only the Ruined Fortress can be chosen.
	GameSession.star_weight_roll = func(_total_weight: int) -> int: return 0
	assert_eq(GameSession._choose_encounter_template(), GameSession.RUINED_FORTRESS_ID)


func test_a_vacancy_refill_can_produce_the_ruined_fortress() -> void:
	GameSession.reset()
	GameSession.active_encounters = [GameSession.active_encounters[1]]
	GameSession.encounter_vacancies = [{"turns_remaining": 1}]
	GameSession.star_weight_roll = func(_total_weight: int) -> int: return 4

	GameSession._advance_encounter_vacancies()

	var template_ids: Array = []
	for instance in GameSession.active_encounters:
		template_ids.append(instance.template_id)
	assert_true(template_ids.has(GameSession.RUINED_FORTRESS_ID))


## Every durable field export_campaign_snapshot()/import_campaign_snapshot()
## carry -- see CampaignSnapshot. Captured field-by-field (rather than
## compared against a pre-serialized dictionary) so a test failure names
## exactly which category regressed.
func _capture_durable_fields() -> Dictionary:
	return {
		"adventurers": GameSession.adventurers.duplicate(true),
		"recruitment_candidates": GameSession.recruitment_candidates.duplicate(true),
		"recruitment_vacancies": GameSession.recruitment_vacancies.duplicate(true),
		"parties": GameSession.parties.duplicate(true),
		"selected_party_id": GameSession.selected_party_id,
		"selected_encounter": GameSession.selected_encounter,
		"completed_encounters": GameSession.completed_encounters.duplicate(true),
		"active_encounters": GameSession.active_encounters.duplicate(true),
		"encounter_vacancies": GameSession.encounter_vacancies.duplicate(true),
		"used_encounter_template_ids": GameSession._used_encounter_template_ids.duplicate(true),
		"world_turn": GameSession.world_turn,
		"gold": GameSession.gold,
		"guild_hall_level": GameSession.guild_hall_level,
		"pending_reward": GameSession.pending_reward,
		"mana_crystals": GameSession.mana_crystals.duplicate(true),
		"banked_gear": GameSession.banked_gear.duplicate(true),
		"pending_mana_crystals": GameSession.pending_mana_crystals.duplicate(true),
		"pending_gear": GameSession.pending_gear.duplicate(true),
		"battle_reward": GameSession.battle_reward,
		"battle_mana_crystals": GameSession.battle_mana_crystals.duplicate(true),
		"battle_gear": GameSession.battle_gear.duplicate(true),
		"has_trading_post": GameSession.has_trading_post,
		"player_name": GameSession.player_name,
		"tutorial_progress": GameSession.tutorial_progress.duplicate(true),
	}


func test_import_keeps_carried_rewards_unbanked() -> void:
	GameSession.pending_reward = 17
	var snapshot := GameSession.export_campaign_snapshot()
	GameSession.reset()
	assert_true(GameSession.import_campaign_snapshot(snapshot).ok)
	assert_eq(GameSession.pending_reward, 17)
	assert_eq(GameSession.gold, 0)


## Exercises every durable category the snapshot contract covers: roster/
## progression/equipment, parties/routes, selected ids, world turn,
## encounter instances/completions/vacancies, recruitment offers/vacancies,
## gold/buildings, every battle/pending/banked reward store, player name,
## and tutorial progress.
func test_export_then_reset_then_import_restores_the_full_session() -> void:
	GameSession.start_new_game("Ryan")
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.recruit_adventurer()
	GameSession.depart_selected_party()
	GameSession.set_deployed_party_position(Vector2i(4, 3))
	GameSession.set_deployed_party_route([Vector2i(4, 4)])
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	GameSession.completed_encounters = ["orc_outpost"]
	GameSession.encounter_vacancies = [{"turns_remaining": 3}]
	GameSession.recruitment_vacancies = [{"turns_remaining": 6}]
	GameSession.world_turn = 5
	GameSession.gold = 123
	GameSession.guild_hall_level = 2
	GameSession.pending_reward = 9
	GameSession.mana_crystals = {1: 2}
	GameSession.banked_gear = {"shortsword_iron": 1}
	GameSession.pending_mana_crystals = {2: 1}
	GameSession.pending_gear = {"longsword_iron": 1}
	GameSession.battle_reward = 4
	GameSession.battle_mana_crystals = {1: 1}
	GameSession.battle_gear = {"dagger_iron": 1}
	GameSession.has_trading_post = true
	GameSession.tutorial_progress = {"formed_party": true}
	var expected := _capture_durable_fields()

	var snapshot := GameSession.export_campaign_snapshot()
	GameSession.reset()
	var result := GameSession.import_campaign_snapshot(snapshot)

	assert_true(result.ok, result.error)
	assert_eq(_capture_durable_fields(), expected)


## Reflection guard against the durable-field list drifting out of sync: the
## field-by-field wiring export_campaign_snapshot()/import_campaign_
## snapshot()/CampaignSnapshot/_capture_durable_fields() above all repeat by
## hand has no shared source of truth, so nothing fails today if a new
## durable var is added to GameSession without also adding it to the
## snapshot -- it would just silently fail to survive a save/load round
## trip. This walks every script-declared instance var GameSession actually
## has and asserts export_campaign_snapshot()'s output carries each one,
## rather than repeating the same hand-written list a fourth time. Only two
## kinds of var are allowed to not appear in the snapshot: Callable
## roll-hooks (injectable test doubles, e.g. GameSession.
## enemy_composition_roll -- behavior, not state) and the balance-config
## numbers GameConfig overwrites at _ready() from config files (e.g.
## GameSession.BASE_ATTACK) -- neither is per-campaign player state. Any
## other genuinely non-durable var must be added to the explicit
## `excluded_names` allowlist below with its own reason, not silently
## skipped.
func test_every_durable_field_is_carried_by_the_snapshot_contract() -> void:
	var snapshot: Dictionary = GameSession.export_campaign_snapshot()

	# GameSession's own field name differs from the snapshot's key for
	# exactly one durable var: _used_encounter_template_ids is private
	# (leading underscore) because nothing outside GameSession needs to
	# read it directly, but see its own doc comment for why it is still
	# durable.
	var renamed_keys: Dictionary = {
		"_used_encounter_template_ids": "used_encounter_template_ids",
	}

	# Balance-config numbers: not per-campaign state, always reset from
	# GameConfig at boot (see GameSession._ready()).
	var excluded_names: Dictionary = {
		"BASE_ATTACK": true,
		"BASE_MAX_HEALTH": true,
		"BASE_MOVE_RANGE": true,
		"LEVEL_UP_MAX_HEALTH_BONUS": true,
		"LEVEL_UP_SKILL_POINTS": true,
		"PERK_LEVEL_INTERVAL": true,
		"GUILD_HALL_LEVEL_1_PARTY_CAP": true,
		"GUILD_HALL_LEVEL_2_PARTY_CAP": true,
		"GUILD_HALL_UPGRADE_COST": true,
		"GUILD_HALL_MAX_LEVEL": true,
		"TRADING_POST_PURCHASE_COST": true,
		"TRADING_POST_INCOME_PER_TURN": true,
		"EFFECTIVE_HIT_CHANCE_CAP": true,
		"ATTACK_TO_HIT_CHANCE_DIVISOR": true,
		"ENCOUNTER_INSTANCE_CAP": true,
		"RECRUITMENT_OFFER_CAP": true,
		"ENCOUNTER_VACANCY_TURNS": true,
		"RECRUITMENT_VACANCY_TURNS": true,
		"ENCOUNTER_VACANCY_JITTER_TURNS": true,
		"RECRUITMENT_VACANCY_JITTER_TURNS": true,
	}

	var checked_field_names: Array[String] = []
	for property in GameSession.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var field_name: String = property.name
		if property.type == TYPE_CALLABLE:
			continue
		if excluded_names.has(field_name):
			continue
		var snapshot_key: String = renamed_keys.get(field_name, field_name)
		checked_field_names.append(field_name)
		assert_true(
			snapshot.has(snapshot_key),
			(
				"GameSession.%s looks durable but export_campaign_snapshot() does not carry it -- "
				+ "wire it into CampaignSnapshot/export_campaign_snapshot()/import_campaign_snapshot(), "
				+ "or add %s to this test's excluded_names allowlist with a reason if it is not durable."
			) % [field_name, field_name]
		)

	# Sanity check: reflection must actually find GameSession's durable vars,
	# so a Godot API change silently returning nothing cannot pass this test
	# vacuously.
	assert_gt(checked_field_names.size(), 15)


func test_export_campaign_snapshot_deep_copies_so_mutating_it_does_not_affect_the_session() -> void:
	GameSession.create_party()

	var snapshot := GameSession.export_campaign_snapshot()
	snapshot.parties[0].name = "Mutated"
	snapshot.gold = 999

	assert_ne(GameSession.get_selected_party().name, "Mutated")
	assert_eq(GameSession.gold, 0)


func test_import_campaign_snapshot_deep_copies_so_mutating_the_session_afterward_does_not_affect_the_source_data() -> void:
	GameSession.create_party()
	var snapshot := GameSession.export_campaign_snapshot()

	GameSession.reset()
	assert_true(GameSession.import_campaign_snapshot(snapshot).ok)
	GameSession.parties[0].name = "Mutated"
	GameSession.gold = 999

	assert_ne(snapshot.parties[0].name, "Mutated")
	assert_ne(snapshot.gold, 999)


## The other direction from the test above: import_campaign_snapshot()'s
## returned result carries a "snapshot" key (see CampaignSnapshot.
## from_dictionary()) that a caller might inspect for logging/diagnostics.
## Mutating that returned dict afterward must not reach back into the live
## session -- import_campaign_snapshot() has to duplicate every Array/
## Dictionary field it assigns from result.snapshot, not alias it.
func test_import_campaign_snapshot_result_does_not_alias_live_session_state() -> void:
	GameSession.create_party()
	var snapshot := GameSession.export_campaign_snapshot()
	GameSession.reset()

	var result := GameSession.import_campaign_snapshot(snapshot)
	assert_true(result.ok, result.error)

	result.snapshot.gold = 999
	result.snapshot.parties[0].name = "Mutated"
	result.snapshot.adventurers.append({"id": "intruder"})

	assert_eq(GameSession.gold, 0)
	assert_ne(GameSession.get_selected_party().name, "Mutated")
	assert_eq(GameSession.adventurers.size(), 1)


func test_import_never_merges_battle_or_pending_rewards_into_the_bank() -> void:
	GameSession.battle_reward = 3
	GameSession.battle_gear = {"dagger_iron": 1}
	GameSession.battle_mana_crystals = {1: 1}
	GameSession.pending_reward = 7
	GameSession.pending_gear = {"longsword_iron": 1}
	GameSession.pending_mana_crystals = {2: 1}
	var snapshot := GameSession.export_campaign_snapshot()
	GameSession.reset()

	assert_true(GameSession.import_campaign_snapshot(snapshot).ok)

	assert_eq(GameSession.gold, 0)
	assert_eq(GameSession.banked_gear, {})
	assert_eq(GameSession.mana_crystals, {})
	assert_eq(GameSession.battle_reward, 3)
	assert_eq(GameSession.battle_gear, {"dagger_iron": 1})
	assert_eq(GameSession.battle_mana_crystals, {1: 1})
	assert_eq(GameSession.pending_reward, 7)
	assert_eq(GameSession.pending_gear, {"longsword_iron": 1})
	assert_eq(GameSession.pending_mana_crystals, {2: 1})


func test_import_campaign_snapshot_rejects_invalid_data_and_leaves_a_prepared_session_unchanged() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.gold = 55
	var expected := _capture_durable_fields()

	var invalid_data := GameSession.export_campaign_snapshot()
	invalid_data.erase("version")
	var result := GameSession.import_campaign_snapshot(invalid_data)

	assert_false(result.ok)
	assert_eq(_capture_durable_fields(), expected)


## get_campaign_guide_state(): the derived, one-shot query behind the first-
## campaign guide banner (see docs/plans/2026-08-10-initial-campaign-and-
## automation/04-first-campaign-guidance.md and scripts/ui/campaign_guide.gd).
## Walks the party-formed -> deployed -> route-selected -> site-entered ->
## reward-banked -> first-improvement loop end to end, then checks
## dismissal and the no-regression backfill separately.
func test_campaign_guide_starts_by_asking_to_form_a_party() -> void:
	GameSession.reset()
	assert_eq(GameSession.get_campaign_guide_state(), GameSession.CAMPAIGN_GUIDE_FORM_PARTY)


func test_campaign_guide_moves_to_deploy_once_a_party_exists() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)

	assert_eq(GameSession.get_campaign_guide_state(), GameSession.CAMPAIGN_GUIDE_DEPLOY)


func test_campaign_guide_moves_to_select_route_once_the_party_deploys() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()

	assert_eq(GameSession.get_campaign_guide_state(), GameSession.CAMPAIGN_GUIDE_SELECT_ROUTE)


func test_campaign_guide_moves_to_enter_site_once_the_party_reaches_an_active_encounter() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	GameSession.set_deployed_party_position(GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position)

	assert_eq(GameSession.get_campaign_guide_state(), GameSession.CAMPAIGN_GUIDE_ENTER_SITE)


func test_campaign_guide_moves_to_return_bank_once_the_party_carries_a_reward() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	GameSession.complete_current_encounter()
	GameSession.merge_battle_loot_into_party()

	assert_true(GameSession.pending_reward > 0)
	assert_eq(GameSession.get_campaign_guide_state(), GameSession.CAMPAIGN_GUIDE_RETURN_BANK)


func test_campaign_guide_offers_the_first_affordable_improvement_once_the_reward_is_banked() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	GameSession.complete_current_encounter()
	GameSession.merge_battle_loot_into_party()
	GameSession.return_deployed_party_to_settlement()
	GameSession.deposit_pending_reward()
	GameSession.gold = 10  # guarantee an affordable recruit regardless of the rolled reward

	assert_eq(GameSession.get_campaign_guide_state(), GameSession.CAMPAIGN_GUIDE_FIRST_IMPROVEMENT)


## get_campaign_guide_state() must be a pure read, exactly like every other
## get_/has_/can_ method in this file (get_recruitment_candidates(),
## has_deployed_party(), can_upgrade_guild_hall(), ...): calling it -- even
## repeatedly, even when several ids are simultaneously triggered -- must
## never write tutorial_progress. Only the explicit
## record_campaign_guide_progress()/record_campaign_guide_dismissal() calls
## may do that.
func test_get_campaign_guide_state_never_writes_tutorial_progress() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	GameSession.complete_current_encounter()
	GameSession.merge_battle_loot_into_party()
	GameSession.return_deployed_party_to_settlement()
	GameSession.deposit_pending_reward()
	GameSession.gold = 10
	# At this point DEPLOY, SELECT_ROUTE, and FIRST_IMPROVEMENT can all be
	# simultaneously live-triggered (see the priority-scan comment on
	# _compute_campaign_guide_active_id()) -- exactly the situation a hidden
	# write would be tempted to "clean up".
	assert_eq(GameSession.get_campaign_guide_state(), GameSession.CAMPAIGN_GUIDE_FIRST_IMPROVEMENT)

	GameSession.get_campaign_guide_state()
	GameSession.get_campaign_guide_state()

	assert_eq(GameSession.tutorial_progress, {})


## record_campaign_guide_progress(): the explicit write the guide banner
## makes (see scripts/ui/campaign_guide.gd's refresh()) whenever it actually
## renders a message -- this is what durably retires every earlier,
## still-pending id, not the query itself.
func test_record_campaign_guide_progress_retires_every_earlier_id() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	GameSession.complete_current_encounter()
	GameSession.merge_battle_loot_into_party()
	GameSession.return_deployed_party_to_settlement()
	GameSession.deposit_pending_reward()
	GameSession.gold = 10
	assert_eq(GameSession.get_campaign_guide_state(), GameSession.CAMPAIGN_GUIDE_FIRST_IMPROVEMENT)

	GameSession.record_campaign_guide_progress(GameSession.CAMPAIGN_GUIDE_FIRST_IMPROVEMENT)

	assert_true(GameSession.tutorial_progress.get(GameSession.CAMPAIGN_GUIDE_FORM_PARTY, false))
	assert_true(GameSession.tutorial_progress.get(GameSession.CAMPAIGN_GUIDE_DEPLOY, false))
	assert_true(GameSession.tutorial_progress.get(GameSession.CAMPAIGN_GUIDE_SELECT_ROUTE, false))
	assert_true(GameSession.tutorial_progress.get(GameSession.CAMPAIGN_GUIDE_ENTER_SITE, false))
	assert_true(GameSession.tutorial_progress.get(GameSession.CAMPAIGN_GUIDE_RETURN_BANK, false))
	# guide_id itself is left alone -- only an explicit dismissal (or later
	# resolving on its own, as the next test covers) retires the current one.
	assert_false(GameSession.tutorial_progress.get(GameSession.CAMPAIGN_GUIDE_FIRST_IMPROVEMENT, false))


func test_record_campaign_guide_progress_on_the_first_stage_writes_nothing() -> void:
	GameSession.reset()
	assert_eq(GameSession.get_campaign_guide_state(), GameSession.CAMPAIGN_GUIDE_FORM_PARTY)

	GameSession.record_campaign_guide_progress(GameSession.CAMPAIGN_GUIDE_FORM_PARTY)

	assert_eq(GameSession.tutorial_progress, {})


## A second expedition naturally un-deploys the party again (see
## return_deployed_party_to_settlement()), which would otherwise make a
## naive live-state check wrongly resurface "deploy your party" even though
## the player is really just standing at the bank with gold to spend. This
## is exactly why record_campaign_guide_progress() exists: it must have
## actually been called (mirroring the guide banner having actually
## rendered FIRST_IMPROVEMENT) for DEPLOY to stay retired once its own live
## trigger goes away.
func test_campaign_guide_clears_once_the_first_improvement_is_made() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	GameSession.return_deployed_party_to_settlement()
	GameSession.gold = 10
	assert_eq(GameSession.get_campaign_guide_state(), GameSession.CAMPAIGN_GUIDE_FIRST_IMPROVEMENT)
	GameSession.record_campaign_guide_progress(GameSession.CAMPAIGN_GUIDE_FIRST_IMPROVEMENT)

	assert_true(GameSession.purchase_recruit(GameSession.recruitment_candidates[0].id))

	assert_eq(GameSession.get_campaign_guide_state(), "")


## _campaign_guide_first_improvement_made()'s other two branches (recruiting
## is covered above): a Guild Hall upgrade or a Trading Post purchase must
## each independently count as "the first improvement" too.
func test_campaign_guide_clears_once_the_guild_hall_is_upgraded() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	GameSession.return_deployed_party_to_settlement()
	GameSession.gold = GameSession.GUILD_HALL_UPGRADE_COST
	assert_eq(GameSession.get_campaign_guide_state(), GameSession.CAMPAIGN_GUIDE_FIRST_IMPROVEMENT)
	GameSession.record_campaign_guide_progress(GameSession.CAMPAIGN_GUIDE_FIRST_IMPROVEMENT)

	assert_true(GameSession.upgrade_guild_hall())

	assert_eq(GameSession.get_campaign_guide_state(), "")


func test_campaign_guide_clears_once_the_trading_post_is_purchased() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	GameSession.return_deployed_party_to_settlement()
	GameSession.gold = GameSession.TRADING_POST_PURCHASE_COST
	assert_eq(GameSession.get_campaign_guide_state(), GameSession.CAMPAIGN_GUIDE_FIRST_IMPROVEMENT)
	GameSession.record_campaign_guide_progress(GameSession.CAMPAIGN_GUIDE_FIRST_IMPROVEMENT)

	assert_true(GameSession.purchase_trading_post())

	assert_eq(GameSession.get_campaign_guide_state(), "")


func test_record_campaign_guide_dismissal_retires_a_message_even_while_its_trigger_still_holds() -> void:
	GameSession.reset()
	assert_eq(GameSession.get_campaign_guide_state(), GameSession.CAMPAIGN_GUIDE_FORM_PARTY)

	GameSession.record_campaign_guide_dismissal(GameSession.CAMPAIGN_GUIDE_FORM_PARTY)

	assert_eq(GameSession.get_campaign_guide_state(), "")


func test_campaign_guide_dismissal_survives_a_snapshot_round_trip() -> void:
	GameSession.reset()
	GameSession.record_campaign_guide_dismissal(GameSession.CAMPAIGN_GUIDE_FORM_PARTY)
	var snapshot := GameSession.export_campaign_snapshot()
	GameSession.reset()

	assert_true(GameSession.import_campaign_snapshot(snapshot).ok)
	assert_eq(GameSession.get_campaign_guide_state(), "")
