extends GutTest

const GameSessionScript := preload("res://scripts/autoload/game_session.gd")


func test_new_session_has_one_unassigned_warrior_and_no_party() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.adventurers, [GameSessionScript.DEFAULT_WARRIOR])
	assert_eq(session.parties, [])
	assert_eq(session.selected_party_id, "")


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
