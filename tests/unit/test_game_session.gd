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
		"stats": {"max_health": 20, "vitality": 10, "attack": 10, "defense": 5},
		"health": 20,
		"progression": {},
	}



## Offer ids are generated and opaque (see _new_instance_id); tests that need
## a specific fixed-pool offer discover it by the template_id it claims.
## Returns "" when no live offer claims the template.
func _candidate_id_for_template(session: Node, template_id: String) -> String:
	for candidate in session.get_recruitment_candidates():
		if candidate.get("template_id", "") == template_id:
			return candidate.id
	return ""


func after_each() -> void:
	GameSession.reset_injectable_rolls()


func before_each() -> void:
	GameSession.reset()


func test_new_session_starts_with_four_unassigned_warriors_and_no_party() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.adventurers.size(), GameSessionScript.STARTING_ROSTER_SIZE)
	assert_eq(session.adventurers[0], session.get_default_warrior())
	assert_eq(session.adventurers[0].id, GameSessionScript.WARRIOR_ID)
	var template_ids: Array = []
	for template in GameSessionScript.RECRUITMENT_CANDIDATE_TEMPLATES:
		template_ids.append(template.id)
	var seen_ids: Dictionary = {}
	for index in session.adventurers.size():
		var adventurer: Dictionary = session.adventurers[index]
		assert_eq(adventurer["class"], "warrior")
		assert_eq(adventurer.level, 1)
		assert_eq(adventurer.availability_status, "available")
		assert_eq(adventurer.stats, session.get_default_warrior().stats)
		assert_eq(adventurer.name, "Warrior" if index == 0 else "Warrior %d" % (index + 1))
		if index > 0:
			assert_ne(adventurer.id, "", "Roster ids beyond the legacy first warrior are generated")
			assert_false(template_ids.has(adventurer.id))
		assert_false(seen_ids.has(adventurer.id), "Roster ids must be unique")
		seen_ids[adventurer.id] = true
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
	assert_eq(session.gold, 200)


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

func test_get_max_party_count_is_one_and_create_party_fails_at_the_cap() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.get_max_party_count(), 1)
	assert_true(session.create_party())
	assert_false(session.create_party(), "create_party() must reject once the party-count cap is reached")
	assert_eq(session.parties.size(), session.get_max_party_count())
	assert_eq(session.get_selected_party().id, GameSessionScript.FIRST_PARTY_ID)


## The complete authored-node catalog is this step's sole ownership
## surface (see GameSession.CAMPAIGN_OBJECTIVES's own doc comment) -- twelve
## unique ids (three tiers of three, a two-battle pre-boss sequence, and the
## final boss), each non-first node naming a real prior node as its
## prerequisite, and the campaign starting on the first tier-1 node.
func test_campaign_objectives_catalog_has_twelve_unique_nodes_each_with_a_valid_prerequisite() -> void:
	var ids: Array = GameSessionScript.CAMPAIGN_OBJECTIVES.keys()
	assert_eq(ids.size(), 12, "The campaign contract is exactly twelve authored nodes")

	var seen_ids: Dictionary = {}
	for id in ids:
		assert_false(seen_ids.has(id), "Objective id %s is not unique" % id)
		seen_ids[id] = true

	for id in ids:
		var node: Dictionary = GameSessionScript.CAMPAIGN_OBJECTIVES[id]
		var prerequisite_id: String = node.prerequisite_id
		if id == "obj_tier1_1_goblin_outpost":
			assert_eq(prerequisite_id, "", "The first node has no prerequisite")
		else:
			assert_true(
				GameSessionScript.CAMPAIGN_OBJECTIVES.has(prerequisite_id),
				"%s's prerequisite %s must name a real node" % [id, prerequisite_id]
			)


func test_new_session_starts_on_the_first_tier_one_objective() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.campaign_objective_id, "obj_tier1_1_goblin_outpost")
	assert_eq(session.completed_objectives, [])
	assert_eq(session.unlocked_authored_encounters, ["obj_tier1_1_goblin_outpost"])
	assert_false(session.is_campaign_completed)
	assert_false(session.is_free_play_active)
	assert_eq(
		session.get_current_campaign_objective(),
		GameSessionScript.CAMPAIGN_OBJECTIVES["obj_tier1_1_goblin_outpost"]
	)


func test_complete_campaign_objective_marks_it_completed_and_unlocks_the_next_node() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	watch_signals(session)

	session.complete_campaign_objective("obj_tier1_1_goblin_outpost")

	assert_true(session.is_objective_completed("obj_tier1_1_goblin_outpost"))
	assert_eq(session.completed_objectives, ["obj_tier1_1_goblin_outpost"])
	assert_eq(session.campaign_objective_id, "obj_tier1_2_kobold_warren")
	assert_true(session.unlocked_authored_encounters.has("obj_tier1_2_kobold_warren"))
	assert_signal_emitted(session, "campaign_progress_changed")


func test_completing_an_unknown_objective_id_does_nothing() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.complete_campaign_objective("no_such_objective")

	assert_eq(session.completed_objectives, [])
	assert_eq(session.campaign_objective_id, "obj_tier1_1_goblin_outpost")


func test_completing_an_objective_twice_is_idempotent() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.complete_campaign_objective("obj_tier1_1_goblin_outpost")
	var completed_after_first: Array = session.completed_objectives.duplicate(true)
	var unlocked_after_first: Array = session.unlocked_authored_encounters.duplicate(true)

	session.complete_campaign_objective("obj_tier1_1_goblin_outpost")

	assert_eq(session.completed_objectives, completed_after_first, "A repeated completion must not double-append")
	assert_eq(session.unlocked_authored_encounters, unlocked_after_first)
	assert_eq(
		session.campaign_objective_id, "obj_tier1_2_kobold_warren",
		"A repeated completion must not re-advance past the next node"
	)


func test_completing_the_final_boss_node_sets_campaign_victory() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.complete_campaign_objective("obj_boss_borderlands_ogre")

	assert_true(session.is_objective_completed("obj_boss_borderlands_ogre"))
	assert_eq(session.campaign_objective_id, "", "No node follows the final boss")
	assert_true(session.is_campaign_completed)
	assert_true(session.is_free_play_active)


func test_set_campaign_victory_atomically_flags_victory_and_free_play() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	watch_signals(session)

	session.set_campaign_victory()

	assert_true(session.is_campaign_completed)
	assert_true(session.is_free_play_active)
	assert_signal_emitted(session, "campaign_progress_changed")


## --- Step 5: Authored 12-battle encounter ladder ---------------------------
## (docs/plans/2026-08-18-core-loop-and-engagement/
## 05-authored-encounters-and-final-boss.md)


## Every CAMPAIGN_OBJECTIVES id must resolve to a real EXPEDITIONS entry
## (its own "encounter_id" mirrors its key -- see that catalog's own doc
## comment), and every such entry must be marked authored, carry a distinct
## world-map position, a positive clear_xp reward, and an ordered mixed-unit
## "enemies" composition (never the legacy single "enemy" + "count" template
## the three sandbox expeditions still use) whose total fielded unit count
## fits the battlefield's eight enemy start positions.
func test_every_campaign_objective_resolves_to_an_authored_expedition_with_a_valid_composition() -> void:
	var seen_positions: Dictionary = {}
	for id in GameSessionScript.CAMPAIGN_OBJECTIVES.keys():
		var objective: Dictionary = GameSessionScript.CAMPAIGN_OBJECTIVES[id]
		assert_eq(objective.encounter_id, id, "%s's encounter_id must mirror its own catalog key" % id)
		assert_true(GameSessionScript.EXPEDITIONS.has(id), "%s must have a matching EXPEDITIONS entry" % id)

		var expedition: Dictionary = GameSessionScript.EXPEDITIONS[id]
		assert_true(expedition.get("is_authored", false), "%s's expedition must be marked authored" % id)
		assert_false(expedition.has("enemy"), "%s must use the mixed 'enemies' formation, not the legacy 'enemy' template" % id)
		assert_true(expedition.has("enemies"), "%s must declare an ordered 'enemies' formation" % id)
		assert_gt(int(expedition.get("clear_xp", 0)), 0, "%s must reward positive clear XP" % id)

		var position: Vector2i = expedition.position
		assert_false(seen_positions.has(position), "%s's world-map position %s collides with another node" % [id, position])
		seen_positions[position] = id

		var total_units := 0
		for group in expedition.enemies:
			assert_true(group.has("enemy") and group.enemy is Dictionary and not group.enemy.is_empty(), "%s has an empty enemy group" % id)
			assert_gt(int(group.get("count", 0)), 0, "%s has a non-positive enemy group count" % id)
			total_units += int(group.count)
		assert_true(total_units > 0 and total_units <= 8, "%s fields %d units, outside the 1-8 supported range" % [id, total_units])


## Cross-checks the plan doc's own composition table (see the step's
## Technical Design section) against the live data, by monster count per
## node -- proof the catalog was actually filled in with the intended
## fight, not just structurally valid placeholder data.
func test_authored_encounter_compositions_match_the_plan_doc() -> void:
	var expected_counts := {
		"obj_tier1_1_goblin_outpost": 3,
		"obj_tier1_2_kobold_warren": 5,
		"obj_tier1_3_goblin_warcamp": 3,
		"obj_tier2_1_orc_outpost": 2,
		"obj_tier2_2_orc_warband": 2,
		"obj_tier2_3_brute_stronghold": 4,
		"obj_tier3_1_hobgoblin_command": 3,
		"obj_tier3_2_mixed_forces_ambush": 3,
		"obj_tier3_3_ruined_fortress": 4,
		"obj_preboss_1_borderlands_vanguard": 5,
		"obj_preboss_2_borderlands_stronghold": 4,
		"obj_boss_borderlands_ogre": 1,
	}
	for id in expected_counts:
		var expedition: Dictionary = GameSessionScript.EXPEDITIONS[id]
		var total_units := 0
		for group in expedition.enemies:
			total_units += int(group.count)
		assert_eq(total_units, expected_counts[id], "%s should field %d total enemies" % [id, expected_counts[id]])

	assert_eq(GameSessionScript.EXPEDITIONS["obj_boss_borderlands_ogre"].enemies[0].enemy, GameSessionScript.OGRE_ENEMY_STATS)


## can_enter_encounter()/enter_encounter() gate authored nodes: only the
## currently-unlocked node (never a locked later one, and never one already
## cleared) can ever become selected_encounter. Sandbox expedition ids
## remain unrestricted, matching prior behavior.
func test_only_the_currently_unlocked_authored_node_can_spawn() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_true(session.can_enter_encounter("obj_tier1_1_goblin_outpost"))
	assert_false(session.can_enter_encounter("obj_tier1_2_kobold_warren"), "A not-yet-unlocked node must not be enterable")
	assert_true(session.can_enter_encounter(GameSessionScript.GOBLIN_CAMP_ID), "Sandbox templates remain unrestricted")

	session.enter_encounter("obj_tier1_2_kobold_warren")
	assert_eq(session.selected_encounter, "", "Entering a locked authored node must not select it")

	session.enter_encounter("obj_tier1_1_goblin_outpost")
	assert_eq(session.selected_encounter, "obj_tier1_1_goblin_outpost")

	session.complete_current_encounter()
	assert_true(session.completed_objectives.has("obj_tier1_1_goblin_outpost"))
	assert_true(session.unlocked_authored_encounters.has("obj_tier1_2_kobold_warren"))

	session.enter_encounter("obj_tier1_1_goblin_outpost")
	assert_eq(session.selected_encounter, "", "A cleared authored node must never reopen")

	session.enter_encounter("obj_tier1_2_kobold_warren")
	assert_eq(session.selected_encounter, "obj_tier1_2_kobold_warren", "The newly-unlocked node must now be enterable")


## Completing an authored node's encounter must complete its matching
## campaign objective (same id -- see CAMPAIGN_OBJECTIVES' own doc comment),
## and clearing the entire ladder must land exactly on campaign victory.
func test_completing_every_authored_encounter_in_order_wins_the_campaign() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	watch_signals(session)

	var chain: Array = []
	var id: String = "obj_tier1_1_goblin_outpost"
	while id != "":
		chain.append(id)
		id = GameSessionScript.CAMPAIGN_OBJECTIVES[id].next_objective_id

	assert_eq(chain.size(), 12, "The full prerequisite chain from Tier 1-1 to the Final Boss is twelve nodes")

	for objective_id in chain:
		assert_eq(session.selected_encounter, "")
		session.enter_encounter(objective_id)
		assert_eq(session.selected_encounter, objective_id, "%s should be enterable once unlocked" % objective_id)
		session.complete_current_encounter()
		assert_true(session.is_objective_completed(objective_id))

	assert_true(session.is_campaign_completed)
	assert_true(session.is_free_play_active)
	assert_signal_emitted(session, "campaign_victory")


## --- Step 5: dynamic 1-5 star threat pacing ---------------------------------


func test_threat_stars_start_at_the_encounters_base_difficulty() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.get_threat_stars(GameSessionScript.GOBLIN_CAMP_ID), 1)
	assert_eq(session.get_threat_stars(GameSessionScript.ORC_OUTPOST_ID), 2)
	assert_eq(session.get_threat_stars("obj_boss_borderlands_ogre"), 5)


func test_threat_stars_rise_with_world_turns_and_clamp_at_five() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.world_turn = 1 + GameSessionScript.THREAT_TURN_INTERVAL
	assert_eq(session.get_threat_stars(GameSessionScript.GOBLIN_CAMP_ID), 2, "One interval elapsed adds exactly one star")

	session.world_turn = 1 + GameSessionScript.THREAT_TURN_INTERVAL * 20
	assert_eq(session.get_threat_stars(GameSessionScript.GOBLIN_CAMP_ID), 5, "Threat stars never exceed five")


func test_public_ui_eligibility_queries_report_current_state_without_mutating_it() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_true(session.is_adventurer_available(GameSessionScript.WARRIOR_ID))
	assert_false(session.is_adventurer_available("missing"))
	var warrior_offer_id := _candidate_id_for_template(session, "warrior_002")
	assert_ne(warrior_offer_id, "")
	assert_true(session.has_recruitment_candidate(warrior_offer_id))
	assert_false(session.is_party_deployable(GameSessionScript.FIRST_PARTY_ID))
	session.create_party()
	session.assign_adventurer_to_selected_party(GameSessionScript.WARRIOR_ID)
	assert_true(session.is_party_deployable(GameSessionScript.FIRST_PARTY_ID))
	session.deploy_party(GameSessionScript.FIRST_PARTY_ID)
	assert_false(session.is_party_deployable(GameSessionScript.FIRST_PARTY_ID))
	session.gold = 10
	session.purchase_recruit(warrior_offer_id)
	assert_false(session.has_recruitment_candidate(warrior_offer_id))


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

	assert_eq(session.get_available_adventurers().size(), GameSessionScript.STARTING_ROSTER_SIZE)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")

	var available: Array[Dictionary] = session.get_available_adventurers()
	assert_eq(available.size(), GameSessionScript.STARTING_ROSTER_SIZE - 1, "Assigning one warrior leaves the rest available")
	for adventurer in available:
		assert_ne(adventurer.id, "warrior_001")


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

	assert_eq(session.adventurers.size(), GameSessionScript.STARTING_ROSTER_SIZE)
	assert_eq(session.adventurers[0], session.get_default_warrior())


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

	assert_eq(session.battle_reward, 19, "Victory should queue the goblin camp's rolled reward in the battle store")
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

	assert_eq(deposited, 19)
	assert_eq(session.gold, 19)
	assert_eq(session.pending_reward, 0)

	var second_deposit: int = session.deposit_pending_reward()

	assert_eq(second_deposit, 0, "A second deposit must not pay again")
	assert_eq(session.gold, 19, "Gold must not change on a second deposit")


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
		57,
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

	assert_eq(deposited, 57)
	assert_eq(session.gold, 57)
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
	assert_eq(session.gold, 19, "Gold already banked must be unaffected by re-completing a finished site")


func test_completing_the_goblin_camp_queues_gold_a_mana_crystal_and_no_gear_when_the_gear_roll_misses() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	session.loot_gear_roll = func() -> float: return 1.0
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)

	session.complete_current_encounter()

	assert_eq(session.battle_reward, 19, "One goblin kill: randi_range(1, 6) stubbed to min (1) + completion (18)")
	assert_eq(session.battle_mana_crystals, {1: 1}, "One goblin kill grants one tier-1 mana crystal")
	assert_eq(session.battle_gear, {}, "A gear roll of 1.0 must never clear the 25% drop chance")

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

	assert_eq(session.battle_reward, 38, "One orc kill (2) plus completion bonus (18 * 2)")
	assert_eq(session.battle_mana_crystals, {2: 1}, "One orc kill grants one tier-2 mana crystal")


func test_completing_a_two_kill_encounter_rolls_loot_once_per_kill() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	session.loot_gear_roll = func() -> float: return 0.0
	session.enemy_composition_roll = func(_option_count: int) -> int: return 0
	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)

	session.complete_current_encounter()

	assert_eq(session.battle_reward, 38, "Two goblin kills (2) plus completion bonus (18 * 2)")
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
	# Encounter bonus: randi_range(18, 22) stubbed to max (22) * difficulty 2 = 44.
	assert_eq(session.battle_reward, 54, "Kill gold (10) plus the encounter bonus (44) at 2-star difficulty")


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

	assert_eq(session.gold, 19)
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
	assert_eq(warrior.stats.melee, 60)
	assert_false(warrior.progression.has("skill_points"))
	assert_eq(warrior.progression.perks, [], "A fresh Warrior has chosen no perks")
	assert_eq(warrior.stats.max_health, 10)


func test_get_adventurer_returns_a_copy_whose_nested_progression_cannot_mutate_session_state() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.reset()

	var warrior: Dictionary = session.get_adventurer(GameSessionScript.WARRIOR_ID)

	warrior.progression.xp = 999.0
	warrior.stats.melee = 999

	var second_copy: Dictionary = session.get_adventurer(GameSessionScript.WARRIOR_ID)
	assert_eq(second_copy.progression.xp, 0.0, "Mutating a returned copy's nested progression must not affect session state")
	assert_eq(second_copy.stats.melee, 60, "Mutating a returned copy's nested stats must not affect session state")


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


## --- Generated instance ids (_new_instance_id) ---

func test_new_instance_id_returns_non_empty_ids_that_stay_unique_across_a_large_batch() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	var template_ids: Array = []
	for template in GameSessionScript.RECRUITMENT_CANDIDATE_TEMPLATES:
		template_ids.append(template.id)

	var seen_ids: Dictionary = {}
	for _draw in 200:
		var instance_id: String = session._new_instance_id()
		assert_ne(instance_id, "")
		assert_false(seen_ids.has(instance_id), "Generated ids must stay unique across draws; duplicate: %s" % instance_id)
		assert_false(template_ids.has(instance_id), "A generated id must never equal a recruitment template id")
		seen_ids[instance_id] = true


## The injectable-roll convention (see instance_id_roll) lets a test pin the
## entropy and assert the exact minted sequence — here through a full reset(),
## whose roster/offer seeding is the heaviest single minting site.
func test_new_instance_id_entropy_is_pinnable_for_deterministic_tests() -> void:
	var session_a: Node = GameSessionScript.new()
	autofree(session_a)
	var session_b: Node = GameSessionScript.new()
	autofree(session_b)
	for session in [session_a, session_b]:
		var counter := [0]
		session.instance_id_roll = func() -> String:
			counter[0] += 1
			return "gen-%04d" % counter[0]
		session.reset()

	for index in session_a.adventurers.size():
		assert_eq(session_a.adventurers[index].id, session_b.adventurers[index].id)
	assert_eq(session_a.adventurers[0].id, GameSessionScript.WARRIOR_ID, "The legacy first warrior keeps its id")
	assert_eq(session_a.adventurers[1].id, "gen-0001")
	assert_eq(session_a.adventurers[2].id, "gen-0002")
	assert_eq(session_a.adventurers[3].id, "gen-0003")
	for index in session_a.recruitment_candidates.size():
		assert_eq(session_a.recruitment_candidates[index].id, session_b.recruitment_candidates[index].id)
	assert_eq(session_a.recruitment_candidates[0].id, "gen-0004")
	assert_eq(session_a.recruitment_candidates[3].id, "gen-0007")


## Debug recruits mint generated ids (see _new_instance_id), so their names
## come from the cosmetic per-class counter: at a fresh start four roster
## warriors plus three live warrior offers already count, hence "Warrior 8".
func test_recruit_adventurer_appends_a_new_available_adventurer_with_a_fresh_id() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.recruit_adventurer()

	assert_eq(session.adventurers.size(), GameSessionScript.STARTING_ROSTER_SIZE + 1)
	var recruit: Dictionary = session.adventurers[session.adventurers.size() - 1]
	assert_ne(recruit.id, "", "A debug recruit gets a generated id")
	assert_eq(recruit.name, "Warrior 8")
	assert_eq(recruit["class"], "warrior")
	assert_eq(recruit.availability_status, "available")
	assert_true(session.get_available_adventurers().has(recruit))


## Generated ids replace the old collision-scanning machinery: repeated
## recruits must stay unique among themselves, never equal a template id,
## and never equal a live offer's id.
func test_recruit_adventurer_ids_stay_unique_across_repeated_recruits() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	var template_ids: Array = []
	for template in GameSessionScript.RECRUITMENT_CANDIDATE_TEMPLATES:
		template_ids.append(template.id)

	session.recruit_adventurer()
	session.recruit_adventurer()

	assert_eq(session.adventurers.size(), GameSessionScript.STARTING_ROSTER_SIZE + 2)
	var live_candidate_ids: Array = []
	for candidate in session.get_recruitment_candidates():
		live_candidate_ids.append(candidate.id)
	var seen_ids: Dictionary = {}
	for adventurer in session.adventurers:
		assert_false(seen_ids.has(adventurer.id), "Adventurer ids must be unique; found a duplicate: %s" % adventurer.id)
		assert_false(template_ids.has(adventurer.id), "A generated id must never equal a recruitment template id")
		assert_false(live_candidate_ids.has(adventurer.id), "A generated id must never equal a live offer's id")
		seen_ids[adventurer.id] = true


func _recruitment_candidate(candidate_id: String) -> Dictionary:
	var candidate: Dictionary = GameSessionScript.RECRUITMENT_CANDIDATE_TEMPLATES[0].duplicate(true)
	candidate.id = candidate_id
	return candidate


## The onboarding decision seeds all four fixed-pool templates as live
## offers (3 warriors + 1 scout), each a fresh record: generated id, the
## claimed template_id, a cosmetic counter name, and class baselines.
func test_get_recruitment_candidates_returns_the_four_seeded_offers() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	var template_ids: Array = []
	for template in GameSessionScript.RECRUITMENT_CANDIDATE_TEMPLATES:
		template_ids.append(template.id)

	var candidates: Array[Dictionary] = session.get_recruitment_candidates()

	assert_eq(candidates.size(), GameSessionScript.RECRUITMENT_CANDIDATE_TEMPLATES.size())
	var seen_ids: Dictionary = {}
	var warrior_count := 0
	for index in candidates.size():
		var candidate: Dictionary = candidates[index]
		assert_eq(candidate.template_id, template_ids[index], "Offers seed in template-pool order")
		assert_ne(candidate.id, "", "Offer ids are generated")
		assert_ne(candidate.id, candidate.template_id, "An offer's identity is no longer the template's identity")
		assert_false(template_ids.has(candidate.id))
		assert_false(seen_ids.has(candidate.id), "Offer ids must be unique")
		seen_ids[candidate.id] = true
		assert_eq(candidate.level, 1, "A recruitment candidate starts at level 1")
		assert_eq(candidate.availability_status, "available")
		assert_eq(candidate.cost, 10, "Every fixed candidate costs 10 gold")
		assert_eq(candidate.name, _expected_offer_name(session, index))
		if candidate["class"] == "warrior":
			warrior_count += 1
	assert_eq(warrior_count, 3, "The seeded composition is 3 warriors and 1 scout")


## Cosmetic counter names for the seeded offers: the four roster warriors
## count first, so the warrior offers continue at 5 and the first-ever
## scout is plain "Scout" (offer 1 is minted between offers 0 and 2).
func _expected_offer_name(session: Node, offer_index: int) -> String:
	match offer_index:
		0: return "Warrior 5"
		1: return "Scout"
		2: return "Warrior 6"
		3: return "Warrior 7"
	return ""


func test_get_recruitment_candidates_returns_a_copy_that_cannot_mutate_the_catalog() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var candidates: Array[Dictionary] = session.get_recruitment_candidates()
	candidates[0].name = "Mutated"

	var second_candidates: Array[Dictionary] = session.get_recruitment_candidates()
	assert_eq(
		second_candidates[0].name,
		_expected_offer_name(session, 0),
		"Mutating a returned candidate must not affect the catalog"
	)


func test_reset_restores_the_four_seeded_recruitment_offers() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 10
	session.purchase_recruit(_candidate_id_for_template(session, "warrior_002"))

	session.reset()

	var candidates: Array[Dictionary] = session.get_recruitment_candidates()
	var template_ids: Array = []
	for candidate in candidates:
		template_ids.append(candidate.template_id)
	var expected_template_ids: Array = []
	for template in GameSessionScript.RECRUITMENT_CANDIDATE_TEMPLATES:
		expected_template_ids.append(template.id)
	assert_eq(template_ids, expected_template_ids, "reset() must restore all four seeded offers")


func test_purchase_recruit_fails_without_enough_gold_and_changes_nothing() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_false(session.purchase_recruit(_candidate_id_for_template(session, "warrior_002")))

	assert_eq(session.gold, 0)
	assert_eq(session.get_recruitment_candidates().size(), GameSessionScript.RECRUITMENT_CANDIDATE_TEMPLATES.size())
	assert_eq(session.adventurers.size(), GameSessionScript.STARTING_ROSTER_SIZE)


func test_purchase_recruit_fails_for_an_unknown_candidate_id() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 10

	assert_false(session.purchase_recruit("no_such_candidate"))

	assert_eq(session.gold, 10)
	assert_eq(session.get_recruitment_candidates().size(), GameSessionScript.RECRUITMENT_CANDIDATE_TEMPLATES.size())
	assert_eq(session.adventurers.size(), GameSessionScript.STARTING_ROSTER_SIZE)


func test_purchase_recruit_fails_for_an_already_purchased_candidate() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 20
	var candidate_id := _candidate_id_for_template(session, "warrior_002")
	session.purchase_recruit(candidate_id)

	assert_false(session.purchase_recruit(candidate_id))

	assert_eq(session.gold, 10, "Only the first purchase should deduct gold")
	assert_eq(
		session.adventurers.size(),
		GameSessionScript.STARTING_ROSTER_SIZE + 1,
		"A repeated purchase must not append a second adventurer"
	)


func test_purchase_recruit_deducts_gold_removes_the_candidate_and_adds_the_adventurer() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 10
	var candidate_id := _candidate_id_for_template(session, "warrior_002")

	assert_true(session.purchase_recruit(candidate_id))

	assert_eq(session.gold, 0, "The exact candidate cost must be deducted")
	assert_eq(
		session.get_recruitment_candidates().size(),
		GameSessionScript.RECRUITMENT_CANDIDATE_TEMPLATES.size() - 1,
		"The purchased candidate should be removed from the catalog, leaving the other seeded offers"
	)

	assert_eq(session.adventurers.size(), GameSessionScript.STARTING_ROSTER_SIZE + 1)
	var recruit: Dictionary = session.adventurers[session.adventurers.size() - 1]
	assert_eq(recruit.id, candidate_id)
	assert_eq(recruit.template_id, "warrior_002", "The purchased adventurer keeps the claimed template_id")
	assert_eq(recruit["class"], "warrior")
	assert_eq(recruit.level, 1)
	assert_eq(recruit.availability_status, "available")
	assert_false(recruit.has("cost"), "The adventurer record should not carry a purchase cost")


func test_purchase_recruit_for_party_is_atomic_and_assigns_the_purchased_candidate() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.gold = 10
	var candidate_id := _candidate_id_for_template(session, "warrior_002")
	assert_true(session.purchase_recruit_for_party(candidate_id, session.FIRST_PARTY_ID))
	assert_eq(session.gold, 0)
	assert_false(session.has_recruitment_candidate(candidate_id))
	assert_eq(session.get_party(session.FIRST_PARTY_ID).member_ids, [candidate_id])
	assert_eq(session.recruitment_vacancies.size(), 1)


func test_purchase_recruit_for_party_rejects_every_invalid_guard_without_mutation() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.gold = 10
	var invalid_requests := [["missing", session.FIRST_PARTY_ID], [_candidate_id_for_template(session, "warrior_002"), "missing"]]
	for request in invalid_requests:
		var gold_before: int = session.gold
		var candidates_before: Array = session.get_recruitment_candidates()
		var roster_before: Array = session.adventurers.duplicate(true)
		var members_before: Array = session.get_party(session.FIRST_PARTY_ID).member_ids.duplicate()
		var vacancies_before: Array = session.recruitment_vacancies.duplicate(true)
		assert_false(session.purchase_recruit_for_party(request[0], request[1]))
		assert_eq(session.gold, gold_before)
		assert_eq(session.get_recruitment_candidates(), candidates_before)
		assert_eq(session.adventurers, roster_before)
		assert_eq(session.get_party(session.FIRST_PARTY_ID).member_ids, members_before)
		assert_eq(session.recruitment_vacancies, vacancies_before)


func _assert_direct_recruit_rejection_is_atomic(session: Node, candidate_id: String, party_id: String) -> void:
	var gold_before: int = session.gold
	var candidates_before: Array = session.get_recruitment_candidates()
	var roster_before: Array = session.adventurers.duplicate(true)
	var members_before: Array = session.get_party(party_id).member_ids.duplicate()
	var vacancies_before: Array = session.recruitment_vacancies.duplicate(true)
	assert_false(session.purchase_recruit_for_party(candidate_id, party_id))
	assert_eq(session.gold, gold_before)
	assert_eq(session.get_recruitment_candidates(), candidates_before)
	assert_eq(session.adventurers, roster_before)
	assert_eq(session.get_party(party_id).member_ids, members_before)
	assert_eq(session.recruitment_vacancies, vacancies_before)


func test_purchase_recruit_for_party_rejects_insufficient_funds_atomically() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	_assert_direct_recruit_rejection_is_atomic(session, _candidate_id_for_template(session, "warrior_002"), session.FIRST_PARTY_ID)


func test_purchase_recruit_for_party_rejects_a_deployed_target_atomically() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party(session.WARRIOR_ID)
	session.deploy_party(session.FIRST_PARTY_ID)
	session.gold = 10
	_assert_direct_recruit_rejection_is_atomic(session, _candidate_id_for_template(session, "warrior_002"), session.FIRST_PARTY_ID)


func test_purchase_recruit_for_party_rejects_a_full_target_atomically() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	for adventurer in session.adventurers.duplicate():
		session.assign_adventurer_to_selected_party(adventurer.id)
	session.gold = 10
	_assert_direct_recruit_rejection_is_atomic(session, _candidate_id_for_template(session, "warrior_002"), session.FIRST_PARTY_ID)


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
	var candidate_id := _candidate_id_for_template(session, "warrior_002")
	assert_true(session.purchase_recruit(candidate_id))

	session.create_party()
	session.assign_adventurer_to_selected_party(candidate_id)
	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 5.0)

	var recruit: Dictionary = session.get_adventurer(candidate_id)
	assert_eq(
		recruit.stats.max_health,
		session.get_default_warrior().stats.max_health,
		"A purchased recruit must start with the Warrior baseline max health, not a missing key"
	)
	assert_eq(
		recruit.stats.melee,
		session.get_default_warrior().stats.melee,
		"A purchased recruit must start with the Warrior baseline Melee, not a missing key"
	)
	assert_eq(recruit.progression.xp, 5.0, "Awarded party XP must be stored, not silently dropped")


## Task 1: progression domain (award_party_xp, spend_attack_points,
## choose_perk) and the derived effective-hit/health/move calculations that
## GameSession centralizes for later battle and UI tasks to call into.

func test_award_party_xp_divides_a_five_point_award_evenly_between_two_members() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	var first_member_id: String = session.adventurers[0].id
	var second_member_id: String = session.adventurers[1].id
	session.create_party()
	session.assign_adventurer_to_selected_party(first_member_id)
	session.assign_adventurer_to_selected_party(second_member_id)

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 5.0)

	assert_eq(session.get_adventurer(first_member_id).progression.xp, 2.5)
	assert_eq(session.get_adventurer(second_member_id).progression.xp, 2.5)


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


func test_leveling_rolls_skill_gains_within_tier_ranges_and_recomputes_max_health() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.skill_gain_roll = func(min_val: int, max_val: int) -> int: return max_val
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 20.0)

	var warrior: Dictionary = session.get_adventurer("warrior_001")
	assert_eq(warrior.stats.max_health, 20, "Leveling once should set max_health = vitality * level")
	assert_eq(warrior.stats.melee, 64, "Melee tier med max gain (+4)")
	assert_eq(warrior.stats.missile, 64, "Missile tier med max gain (+4)")
	assert_eq(warrior.stats.guard, 2, "Guard tier low max gain (+2)")
	assert_eq(warrior.stats.might, 4, "Might tier med max gain (+4)")


func test_fresh_adventurers_and_recruits_start_at_full_health() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	var warrior: Dictionary = session.get_adventurer("warrior_001")
	assert_eq(warrior.health, 10)
	assert_eq(session.get_current_health("warrior_001"), 10)


func test_get_current_health_and_set_adventurer_health_clamp_and_reject_unknown_ids() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	assert_eq(session.get_current_health("unknown_id"), 0)
	assert_false(session.set_adventurer_health("unknown_id", 5))

	assert_true(session.set_adventurer_health("warrior_001", 4))
	assert_eq(session.get_current_health("warrior_001"), 4)

	session.set_adventurer_health("warrior_001", 0)
	assert_eq(session.get_current_health("warrior_001"), 1, "Health cannot drop below 1 outside battle")

	session.set_adventurer_health("warrior_001", 999)
	assert_eq(session.get_current_health("warrior_001"), 10, "Health cannot exceed effective max health")


func test_apply_battle_aftermath_persists_reported_health_with_a_floor_of_one() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.apply_battle_aftermath({"warrior_001": 3, "unknown_id": 10})
	assert_eq(session.get_current_health("warrior_001"), 3)

	session.apply_battle_aftermath({"warrior_001": 0})
	assert_eq(session.get_current_health("warrior_001"), 1, "Downed units persist at 1 health")


## Step 2 of docs/plans/2026-08-18-core-loop-and-engagement: unit permadeath
## resolution (resolve_battle_deaths()) and its gear-recovery pipeline.

func test_resolve_battle_deaths_removes_a_zero_health_unit_from_the_roster_and_party() -> void:
	GameSession.reset()
	var survivor_id: String = GameSession.adventurers[1].id
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.assign_adventurer_to_selected_party(survivor_id)

	var dead_ids: Array[String] = GameSession.resolve_battle_deaths({"warrior_001": 0, survivor_id: 5})

	assert_eq(dead_ids, ["warrior_001"])
	assert_true(GameSession.get_adventurer("warrior_001").is_empty(), "The dead unit is erased from the roster")
	assert_false(GameSession.get_adventurer(survivor_id).is_empty(), "A surviving unit is untouched")
	assert_eq(GameSession.get_selected_party().member_ids, [survivor_id])


func test_resolve_battle_deaths_ignores_negative_reported_health_the_same_as_zero() -> void:
	GameSession.reset()

	var dead_ids: Array[String] = GameSession.resolve_battle_deaths({"warrior_001": -3})

	assert_eq(dead_ids, ["warrior_001"])
	assert_true(GameSession.get_adventurer("warrior_001").is_empty())


## Validation runs to completion before any mutation: an unknown id in the
## same batch as a genuine kill must not block that genuine kill from
## resolving, and the unknown id itself must never crash roster inspection.
func test_resolve_battle_deaths_validates_every_id_before_mutating_and_ignores_unknown_ids() -> void:
	GameSession.reset()

	var dead_ids: Array[String] = GameSession.resolve_battle_deaths({"warrior_001": 0, "no_such_id": 0})

	assert_eq(dead_ids, ["warrior_001"], "The unknown id must not be reported as a resolved kill")
	assert_true(GameSession.get_adventurer("warrior_001").is_empty(), "The genuine kill in the same batch must still resolve")
	assert_true(GameSession.get_adventurer("no_such_id").is_empty(), "An unknown id must remain a safe no-op lookup")


## The slain unit's ordinary carried gear (its starting Iron Longsword and
## Leather Armor -- both plain stackable ids, not unique instances) and its
## carried potion all move to pending_gear in one pass, retained until the
## existing settlement transition (deposit_pending_reward()) banks them --
## never banked directly by this transaction.
func test_resolve_battle_deaths_transfers_ordinary_carried_gear_to_pending_loot() -> void:
	GameSession.reset()
	GameSession.banked_gear["healing_potion"] = 1
	GameSession.equip_item_from_bank("warrior_001", "healing_potion")

	GameSession.resolve_battle_deaths({"warrior_001": 0})

	assert_eq(GameSession.pending_gear, {"longsword_iron": 1, "leather_armor": 1, "healing_potion": 1})
	assert_eq(GameSession.banked_gear.get("longsword_iron", 0), 0, "Not banked directly by the permadeath transaction")
	assert_eq(GameSession.banked_gear.get("leather_armor", 0), 0, "Not banked directly by the permadeath transaction")


## A unique modified instance (e.g. a sharpened weapon) moves into pending_
## gear by its own instance id, not folded into a plain item count, and its
## owned_item_instances record (carrying its modifier tiers) is left
## completely untouched -- "never delete a recovered owned-item record."
func test_resolve_battle_deaths_transfers_a_unique_item_instance_preserving_its_modifiers() -> void:
	GameSession.reset()
	GameSession.banked_gear["dagger_steel"] = 1
	var instance_id: String = GameSession.materialize_banked_item_instance("dagger_steel")
	GameSession.set_item_instance_modifier(instance_id, "treatment", GameSession.SHARPENED_TREATMENT_ID, 1)
	GameSession.equip_item_from_bank("warrior_001", instance_id)

	GameSession.resolve_battle_deaths({"warrior_001": 0})

	assert_eq(GameSession.pending_gear.get(instance_id, 0), 1, "The instance id itself moves to pending loot")
	assert_true(
		GameSession.owned_item_instances.has(instance_id),
		"The owned-instance record must never be deleted on a successful recovery"
	)
	assert_eq(
		GameSession.owned_item_instances[instance_id].treatment_id, GameSession.SHARPENED_TREATMENT_ID,
		"Its modifiers must survive the transfer intact"
	)
	assert_false(
		GameSession.banked_item_instance_ids.has(instance_id),
		"Not banked directly -- only the settlement transition banks recovered loot"
	)


## Only the dead unit's own carried gear moves; a party's survivors keep
## their own equipment untouched, and only the party membership reference
## unique to the dead unit is stripped.
func test_resolve_battle_deaths_only_transfers_the_dead_units_own_gear() -> void:
	GameSession.reset()
	var survivor_id: String = GameSession.adventurers[1].id
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.assign_adventurer_to_selected_party(survivor_id)

	GameSession.resolve_battle_deaths({"warrior_001": 0, survivor_id: 5})

	assert_eq(GameSession.pending_gear, {"longsword_iron": 1, "leather_armor": 1})
	assert_eq(
		GameSession.get_adventurer(survivor_id).equipment.weapon_inventory, ["longsword_iron"],
		"A surviving member's own equipment must be untouched"
	)


## Step 1 of docs/plans/2026-08-21-stage-1-campaign-spine: pre-battle
## Withdraw (withdraw_from_encounter()) -- a nonlethal alternative to
## entering an authored/sandbox encounter, available only before Battlefield
## is ever reached.

func test_withdraw_from_encounter_rolls_once_per_living_deployed_member_and_can_apply_no_loss() -> void:
	GameSession.reset()
	var survivor_id: String = GameSession.adventurers[1].id
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.assign_adventurer_to_selected_party(survivor_id)
	GameSession.depart_selected_party()
	var encounter_id := "obj_tier1_1_goblin_outpost"
	var encounter_position: Vector2i = GameSession.get_expedition(encounter_id).position
	GameSession.set_deployed_party_position(encounter_position)
	# An Array, not a plain int, since GDScript lambdas capture a local int by
	# value -- an in-lambda increment would never be visible out here.
	var roll_calls := [0]
	var no_loss_roll := func() -> float:
		roll_calls[0] += 1
		return 0.0

	var results: Array[Dictionary] = GameSession.withdraw_from_encounter(encounter_id, no_loss_roll)

	assert_eq(roll_calls[0], 2, "One roll per living deployed member")
	assert_eq(results.size(), 2)
	assert_eq(GameSession.get_current_health("warrior_001"), 10, "A roll below 0.90 must leave health untouched")
	assert_eq(GameSession.get_current_health(survivor_id), GameSession.get_effective_max_health(survivor_id))


func test_withdraw_from_encounter_applies_a_rounded_up_ten_percent_loss_that_cannot_kill() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	var encounter_id := "obj_tier1_1_goblin_outpost"
	var encounter_position: Vector2i = GameSession.get_expedition(encounter_id).position
	GameSession.set_deployed_party_position(encounter_position)
	var high_roll := func() -> float: return 0.95

	var results: Array[Dictionary] = GameSession.withdraw_from_encounter(encounter_id, high_roll)

	# warrior_001's 10 max health -> ceili(10 * 0.10) == 1 lost, never below 1 HP.
	assert_eq(GameSession.get_current_health("warrior_001"), 9)
	assert_eq(results.size(), 1)
	assert_eq(results[0].id, "warrior_001")
	assert_eq(results[0].previous_health, 10)
	assert_eq(results[0].new_health, 9)


func test_withdraw_from_encounter_preserves_the_objective_and_records_a_homeward_route() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	var encounter_id := "obj_tier1_1_goblin_outpost"
	var encounter_position: Vector2i = GameSession.get_expedition(encounter_id).position
	GameSession.set_deployed_party_position(encounter_position)
	var pending_reward_before := GameSession.pending_reward
	var pending_gear_before := GameSession.pending_gear.duplicate(true)
	var battle_reward_before := GameSession.battle_reward

	GameSession.withdraw_from_encounter(encounter_id, func() -> float: return 0.95)

	assert_eq(GameSession.campaign_objective_id, encounter_id, "The current objective must remain current")
	assert_true(GameSession.can_enter_encounter(encounter_id), "The encounter must remain enterable")
	assert_false(GameSession.is_encounter_complete(encounter_id))
	assert_eq(GameSession.pending_reward, pending_reward_before, "Withdraw must not touch reward buckets")
	assert_eq(GameSession.pending_gear, pending_gear_before)
	assert_eq(GameSession.battle_reward, battle_reward_before)
	var route := GameSession.get_deployed_party_route()
	assert_false(route.is_empty(), "A homeward route must be recorded")
	assert_eq(
		route[route.size() - 1], GameSession.STARTING_SETTLEMENT_WORLD_POSITION,
		"The recorded route must lead to the settlement"
	)


func test_withdraw_from_encounter_is_a_no_op_when_the_party_is_not_at_the_encounter() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	var encounter_id := "obj_tier1_1_goblin_outpost"

	var results: Array[Dictionary] = GameSession.withdraw_from_encounter(encounter_id, func() -> float: return 0.95)

	assert_true(results.is_empty())
	assert_eq(GameSession.get_current_health("warrior_001"), 10, "Health must be untouched")
	assert_true(GameSession.get_deployed_party_route().is_empty(), "No route may be recorded")


func test_withdraw_from_encounter_is_a_no_op_once_a_battle_is_already_selected() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	var encounter_id := "obj_tier1_1_goblin_outpost"
	var encounter_position: Vector2i = GameSession.get_expedition(encounter_id).position
	GameSession.set_deployed_party_position(encounter_position)
	GameSession.enter_encounter(encounter_id)

	var results: Array[Dictionary] = GameSession.withdraw_from_encounter(encounter_id, func() -> float: return 0.95)

	assert_true(results.is_empty())
	assert_eq(GameSession.selected_encounter, encounter_id, "The active battle selection must be untouched")


## deposit_pending_reward() -- the existing party-to-Encampment settlement
## transition -- is the only thing that ever banks recovered permadeath
## loot; resolve_battle_deaths() alone never reaches banked_gear/banked_
## item_instance_ids.
func test_recovered_permadeath_loot_is_only_banked_by_the_settlement_transition() -> void:
	GameSession.reset()
	GameSession.banked_gear["dagger_steel"] = 1
	var instance_id: String = GameSession.materialize_banked_item_instance("dagger_steel")
	GameSession.equip_item_from_bank("warrior_001", instance_id)

	GameSession.resolve_battle_deaths({"warrior_001": 0})
	assert_eq(GameSession.banked_gear.get("leather_armor", 0), 0, "Not banked yet")
	assert_false(GameSession.banked_item_instance_ids.has(instance_id), "Not banked yet")

	GameSession.deposit_pending_reward()

	assert_eq(GameSession.banked_gear.get("leather_armor", 0), 1, "Now banked by the settlement transition")
	assert_true(GameSession.banked_item_instance_ids.has(instance_id), "The instance is now banked, not folded into a count")
	assert_eq(GameSession.pending_gear, {})


## A dead id must not remain in live session state, parties, or save
## snapshots (docs/designs/campaign-loop.md).
func test_dead_unit_id_does_not_survive_into_the_campaign_snapshot() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")

	GameSession.resolve_battle_deaths({"warrior_001": 0})
	var snapshot: Dictionary = GameSession.export_campaign_snapshot()

	for adventurer in snapshot.adventurers:
		assert_ne(adventurer.id, "warrior_001")
	for party in snapshot.parties:
		assert_false(party.member_ids.has("warrior_001"))


func test_leveling_up_raises_current_health_by_the_vitality_delta() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.set_adventurer_health("warrior_001", 4)

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 20.0)

	var warrior: Dictionary = session.get_adventurer("warrior_001")
	assert_eq(warrior.stats.max_health, 20)
	assert_eq(warrior.health, 14, "Leveling raises current health by the 10-point vitality delta")


func test_end_world_turn_applies_natural_recovery_based_on_encamped_resting_and_moving_states() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.HEAL_RATE_ENCAMPED = 4
	session.HEAL_RATE_RESTING = 2
	session.HEAL_RATE_MOVING = 1

	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	# Party is not deployed -> Encamped rate (4)
	session.set_adventurer_health("warrior_001", 2)
	session.end_world_turn()
	assert_eq(session.get_current_health("warrior_001"), 6, "Encamped recovery heals 4")

	# Deploy party -> Deployed resting rate (2) when not moved
	session.depart_selected_party()
	session.set_adventurer_health("warrior_001", 2)

	session.end_world_turn()
	assert_eq(session.get_current_health("warrior_001"), 4, "Deployed resting recovery heals 2")

	# Deployed moving rate (1) when movement_spent is true
	session.set_adventurer_health("warrior_001", 2)
	session.parties[0].movement_spent = true
	session.end_world_turn()
	assert_eq(session.get_current_health("warrior_001"), 3, "Deployed moving recovery heals 1")

	# Full health is a no-op
	session.set_adventurer_health("warrior_001", 10)
	session.end_world_turn()
	assert_eq(session.get_current_health("warrior_001"), 10)


## Perk selection (docs/plans/2026-08-21-stage-2-party-readiness/
## 02-class-progression-and-perks.md): choose_perk() only ever accepts one of
## the adventurer's own class's two locked perks (docs/designs/class-
## system.md's "Stage 2 locked perk set"), only once a slot is pending, and
## only once per perk. Every scenario below is a red/green rejection that
## must leave progression.perks completely untouched.

func test_choose_perk_accepts_a_class_owned_perk_only_once_and_only_when_pending() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")

	assert_false(
		session.choose_perk("warrior_001", GameSessionScript.WARRIOR_JUGGERNAUT_PERK_ID),
		"A perk cannot be chosen before any slot is pending (level 1, no interval reached yet)"
	)
	assert_eq(session.get_adventurer("warrior_001").progression.perks, [])

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 50.0)
	assert_true(session.is_perk_choice_pending("warrior_001"))

	assert_true(session.choose_perk("warrior_001", GameSessionScript.WARRIOR_JUGGERNAUT_PERK_ID))
	assert_eq(
		session.get_adventurer("warrior_001").progression.perks, [GameSessionScript.WARRIOR_JUGGERNAUT_PERK_ID]
	)

	assert_false(
		session.choose_perk("warrior_001", GameSessionScript.WARRIOR_JUGGERNAUT_PERK_ID),
		"The same perk cannot be chosen a second time (duplicate selection)"
	)
	assert_eq(
		session.get_adventurer("warrior_001").progression.perks, [GameSessionScript.WARRIOR_JUGGERNAUT_PERK_ID],
		"A rejected duplicate selection leaves progression.perks unchanged"
	)


func test_choose_perk_rejects_an_unknown_perk_id() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 50.0)

	assert_false(session.choose_perk("warrior_001", "no_such_perk"))
	assert_eq(session.get_adventurer("warrior_001").progression.perks, [])


## bonus_move is retired from new choices for every class (docs/designs/
## class-system.md), including a Warrior, who has no class-owned AP perk of
## its own to conflict with it -- retirement is unconditional, not merely
## "unless nothing else offers this effect".
func test_choose_perk_rejects_bonus_move_as_a_new_choice() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 50.0)

	assert_false(session.choose_perk("warrior_001", GameSessionScript.BONUS_MOVE_PERK_ID))
	assert_eq(session.get_adventurer("warrior_001").progression.perks, [])


func test_choose_perk_rejects_a_perk_belonging_to_a_different_class() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 50.0)

	assert_false(
		session.choose_perk("warrior_001", GameSessionScript.SCOUT_QUICKDRAW_PERK_ID),
		"A Warrior cannot choose a Scout-owned perk"
	)
	assert_eq(session.get_adventurer("warrior_001").progression.perks, [])


## progression.perk_tree_size (2) caps how many slots ever open, even though
## PERK_LEVEL_INTERVAL alone would open a third at level 9 -- once both of a
## class's perks are chosen, is_perk_choice_pending() must stay false
## permanently, and every further choose_perk() call (whether the id is
## already-owned or simply unavailable) must leave state unchanged.
func test_is_perk_choice_pending_and_choose_perk_stay_locked_once_both_class_slots_are_spent() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 200.0)  # crosses the level 6 threshold (200 XP)

	assert_eq(session.get_adventurer("warrior_001").level, 6)
	assert_true(session.is_perk_choice_pending("warrior_001"), "Level 6 earns both of a Warrior's two locked slots")
	assert_true(session.choose_perk("warrior_001", GameSessionScript.WARRIOR_JUGGERNAUT_PERK_ID))
	assert_true(session.choose_perk("warrior_001", GameSessionScript.WARRIOR_BULWARK_PERK_ID))
	assert_false(session.is_perk_choice_pending("warrior_001"), "Both slots are now spent")
	assert_eq(session.get_available_perks("warrior_001"), [] as Array[String])

	# Award enough further XP to cross level 9 (the third PERK_LEVEL_INTERVAL
	# multiple) -- PERK_TREE_SIZE must still cap this at zero new slots.
	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 250.0)
	assert_eq(session.get_adventurer("warrior_001").level, 9)
	assert_false(
		session.is_perk_choice_pending("warrior_001"),
		"A class with only two locked perks never opens a third slot, however high level climbs"
	)
	assert_false(session.choose_perk("warrior_001", GameSessionScript.WARRIOR_JUGGERNAUT_PERK_ID))
	assert_eq(
		session.get_adventurer("warrior_001").progression.perks,
		[GameSessionScript.WARRIOR_JUGGERNAUT_PERK_ID, GameSessionScript.WARRIOR_BULWARK_PERK_ID],
		"A rejected full-slot selection leaves progression.perks unchanged"
	)


## get_available_perks() is scoped to exactly the calling adventurer's own
## class -- a pure data query, independent of level or of whether a slot is
## currently pending -- and never lists an already-chosen perk again.
func test_get_available_perks_lists_only_the_adventurers_own_class_perks_not_yet_chosen() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	var scout: Dictionary = session.get_default_scout("scout_test", "Test Scout")
	session.adventurers.append(scout)
	session.assign_adventurer_to_selected_party("scout_test")

	# get_available_perks() is a pure "which of this class's perks are not
	# yet chosen" query -- it does not itself gate on is_perk_choice_pending()
	# (that is level_up.gd's own job before ever calling it, see its
	# _refresh_perk_options()), so both scout perks already list here even
	# at level 1.
	assert_eq(
		session.get_available_perks("scout_test"),
		[GameSessionScript.SCOUT_QUICKDRAW_PERK_ID, GameSessionScript.SCOUT_KEEN_EYES_PERK_ID],
		"A Scout sees only its own two class perks, neither yet chosen"
	)

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 50.0)  # level 3

	session.choose_perk("scout_test", GameSessionScript.SCOUT_QUICKDRAW_PERK_ID)
	assert_eq(
		session.get_available_perks("scout_test"),
		[GameSessionScript.SCOUT_KEEN_EYES_PERK_ID],
		"An already-chosen perk is never offered again"
	)

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 150.0)  # level 6 (200 total XP)
	assert_eq(session.get_adventurer("scout_test").level, 6)
	assert_eq(
		session.get_available_perks("scout_test"),
		[GameSessionScript.SCOUT_KEEN_EYES_PERK_ID],
		"The unchosen Keen Eyes perk remains available at the second slot"
	)


## Legacy compatibility (docs/designs/class-system.md): an adventurer who
## already holds the retired universal bonus_move perk is never migrated --
## it keeps its own effect exactly as before, sits alongside the class-owned
## perks as a "third" perk, and critically never consumes one of the two new
## class-owned slots. A Scout is used here (rather than a Warrior/Cleric,
## neither of whom has any class-owned AP perk) specifically because it lets
## bonus_move's flat +1 AP and Quickdraw's own configured AP bonus stack
## independently, proving they are tracked as genuinely separate bonuses.
func test_legacy_bonus_move_holder_is_not_migrated_and_still_earns_both_class_perk_slots() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	var scout: Dictionary = session.get_default_scout("scout_test", "Test Scout")
	scout.progression.perks.append(GameSessionScript.BONUS_MOVE_PERK_ID)
	session.adventurers.append(scout)
	session.assign_adventurer_to_selected_party("scout_test")
	assert_eq(session.get_effective_action_points("scout_test"), 7, "The pre-existing bonus_move perk already applies")

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 200.0)  # level 6: two locked slots earned
	assert_eq(session.get_adventurer("scout_test").level, 6)
	assert_true(
		session.is_perk_choice_pending("scout_test"),
		"bonus_move must not have silently consumed either of the two new class slots"
	)
	assert_eq(
		session.get_available_perks("scout_test"),
		[GameSessionScript.SCOUT_QUICKDRAW_PERK_ID, GameSessionScript.SCOUT_KEEN_EYES_PERK_ID]
	)

	assert_true(session.choose_perk("scout_test", GameSessionScript.SCOUT_QUICKDRAW_PERK_ID))
	assert_true(session.choose_perk("scout_test", GameSessionScript.SCOUT_KEEN_EYES_PERK_ID))
	assert_false(session.is_perk_choice_pending("scout_test"), "Both of the Scout's own slots are now spent")
	assert_eq(
		session.get_adventurer("scout_test").progression.perks,
		[
			GameSessionScript.BONUS_MOVE_PERK_ID, GameSessionScript.SCOUT_QUICKDRAW_PERK_ID,
			GameSessionScript.SCOUT_KEEN_EYES_PERK_ID,
		]
	)
	assert_eq(
		session.get_effective_action_points("scout_test"), 8,
		"bonus_move's +1 and Quickdraw's own +1 stack independently: 6 base + 1 + 1"
	)


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

	session.adventurers[0].stats.melee = 100

	var warrior: Dictionary = session.get_adventurer("warrior_001")
	assert_eq(warrior.stats.melee, 100, "Raw Melee itself is not capped")
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


## A legacy bonus_move holder (see the migration test above for how it gets
## there -- direct progression.perks mutation, since choose_perk() no longer
## accepts it) still gets its flat +1 AP.
func test_get_effective_action_points_adds_the_legacy_bonus_move_perk() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")

	assert_eq(session.get_effective_action_points("warrior_001"), 6)

	session.adventurers[0].progression.perks.append(GameSessionScript.BONUS_MOVE_PERK_ID)

	assert_eq(session.get_effective_action_points("warrior_001"), 7, "bonus_move grants one flexible action point")


## --- Stage 2 locked perk effects (docs/plans/2026-08-21-stage-2-party-
## readiness/02-class-progression-and-perks.md): each of the six perk
## effects below is verified to land on its own single named effective-stat
## reader and nowhere else -- a battery of unrelated readers is checked
## alongside the target one so a perk that accidentally leaked into the
## wrong reader would fail loudly here. ---

func test_warrior_juggernaut_adds_its_configured_percent_to_effective_max_health_only() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 50.0)  # level 3: base max_health 30

	var defense_before: int = session.get_effective_defense("warrior_001")
	var ap_before: int = session.get_effective_action_points("warrior_001")

	assert_true(session.choose_perk("warrior_001", GameSessionScript.WARRIOR_JUGGERNAUT_PERK_ID))

	assert_eq(
		session.get_effective_max_health("warrior_001"), 35,
		"30 base + round(30 * 15%) = 35 (config-driven warrior_juggernaut_hp_percent)"
	)
	assert_eq(session.get_effective_defense("warrior_001"), defense_before, "Juggernaut must not touch Guard/defense")
	assert_eq(session.get_effective_action_points("warrior_001"), ap_before, "Juggernaut must not touch Action Points")


func test_warrior_bulwark_adds_its_configured_guard_to_effective_defense_only() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 50.0)  # level 3

	# Guard grows by a real random roll each level-up (skill_gain_roll is not
	# pinned here), so the pre-perk defense is captured fresh rather than
	# assumed, and the perk's contribution is checked as a delta on top of it.
	var defense_before: int = session.get_effective_defense("warrior_001")
	var max_health_before: int = session.get_effective_max_health("warrior_001")
	var ap_before: int = session.get_effective_action_points("warrior_001")

	assert_true(session.choose_perk("warrior_001", GameSessionScript.WARRIOR_BULWARK_PERK_ID))

	assert_eq(
		session.get_effective_defense("warrior_001"), defense_before + 10,
		"Bulwark adds exactly its config-driven warrior_bulwark_guard (10) on top of whatever defense already was"
	)
	assert_eq(session.get_effective_max_health("warrior_001"), max_health_before, "Bulwark must not touch max health")
	assert_eq(session.get_effective_action_points("warrior_001"), ap_before, "Bulwark must not touch Action Points")


func test_scout_quickdraw_adds_its_configured_bonus_to_effective_action_points_only() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	var scout: Dictionary = session.get_default_scout("scout_test", "Test Scout")
	session.adventurers.append(scout)
	session.assign_adventurer_to_selected_party("scout_test")
	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 50.0)  # level 3

	var max_health_before: int = session.get_effective_max_health("scout_test")
	var defense_before: int = session.get_effective_defense("scout_test")

	assert_true(session.choose_perk("scout_test", GameSessionScript.SCOUT_QUICKDRAW_PERK_ID))

	assert_eq(session.get_effective_action_points("scout_test"), 7, "6 base + 1 config-driven quickdraw bonus")
	assert_eq(session.get_effective_max_health("scout_test"), max_health_before, "Quickdraw must not touch max health")
	assert_eq(session.get_effective_defense("scout_test"), defense_before, "Quickdraw must not touch defense")


func test_scout_keen_eyes_adds_its_configured_bonus_to_effective_scout_intel_range_only() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	var scout: Dictionary = session.get_default_scout("scout_test", "Test Scout")
	session.adventurers.append(scout)
	session.assign_adventurer_to_selected_party("scout_test")
	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 50.0)  # level 3

	assert_eq(session.get_effective_scout_intel_range("scout_test"), 3, "Base Scout intel range")
	var ap_before: int = session.get_effective_action_points("scout_test")

	assert_true(session.choose_perk("scout_test", GameSessionScript.SCOUT_KEEN_EYES_PERK_ID))

	assert_eq(
		session.get_effective_scout_intel_range("scout_test"), 4,
		"3 base + 1 config-driven scout_keen_eyes_intel_range_bonus"
	)
	assert_eq(session.get_effective_action_points("scout_test"), ap_before, "Keen Eyes must not touch Action Points")


## get_party_scouting_intel() reads get_effective_scout_intel_range() per
## Scout member (see that function's own doc comment) rather than a flat
## constant -- a party whose Scout has chosen Keen Eyes sees intel at
## distance 4, which test_get_party_scouting_intel_hides_composition_when_
## the_scout_is_four_or_more_squares_away above proves is out of range for a
## Scout without the perk.
func test_get_party_scouting_intel_reveals_composition_at_distance_four_with_keen_eyes() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	var scout: Dictionary = session.get_default_scout("scout_test", "Test Scout")
	session.adventurers.append(scout)
	session.assign_adventurer_to_selected_party("scout_test")
	# award_party_xp() splits its amount evenly across all party members
	# (two here), so 100 total XP gives each member 50 -- exactly the level
	# 3 threshold.
	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 100.0)  # level 3 for both members
	assert_true(session.choose_perk("scout_test", GameSessionScript.SCOUT_KEEN_EYES_PERK_ID))
	session.deploy_party(GameSessionScript.FIRST_PARTY_ID)
	# Goblin Camp sits at (4, 4) (difficulty 1); (0, 4) is Manhattan distance 4.
	session.set_deployed_party_position(Vector2i(0, 4))

	var intel: Dictionary = session.get_party_scouting_intel(
		GameSessionScript.FIRST_PARTY_ID, GameSessionScript.GOBLIN_CAMP_ID
	)

	assert_true(intel.has_intel, "Keen Eyes extends detection range to 4 tiles")
	assert_eq(intel.danger_tier, 1)


func test_cleric_meditation_adds_its_configured_bonus_to_effective_spell_range_only() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	var cleric: Dictionary = session.get_default_cleric("cleric_test", "Test Cleric")
	session.adventurers.append(cleric)
	session.assign_adventurer_to_selected_party("cleric_test")
	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 50.0)  # level 3

	assert_eq(session.get_effective_spell_range("cleric_test"), 3, "Base Cleric spell range")
	var max_health_before: int = session.get_effective_max_health("cleric_test")

	assert_true(session.choose_perk("cleric_test", GameSessionScript.CLERIC_MEDITATION_PERK_ID))

	assert_eq(
		session.get_effective_spell_range("cleric_test"), 4,
		"3 base + 1 config-driven cleric_meditation_spell_range_bonus"
	)
	assert_eq(session.get_effective_max_health("cleric_test"), max_health_before, "Meditation must not touch max health")


func test_cleric_devout_adds_its_configured_percent_to_effective_max_health_only() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	var cleric: Dictionary = session.get_default_cleric("cleric_test", "Test Cleric")
	session.adventurers.append(cleric)
	session.assign_adventurer_to_selected_party("cleric_test")
	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 50.0)  # level 3: base max_health 36 (vitality 12 * 3)

	var spell_range_before: int = session.get_effective_spell_range("cleric_test")
	var defense_before: int = session.get_effective_defense("cleric_test")

	assert_true(session.choose_perk("cleric_test", GameSessionScript.CLERIC_DEVOUT_PERK_ID))

	assert_eq(
		session.get_effective_max_health("cleric_test"), 40,
		"36 base + round(36 * 10%) = 40 (config-driven cleric_devout_hp_percent)"
	)
	assert_eq(session.get_effective_spell_range("cleric_test"), spell_range_before, "Devout must not touch spell range")
	assert_eq(session.get_effective_defense("cleric_test"), defense_before, "Devout must not touch defense")


## Task 7 (docs/plans/2026-08-21-stage-2-party-readiness/
## 02-class-progression-and-perks.md): monster-manual.md's "Stage 2 locked
## values" table used to be a mean-of-range approximation (melee 63.5, guard
## 11.5, might +3.5 -- see docs/designs/monster-manual.md's Calibration
## Baseline section). This pins skill_gain_roll to a fully deterministic,
## reproducible sequence -- always the top of each skill's gain range,
## rather than a real seeded roll, since GameSession's own leveling loop
## already takes skill_gain_roll as its sole entropy source -- computes the
## resulting REAL (not averaged) level-2 Warrior baseline, and checks the
## comparison figures monster-manual.md's own table now derives from it
## against every initial-roster monster's real stats. If a future change to
## skill gain ranges, Might's damage contribution, or a monster's stats moves
## any of these numbers, this test and monster-manual.md's own table must be
## updated together -- never silently patched around by retuning a monster
## to hide a failed comparison (see this step's own doc comment).
func test_deterministic_level_two_warrior_baseline_matches_monster_manual_table() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.skill_gain_roll = func(_min_value: int, max_value: int) -> int: return max_value
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 20.0)  # exactly the level-2 threshold

	var warrior: Dictionary = session.get_adventurer("warrior_001")
	assert_eq(warrior.level, 2)
	assert_eq(warrior.stats.melee, 64, "60 base + a pinned max melee gain of 4 ('med' tier, one level-up)")
	assert_eq(int(warrior.stats.guard), 2, "0 base + a pinned max guard gain of 2 ('low' tier, one level-up)")
	assert_eq(warrior.stats.might, 4, "0 base + a pinned max might gain of 4 ('med' tier, one level-up)")
	assert_eq(session.get_effective_max_health("warrior_001"), 20, "vitality 10 * level 2, unaffected by pinning")
	assert_eq(session.get_effective_defense("warrior_001"), 12, "10 leather armor + 2 pinned Guard")

	var hit_chance: float = session.get_effective_hit_chance("warrior_001")
	var mean_weapon_damage_with_might: float = 4.5 + session.get_effective_might("warrior_001")  # Iron Longsword 1-8
	var expected_damage_per_swing: float = hit_chance * mean_weapon_damage_with_might
	var warrior_guard: int = session.get_effective_defense("warrior_001")
	var warrior_resistance: int = session.get_effective_resistance("warrior_001")

	var monsters := {
		"Kobold": GameSessionScript.KOBOLD_ENEMY_STATS,
		"Goblin": GameSessionScript.GOBLIN_ENEMY_STATS,
		"Orc": GameSessionScript.ORC_ENEMY_STATS,
		"Hobgoblin": GameSessionScript.HOBGOBLIN_ENEMY_STATS,
	}
	# See docs/designs/monster-manual.md's "Stage 2 locked values" table --
	# these are that table's own numbers, recalculated here from the real
	# pinned baseline above rather than Step 1's mean-based approximation.
	var expected_attacks_to_defeat := {"Kobold": 1.1, "Goblin": 2.4, "Orc": 4.0, "Hobgoblin": 5.5}
	var expected_damage_to_warrior := {"Kobold": 0.12, "Goblin": 0.32, "Orc": 1.03, "Hobgoblin": 1.73}

	for monster_name in monsters:
		var monster: Dictionary = monsters[monster_name]

		var attacks_to_defeat: float = monster.max_health / expected_damage_per_swing
		assert_almost_eq(
			snappedf(attacks_to_defeat, 0.1), expected_attacks_to_defeat[monster_name], 0.001,
			"%s expected-attacks-to-defeat must match monster-manual.md's Stage 2 table" % monster_name
		)

		var monster_hit_chance: float = maxf(0.0, float(monster.hit_chance) - warrior_guard / 100.0)
		var monster_mean_damage: float = float(monster.attack_damage) * (1.0 - warrior_resistance / 100.0)
		var damage_to_warrior: float = monster_hit_chance * monster_mean_damage
		assert_almost_eq(
			snappedf(damage_to_warrior, 0.01), expected_damage_to_warrior[monster_name], 0.001,
			"%s expected-damage-to-Warrior-per-attack must match monster-manual.md's Stage 2 table" % monster_name
		)


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


func test_reset_seeds_all_four_recruitment_offers_from_the_template_pool() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var candidates: Array[Dictionary] = session.get_recruitment_candidates()

	assert_eq(candidates.size(), GameSessionScript.RECRUITMENT_CANDIDATE_TEMPLATES.size(), "A fresh campaign seeds every fixed-pool template as a live offer")
	var template_ids: Array = []
	for candidate in candidates:
		template_ids.append(candidate.template_id)
	assert_eq(template_ids, ["warrior_002", "scout_002", "warrior_003", "warrior_004"])


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

	session.purchase_recruit(_candidate_id_for_template(session, "warrior_002"))

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

	session.purchase_recruit(_candidate_id_for_template(session, "warrior_002"))

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
	session.reset()
	# Force the base result so this test keeps validating "a purchase starts
	# one vacancy clock at the documented base delay" rather than the jitter
	# range _resolve_vacancy_delay() now resolves (see vacancy_delay_roll and
	# its dedicated jitter tests above).
	session.vacancy_delay_roll = func(_minimum: int, _maximum: int) -> int: return session.RECRUITMENT_VACANCY_TURNS
	session.gold = 10
	var candidate_id: String = session.get_recruitment_candidates()[0].id

	assert_true(session.purchase_recruit(candidate_id))

	assert_eq(session.recruitment_vacancies.size(), 1)
	assert_eq(session.recruitment_vacancies[0].turns_remaining, session.RECRUITMENT_VACANCY_TURNS)


func test_a_failed_purchase_starts_no_recruitment_vacancy_clock() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.reset()
	session.gold = 0
	var candidate_id: String = session.get_recruitment_candidates()[0].id

	assert_false(session.purchase_recruit(candidate_id), "Zero gold should reject the purchase")

	assert_eq(session.recruitment_vacancies, [] as Array[Dictionary])


func test_recruitment_vacancy_does_not_refill_before_turn_thirty() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.reset()
	# Force the base result -- see test_a_successful_purchase_starts_one_thirty_turn_recruitment_vacancy_clock.
	session.vacancy_delay_roll = func(_minimum: int, _maximum: int) -> int: return session.RECRUITMENT_VACANCY_TURNS
	session.gold = 10
	var candidate_id: String = session.get_recruitment_candidates()[0].id
	session.purchase_recruit(candidate_id)

	for i in session.RECRUITMENT_VACANCY_TURNS - 1:
		session.end_world_turn()

	assert_eq(session.get_recruitment_candidates().size(), 3)
	assert_eq(session.recruitment_vacancies.size(), 1)


func test_recruitment_vacancy_refills_exactly_at_turn_thirty_under_the_cap() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.reset()
	# Force the base result -- see test_a_successful_purchase_starts_one_thirty_turn_recruitment_vacancy_clock.
	session.vacancy_delay_roll = func(_minimum: int, _maximum: int) -> int: return session.RECRUITMENT_VACANCY_TURNS
	session.recruitment_class_roll = func() -> String: return "scout"
	session.gold = 10
	var candidate_id: String = session.get_recruitment_candidates()[0].id
	session.purchase_recruit(candidate_id)

	for i in session.RECRUITMENT_VACANCY_TURNS:
		session.end_world_turn()

	var candidates: Array[Dictionary] = session.get_recruitment_candidates()
	assert_eq(candidates.size(), 4, "Turn 30 after the purchase should refill exactly one new offer back to cap of 4")
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
		"A fired clock is consumed after evicting the oldest offer to make room, not rescheduled or caught up later"
	)

	for i in 5:
		session.end_world_turn()
	assert_eq(session.get_recruitment_candidates().size(), 4, "A capped pool must never grow past its cap, no matter how many clocks fire")


## TDD Task 1's overflow bullet: "Test candidate overflow removes oldest
## offer when new offer arrives." The sibling test above only asserts
## .size() holds at the cap, which would also pass if refills were silently
## discarded instead of evicting-and-replacing -- this test pins the actual
## FIFO contract (_advance_recruitment_vacancies(): recruitment_candidates.
## remove_at(0) before appending the new offer) by asserting the specific
## oldest offer is gone while the rest survive in their original order.
func test_recruitment_refill_evicts_the_oldest_offer_specifically() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.recruitment_candidates = [
		_recruitment_candidate("warrior_002"),
		_recruitment_candidate("warrior_003"),
		_recruitment_candidate("warrior_004"),
		_recruitment_candidate("warrior_010"),
	] as Array[Dictionary]
	session.recruitment_vacancies.append({"turns_remaining": 1})

	session.end_world_turn()

	var candidates: Array[Dictionary] = session.get_recruitment_candidates()
	assert_eq(candidates.size(), 4, "A refill must never push active offers above the cap")
	assert_false(
		session.has_recruitment_candidate("warrior_002"),
		"The oldest offer (FIFO head, index 0) must be evicted to make room for the refill"
	)
	assert_eq(candidates[0].id, "warrior_003", "The second-oldest offer becomes the new head, preserving arrival order")
	assert_eq(candidates[1].id, "warrior_004", "Surviving offers keep their relative order")
	assert_eq(candidates[2].id, "warrior_010", "Surviving offers keep their relative order")
	assert_eq(
		["warrior_002", "warrior_003", "warrior_004", "warrior_010"].find(candidates[3].id), -1,
		"The newly spawned offer (FIFO tail) must be distinct from every surviving seeded offer"
	)


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
	# Exhaust every fixed template (warrior_002, scout_002, warrior_003/004) as roster members, so
	# the overflow mint path must synthesize a fresh id.
	session.adventurers.append(_adventurer("warrior_002", "available"))
	session.adventurers.append(_adventurer("scout_002", "available"))
	session.adventurers.append(_adventurer("warrior_003", "available"))
	session.adventurers.append(_adventurer("warrior_004", "available"))
	session.recruitment_candidates = [] as Array[Dictionary]
	session.recruitment_vacancies.append({"turns_remaining": 1})

	session.end_world_turn()

	var candidates: Array[Dictionary] = session.get_recruitment_candidates()
	assert_eq(candidates.size(), 1, "The overflow mint path must still deliver exactly one new offer")
	var new_id: String = candidates[0].id
	assert_false(
		["warrior_002", "scout_002", "warrior_003", "warrior_004"].has(new_id),
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


func test_get_max_party_size_returns_three_at_level_one() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.get_max_party_size(), 3)


func test_get_max_party_size_returns_four_at_level_two() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.guild_hall_level = 2

	assert_eq(session.get_max_party_size(), 4)


func test_get_max_party_size_returns_five_at_level_three() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.guild_hall_level = 3

	assert_eq(session.get_max_party_size(), 5)


## Guild Hall tier model: 10/4 roster/offer caps at level 1, 15/8 at level 2,
## 20/10 at level 3 (see docs/plans/2026-08-18-core-loop-and-engagement/03-
## encampment-buildings-and-tier-model.md).
func test_get_roster_cap_scales_with_guild_hall_level() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.get_roster_cap(), 10)
	session.guild_hall_level = 2
	assert_eq(session.get_roster_cap(), 15)
	session.guild_hall_level = 3
	assert_eq(session.get_roster_cap(), 20)


func test_get_recruitment_offer_cap_scales_with_guild_hall_level() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.get_recruitment_offer_cap(), 4)
	session.guild_hall_level = 2
	assert_eq(session.get_recruitment_offer_cap(), 8)
	session.guild_hall_level = 3
	assert_eq(session.get_recruitment_offer_cap(), 10)


func test_purchase_recruit_rejects_a_roster_already_at_cap() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 1000
	while session.adventurers.size() < session.get_roster_cap():
		session.adventurers.append(_adventurer("filler_%d" % session.adventurers.size(), "available"))
	var candidate_id: String = session.get_recruitment_candidates()[0].id

	assert_false(session.purchase_recruit(candidate_id), "A full roster must reject a new recruit")


func test_upgrade_guild_hall_with_fifty_gold_succeeds() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 50

	assert_true(session.upgrade_guild_hall())

	assert_eq(session.guild_hall_level, 2)
	assert_eq(session.gold, 0)
	assert_eq(session.get_max_party_size(), 4)


func test_upgrade_guild_hall_with_forty_nine_gold_fails() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 49

	assert_false(session.upgrade_guild_hall())

	assert_eq(session.guild_hall_level, 1)
	assert_eq(session.gold, 49)


## Level 2 -> 3 costs GUILD_HALL_LEVEL_3_UPGRADE_COST (100), a different
## amount than the level 1 -> 2 upgrade (50) -- see _guild_hall_upgrade_cost().
func test_upgrade_guild_hall_from_level_two_to_three_costs_one_hundred_gold() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 50
	session.upgrade_guild_hall()
	session.gold = 99

	assert_false(session.upgrade_guild_hall(), "99 gold is not enough for the level 2 -> 3 upgrade")

	session.gold = 100

	assert_true(session.upgrade_guild_hall())
	assert_eq(session.guild_hall_level, 3)
	assert_eq(session.gold, 0)
	assert_eq(session.get_max_party_size(), 5)


func test_upgrade_guild_hall_at_max_level_returns_false() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 200
	session.upgrade_guild_hall()
	session.upgrade_guild_hall()
	assert_eq(session.guild_hall_level, 3)

	assert_false(session.upgrade_guild_hall())

	assert_eq(session.gold, 50, "Gold should not be deducted on a failed upgrade after two successes (50 + 100 spent)")
	assert_eq(session.guild_hall_level, 3)


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
	session.gold = 200
	session.upgrade_guild_hall()
	session.upgrade_guild_hall()

	assert_false(session.can_upgrade_guild_hall())


## --- Temple ---

func test_new_session_starts_with_temple_unbuilt() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.temple_level, 0)


func test_reset_restores_temple_level_to_zero() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.temple_level = 1

	session.reset()

	assert_eq(session.temple_level, 0)


func test_can_build_temple_requires_the_build_cost() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_false(session.can_build_temple())

	session.gold = session.TEMPLE_BUILD_COST - 1
	assert_false(session.can_build_temple())

	session.gold = session.TEMPLE_BUILD_COST
	assert_true(session.can_build_temple())


func test_build_temple_deducts_gold_and_sets_level_one() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = session.TEMPLE_BUILD_COST

	assert_true(session.build_temple())

	assert_eq(session.temple_level, 1)
	assert_eq(session.gold, 0)


func test_build_temple_fails_once_already_built() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = session.TEMPLE_BUILD_COST * 2
	session.build_temple()

	assert_false(session.build_temple(), "The Temple has only one buildable level in this slice")
	assert_eq(session.temple_level, 1)


## Building the Temple must immediately guarantee a recruitable Cleric
## offer -- a one-time grant at construction, not the ongoing probabilistic
## cleric_offer_roll refill (see build_temple()'s doc comment).
func test_build_temple_immediately_adds_a_cleric_recruitment_offer() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = session.TEMPLE_BUILD_COST

	assert_true(session.build_temple())

	var has_cleric_offer := false
	for candidate in session.recruitment_candidates:
		if candidate["class"] == "cleric":
			has_cleric_offer = true
			break
	assert_true(has_cleric_offer, "Building the Temple should guarantee a recruitable Cleric offer")


## When the offer pool is already at cap, the guaranteed Cleric offer must
## evict the oldest (FIFO head) offer, matching the overflow policy already
## established by _advance_recruitment_vacancies().
func test_build_temple_evicts_oldest_offer_when_pool_is_at_cap() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = session.TEMPLE_BUILD_COST
	assert_eq(session.recruitment_candidates.size(), session.get_recruitment_offer_cap(),
		"Precondition: a fresh campaign seeds the offer pool to its cap")
	var oldest_offer_id: String = session.recruitment_candidates[0]["id"]

	assert_true(session.build_temple())

	assert_eq(session.recruitment_candidates.size(), session.get_recruitment_offer_cap(),
		"The pool stays at cap -- the guaranteed offer evicts rather than overflows it")
	var still_has_oldest := false
	var has_cleric_offer := false
	for candidate in session.recruitment_candidates:
		if candidate["id"] == oldest_offer_id:
			still_has_oldest = true
		if candidate["class"] == "cleric":
			has_cleric_offer = true
	assert_false(still_has_oldest, "The oldest pre-existing offer should have been evicted")
	assert_true(has_cleric_offer)


## Minimal Cleric stub (see CLASS_DEFINITIONS.cleric's own doc comment): base
## stats in the same family as warrior/scout, no MP/Heal/Bless fields --
## those are Step 4's job.
func test_cleric_class_definition_exists_in_the_warrior_scout_family() -> void:
	assert_true(GameSession.CLASS_DEFINITIONS.has("cleric"))
	var cleric: Dictionary = GameSession.CLASS_DEFINITIONS.cleric
	assert_true(cleric.has("base_stats"))
	assert_true(cleric.has("allowed_weapon_categories"))
	assert_false(cleric.has("mp"), "MP is out of scope for this step")
	assert_false(cleric.has("abilities"), "Heal/Bless abilities are out of scope for this step")


func test_get_default_cleric_returns_a_seeded_cleric_record() -> void:
	var cleric := GameSession.get_default_cleric("cleric_test", "Test Cleric")

	assert_eq(cleric.class, "cleric")
	assert_eq(cleric.stats, GameSession.CLASS_DEFINITIONS.cleric.base_stats)
	assert_eq(cleric.health, GameSession.CLASS_DEFINITIONS.cleric.base_stats.max_health)
	assert_true(GameSession.CLASS_DEFINITIONS.cleric.allowed_weapon_categories.has(
		GameSession.WEAPONS[cleric.equipment.weapon].category
	), "the Cleric's default weapon must be one its own class can equip")


## Temple gating (see docs/plans/2026-08-18-core-loop-and-engagement/03-
## encampment-buildings-and-tier-model.md): a Cleric candidate must be
## structurally impossible before the Temple is built, not just unlikely --
## cleric_offer_roll is never even consulted while temple_level is 0.
func test_cleric_offer_roll_is_never_consulted_before_the_temple_is_built() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.reset()
	var roll_called := false
	session.cleric_offer_roll = func() -> bool:
		roll_called = true
		return true
	session.recruitment_vacancies.append({"turns_remaining": 1})

	session.end_world_turn()

	assert_false(roll_called, "cleric_offer_roll must not be consulted while the Temple is unbuilt")
	var candidates: Array[Dictionary] = session.get_recruitment_candidates()
	assert_false(candidates.any(func(c): return c.class == "cleric"))


func test_a_built_temple_can_produce_a_real_cleric_recruitment_offer() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.reset()
	session.temple_level = 1
	session.cleric_offer_roll = func() -> bool: return true
	session.recruitment_vacancies.append({"turns_remaining": 1})

	session.end_world_turn()

	var candidates: Array[Dictionary] = session.get_recruitment_candidates()
	assert_true(candidates.any(func(c): return c.class == "cleric"), "A built Temple must be able to offer a real Cleric candidate")


func test_purchasing_a_cleric_offer_lands_a_cleric_on_the_roster() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.reset()
	session.temple_level = 1
	session.cleric_offer_roll = func() -> bool: return true
	session.recruitment_vacancies.append({"turns_remaining": 1})
	session.end_world_turn()
	var cleric_offer: Dictionary = session.get_recruitment_candidates().filter(func(c): return c.class == "cleric")[0]
	session.gold = 1000

	assert_true(session.purchase_recruit(cleric_offer.id))

	var roster_cleric: Dictionary = session.get_adventurer(cleric_offer.id)
	assert_eq(roster_cleric.class, "cleric")
	assert_eq(roster_cleric.stats, GameSession.CLASS_DEFINITIONS.cleric.base_stats)


## --- Cleric spellcasting schema & progression (Step 4) ---

## Step 4 replaces Step 3's minimal stub with the full Cleric: blunt weapons,
## a spellcasting stat, and its two spells.
func test_cleric_class_definition_has_full_spellcasting_schema() -> void:
	var cleric: Dictionary = GameSession.CLASS_DEFINITIONS.cleric

	assert_true(cleric.allowed_weapon_categories.has("mace"))
	assert_true(cleric.allowed_weapon_categories.has("hammer"))
	assert_true(cleric.allowed_weapon_categories.has("staff"))
	assert_true(cleric.base_stats.has("spellcasting"))
	assert_eq(cleric.mp_max, 3)
	assert_eq(cleric.spells, ["heal", "bless"])
	assert_true(cleric.skills.has("spellcasting"))


func test_get_default_cleric_equips_a_mace_weapon() -> void:
	var cleric := GameSession.get_default_cleric("cleric_test", "Test Cleric")

	assert_eq(cleric.equipment.weapon, "mace_iron")
	assert_eq(GameSession.WEAPONS.mace_iron.category, "mace")


func test_leveling_up_a_cleric_grows_health_melee_guard_and_spellcasting() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.skill_gain_roll = func(_min_val: int, max_val: int) -> int: return max_val
	session.create_party()
	var cleric: Dictionary = session.get_default_cleric("cleric_test", "Test Cleric")
	session.adventurers.append(cleric)
	session.assign_adventurer_to_selected_party("cleric_test")

	session.award_party_xp(GameSessionScript.FIRST_PARTY_ID, 20.0)

	var leveled: Dictionary = session.get_adventurer("cleric_test")
	assert_eq(leveled.level, 2)
	assert_eq(leveled.stats.max_health, 24, "max_health = vitality(12) * level(2)")
	assert_eq(leveled.stats.melee, 47, "melee tier low max gain (+2)")
	assert_eq(leveled.stats.guard, 14, "guard tier med max gain (+4)")
	assert_eq(leveled.stats.spellcasting, 60, "spellcasting tier hi max gain (+5)")
	assert_eq(leveled.stats.might, 3, "might tier low max gain (+2)")


## --- Scout strategic reconnaissance (Step 4) ---

func test_get_party_scouting_intel_reveals_composition_when_a_scout_is_within_range() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	var scout: Dictionary = session.get_default_scout("scout_test", "Test Scout")
	session.adventurers.append(scout)
	session.assign_adventurer_to_selected_party("scout_test")
	session.deploy_party(GameSessionScript.FIRST_PARTY_ID)
	var goblin_camp: Dictionary = session.get_expedition(GameSessionScript.GOBLIN_CAMP_ID)
	session.set_deployed_party_position(goblin_camp.position)

	var intel: Dictionary = session.get_party_scouting_intel(
		GameSessionScript.FIRST_PARTY_ID, GameSessionScript.GOBLIN_CAMP_ID
	)

	assert_true(intel.has_intel)
	assert_eq(intel.danger_tier, 1)
	assert_eq(intel.enemy_count, 1)
	assert_eq(intel.enemy_types, [tr("battle.enemy.goblin")])


func test_get_party_scouting_intel_hides_composition_without_a_scout() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.deploy_party(GameSessionScript.FIRST_PARTY_ID)
	var goblin_camp: Dictionary = session.get_expedition(GameSessionScript.GOBLIN_CAMP_ID)
	session.set_deployed_party_position(goblin_camp.position)

	var intel: Dictionary = session.get_party_scouting_intel(
		GameSessionScript.FIRST_PARTY_ID, GameSessionScript.GOBLIN_CAMP_ID
	)

	assert_false(intel.has_intel, "No Scout in the party means no detailed composition")
	assert_eq(intel.enemy_types, [])
	assert_eq(intel.enemy_count, 0)
	assert_eq(intel.danger_tier, 0, "Danger tier is withheld too -- only the bare location is public")


func test_get_party_scouting_intel_hides_composition_when_the_scout_is_four_or_more_squares_away() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	var scout: Dictionary = session.get_default_scout("scout_test", "Test Scout")
	session.adventurers.append(scout)
	session.assign_adventurer_to_selected_party("scout_test")
	session.deploy_party(GameSessionScript.FIRST_PARTY_ID)
	# Goblin Camp sits at (4, 4) (difficulty 1); (0, 4) is Manhattan distance 4.
	session.set_deployed_party_position(Vector2i(0, 4))

	var intel: Dictionary = session.get_party_scouting_intel(
		GameSessionScript.FIRST_PARTY_ID, GameSessionScript.GOBLIN_CAMP_ID
	)

	assert_false(intel.has_intel, "A Scout four squares away is still out of reconnaissance range")
	assert_eq(intel.danger_tier, 0, "Out-of-range still withholds the danger tier, not just composition")


func test_get_party_scouting_intel_returns_empty_for_an_unknown_party_or_encounter() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")

	assert_eq(session.get_party_scouting_intel("nope", GameSessionScript.GOBLIN_CAMP_ID), {})
	assert_eq(session.get_party_scouting_intel(GameSessionScript.FIRST_PARTY_ID, "nope"), {})


## --- Blacksmith ---

## --- Alchemy Workshop ---

## --- Runic Workshop ---

func test_runic_workshop_builds_upgrades_and_starts_one_thorn_job_atomically() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 120
	session.mana_crystals = {1: 2}
	session.banked_gear = {"leather_armor": 1}
	assert_true(session.materialize_banked_item_instance("leather_armor", "thorn_armor"))

	assert_false(session.start_runic_craft("thorn_armor"), "A Runic Workshop is required")
	assert_true(session.build_runic_workshop())
	assert_eq(session.runic_workshop_level, 1)
	assert_eq(session.gold, 70)
	assert_true(session.start_runic_craft("thorn_armor"))
	assert_eq(session.gold, 50)
	assert_eq(session.mana_crystals, {1: 1})
	assert_false(session.start_runic_craft("thorn_armor"), "Only one Runic Workshop job may run")
	assert_true(session.upgrade_runic_workshop(), "Exactly 50 gold is sufficient to upgrade")
	assert_eq(session.runic_workshop_level, 2)
	assert_eq(session.gold, 0)


func test_runic_workshop_job_state_survives_a_campaign_snapshot_round_trip() -> void:
	GameSession.gold = 70
	GameSession.mana_crystals = {1: 1}
	GameSession.banked_gear = {"leather_armor": 1}
	assert_true(GameSession.materialize_banked_item_instance("leather_armor", "thorn_armor"))
	assert_true(GameSession.build_runic_workshop())
	assert_true(GameSession.start_runic_craft("thorn_armor"))
	var snapshot := GameSession.export_campaign_snapshot()
	GameSession.reset()

	assert_true(GameSession.import_campaign_snapshot(snapshot).ok)
	assert_eq(GameSession.runic_workshop_level, 1)
	assert_eq(GameSession.runic_craft_job, snapshot.runic_craft_job)


func test_runic_workshop_sockets_thorn_only_into_owned_armor_after_seven_world_map_turns() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 70
	session.mana_crystals = {1: 1}
	session.banked_gear = {"leather_armor": 1, "dagger_iron": 1}
	assert_true(session.materialize_banked_item_instance("leather_armor", "thorn_armor"))
	assert_true(session.materialize_banked_item_instance("dagger_iron", "thorn_dagger"))
	assert_true(session.build_runic_workshop())

	assert_false(session.start_runic_craft("thorn_dagger"))
	assert_eq(session.gold, 20, "An incompatible target must not spend gold")
	assert_eq(session.mana_crystals, {1: 1}, "An incompatible target must not spend a crystal")
	assert_true(session.start_runic_craft("thorn_armor"))
	for _turn in 6:
		session.end_world_turn()
	assert_eq(session.owned_item_instances.thorn_armor.rune_id, "")
	assert_ne(session.runic_craft_job, {})

	session.end_world_turn()
	assert_eq(session.owned_item_instances.thorn_armor.rune_id, "thorn")
	assert_eq(session.owned_item_instances.thorn_armor.modifier_tiers.rune, 1)
	assert_eq(session.runic_craft_job, {})


func test_runic_workshop_replaces_an_armor_rune_without_returning_the_displaced_rune() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 70
	session.mana_crystals = {1: 1}
	session.banked_gear = {"leather_armor": 1}
	assert_true(session.materialize_banked_item_instance("leather_armor", "thorn_armor"))
	assert_true(session.set_item_instance_modifier("thorn_armor", "rune", "old_rune", 1))
	assert_true(session.build_runic_workshop())
	assert_true(session.start_runic_craft("thorn_armor"))
	for _turn in 7:
		session.end_world_turn()

	assert_eq(session.owned_item_instances.thorn_armor.rune_id, "thorn")
	assert_eq(session.owned_item_instances.thorn_armor.modifier_tiers.rune, 1)
	assert_false(session.banked_gear.has("old_rune"), "A displaced rune is consumed rather than returned")

func test_alchemy_workshop_builds_upgrades_and_starts_only_one_eligible_recipe() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 120
	session.mana_crystals = {1: 1, 2: 1}

	assert_false(session.start_alchemy_craft("healing_potion"), "An Alchemy Workshop is required")
	assert_true(session.build_alchemy_workshop())
	assert_eq(session.alchemy_workshop_level, 1)
	assert_eq(session.gold, 70)
	assert_true(session.start_alchemy_craft("healing_potion"))
	assert_eq(session.gold, 60)
	assert_eq(session.mana_crystals, {2: 1})
	assert_false(session.start_alchemy_craft("healing_potion"), "The workshop has one job slot")
	assert_false(session.start_alchemy_craft("greater_healing_potion"), "Level 2 is required")


func test_alchemy_workshop_jobs_complete_after_seven_world_map_turns_into_stores() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 60
	session.mana_crystals = {1: 1}
	assert_true(session.build_alchemy_workshop())
	assert_true(session.start_alchemy_craft("healing_potion"))

	for _turn in 6:
		session.end_world_turn()
	assert_eq(session.banked_gear.get("healing_potion", 0), 0)
	assert_ne(session.alchemy_craft_job, {})
	session.end_world_turn()
	assert_eq(session.banked_gear.get("healing_potion", 0), 1)
	assert_eq(session.alchemy_craft_job, {})


func test_alchemy_workshop_level_two_consumes_a_tier_two_or_higher_crystal() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 120
	session.mana_crystals = {1: 2}
	assert_true(session.build_alchemy_workshop())
	assert_true(session.upgrade_alchemy_workshop())
	assert_false(session.start_alchemy_craft("greater_healing_potion"))
	assert_eq(session.gold, 20, "The failed recipe must not spend gold")
	session.mana_crystals = {2: 1}
	assert_true(session.start_alchemy_craft("greater_healing_potion"))
	assert_eq(session.gold, 0)
	assert_eq(session.mana_crystals, {})


func test_potions_equip_from_stores_only_while_the_adventurer_has_a_free_total_item_slot() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.banked_gear = {"healing_potion": 10}

	for _slot in 8:
		assert_true(session.equip_item_from_bank(GameSessionScript.WARRIOR_ID, "healing_potion"))
	assert_eq(session.get_carried_item_ids(GameSessionScript.WARRIOR_ID).size(), 10)
	assert_false(session.equip_item_from_bank(GameSessionScript.WARRIOR_ID, "healing_potion"))
	assert_eq(session.banked_gear.healing_potion, 2)


func test_owned_item_instances_also_respect_the_total_carried_item_capacity() -> void:
	var session := GameSessionScript.new()
	session.reset()
	session.banked_gear = {"healing_potion": 8, "dagger_iron": 1}
	for _index in 8:
		assert_true(session.equip_item_from_bank(GameSessionScript.WARRIOR_ID, "healing_potion"))
	assert_eq(session.get_carried_item_ids(GameSessionScript.WARRIOR_ID).size(), GameSessionScript.CARRIED_ITEM_CAPACITY)
	assert_true(session.materialize_banked_item_instance("dagger_iron", "owned_dagger"))

	assert_false(session.equip_item_from_bank(GameSessionScript.WARRIOR_ID, "owned_dagger"))
	assert_true(session.banked_item_instance_ids.has("owned_dagger"))
	assert_eq(session.get_carried_item_ids(GameSessionScript.WARRIOR_ID).size(), GameSessionScript.CARRIED_ITEM_CAPACITY)


func test_alchemy_workshop_and_potion_inventory_survive_a_campaign_snapshot_round_trip() -> void:
	GameSession.gold = 60
	GameSession.mana_crystals = {1: 2}
	assert_true(GameSession.build_alchemy_workshop())
	assert_true(GameSession.start_alchemy_craft("healing_potion"))
	GameSession.banked_gear["healing_potion"] = 1
	assert_true(GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "healing_potion"))
	var snapshot := GameSession.export_campaign_snapshot()
	GameSession.reset()

	assert_true(GameSession.import_campaign_snapshot(snapshot).ok)
	assert_eq(GameSession.alchemy_workshop_level, 1)
	assert_eq(GameSession.alchemy_craft_job, snapshot.alchemy_craft_job)
	assert_eq(GameSession.get_carried_item_ids(GameSession.WARRIOR_ID).count("healing_potion"), 1)


func test_alchemy_snapshot_rejects_more_than_ten_carried_items_without_mutating_live_state() -> void:
	var snapshot := GameSession.export_campaign_snapshot()
	snapshot.adventurers[0].equipment["potion_inventory"] = [
		"healing_potion", "healing_potion", "healing_potion", "healing_potion", "healing_potion",
		"healing_potion", "healing_potion", "healing_potion", "healing_potion",
	]
	var before := _capture_durable_fields()

	var result := GameSession.import_campaign_snapshot(snapshot)

	assert_false(result.ok)
	assert_string_contains(result.error, "carried item")
	assert_eq(_capture_durable_fields(), before)

func test_blacksmith_build_upgrade_and_craft_tier_gates() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 199

	assert_false(session.start_blacksmith_craft("dagger_iron"), "A Blacksmith is required")
	assert_true(session.build_blacksmith())
	assert_eq(session.blacksmith_level, 1)
	assert_eq(session.gold, 149)
	assert_false(session.start_blacksmith_craft("dagger_iron"), "Iron requires level 2")
	assert_true(session.upgrade_blacksmith())
	assert_eq(session.blacksmith_level, 2)
	assert_eq(session.gold, 99)
	assert_true(session.start_blacksmith_craft("dagger_iron"))
	assert_false(session.start_blacksmith_craft("dagger_steel"), "Only one craft job may run")


func test_blacksmith_level_three_unlocks_steel_crafting_for_one_craft_slot() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 200

	assert_true(session.build_blacksmith())
	assert_true(session.upgrade_blacksmith())
	assert_true(session.upgrade_blacksmith())
	assert_eq(session.blacksmith_level, 3)
	assert_eq(session.gold, 0)
	assert_false(session.start_blacksmith_craft("dagger_steel"), "Crafting also requires its price")
	session.gold = session.get_blacksmith_craft_cost("dagger_steel")
	assert_true(session.start_blacksmith_craft("dagger_steel"))


func test_blacksmith_craft_cost_is_ninety_percent_of_sale_price_rounded_up() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	assert_eq(session.get_item_sale_price("dagger_iron"), 5)
	assert_eq(session.get_blacksmith_craft_cost("dagger_iron"), 5)
	assert_eq(session.get_item_sale_price("shortsword_iron"), 10)
	assert_eq(session.get_blacksmith_craft_cost("shortsword_iron"), 9)


func test_blacksmith_failed_job_starts_are_atomic_and_jobs_run_in_parallel() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 110
	assert_true(session.build_blacksmith())
	session.banked_gear["dagger_iron"] = 1
	var gold_before: int = session.gold

	assert_false(session.start_sharpening("longsword_iron"))
	assert_eq(session.gold, gold_before)
	assert_eq(session.banked_gear.dagger_iron, 1)
	assert_eq(session.blacksmith_sharpening_job, {})
	assert_true(session.start_sharpening("dagger_iron"))
	assert_eq(session.banked_gear.get("dagger_iron", 0), 0)
	assert_false(session.start_sharpening("dagger_iron"))
	assert_true(session.upgrade_blacksmith())
	session.gold = 100
	assert_true(session.start_blacksmith_craft("dagger_iron"))
	assert_ne(session.blacksmith_craft_job, {})
	assert_ne(session.blacksmith_sharpening_job, {})


func test_blacksmith_jobs_complete_only_after_their_world_map_turn_durations() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.gold = 200
	assert_true(session.build_blacksmith())
	session.banked_gear["dagger_iron"] = 1
	assert_true(session.start_sharpening("dagger_iron"))
	assert_true(session.upgrade_blacksmith())
	assert_true(session.start_blacksmith_craft("dagger_iron"))

	for _turn in 4:
		session.end_world_turn()
	assert_eq(session.banked_gear.get("dagger_iron", 0), 0)
	assert_ne(session.blacksmith_craft_job, {})
	session.end_world_turn()
	assert_eq(session.banked_gear.get("dagger_iron", 0), 1)
	assert_eq(session.blacksmith_craft_job, {})
	for _turn in 15:
		session.end_world_turn()
	assert_eq(session.blacksmith_sharpening_job, {})
	assert_eq(session.banked_item_instance_ids.size(), 1)
	var instance: Dictionary = session.owned_item_instances[session.banked_item_instance_ids[0]]
	assert_eq(instance.treatment_id, "sharpened")


func test_blacksmith_state_survives_a_campaign_snapshot_round_trip() -> void:
	GameSession.gold = 200
	assert_true(GameSession.build_blacksmith())
	GameSession.banked_gear["dagger_iron"] = 1
	assert_true(GameSession.start_sharpening("dagger_iron"))
	assert_true(GameSession.upgrade_blacksmith())
	assert_true(GameSession.start_blacksmith_craft("dagger_iron"))
	var snapshot := GameSession.export_campaign_snapshot()
	GameSession.reset()

	assert_true(GameSession.import_campaign_snapshot(snapshot).ok)
	assert_eq(GameSession.blacksmith_level, 2)
	assert_eq(GameSession.blacksmith_craft_job, snapshot.blacksmith_craft_job)
	assert_eq(GameSession.blacksmith_sharpening_job, snapshot.blacksmith_sharpening_job)


func test_blacksmith_snapshot_rejects_an_impossible_job_without_mutating_the_session() -> void:
	GameSession.gold = 75
	var before_gold := GameSession.gold
	var snapshot := GameSession.export_campaign_snapshot()
	snapshot.blacksmith_level = 1
	snapshot.blacksmith_craft_job = {"item_id": "dagger_iron", "completion_turn": GameSession.world_turn + 5}

	var result := GameSession.import_campaign_snapshot(snapshot)

	assert_false(result.ok)
	assert_eq(GameSession.gold, before_gold)
	assert_eq(GameSession.blacksmith_level, 0)


func test_sharpened_owned_weapon_grants_its_raw_damage_bonus_only_when_equipped() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.banked_gear["dagger_iron"] = 1
	assert_true(session.materialize_banked_item_instance("dagger_iron", "sharpened_dagger"))
	assert_true(session.set_item_instance_modifier("sharpened_dagger", "treatment", "sharpened", 1))
	assert_eq(session.get_effective_weapon_raw_damage_bonus(GameSessionScript.WARRIOR_ID), 0)
	assert_true(session.equip_item_from_bank(GameSessionScript.WARRIOR_ID, "sharpened_dagger"))
	assert_eq(session.get_effective_weapon_raw_damage_bonus(GameSessionScript.WARRIOR_ID), 1)


func test_snapshot_rejects_a_sharpened_treatment_without_its_modifier_tier() -> void:
	GameSession.banked_gear["dagger_iron"] = 1
	assert_true(GameSession.materialize_banked_item_instance("dagger_iron", "forged_dagger"))
	var snapshot := GameSession.export_campaign_snapshot()
	snapshot.owned_item_instances.forged_dagger.treatment_id = "sharpened"

	var result := GameSession.import_campaign_snapshot(snapshot)

	assert_false(result.ok)
	assert_eq(GameSession.owned_item_instances.forged_dagger.treatment_id, "")


func test_assign_adventurer_to_party_rejects_fourth_member_at_level_one() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.adventurers.append(_adventurer("test_001", "available"))
	session.adventurers.append(_adventurer("test_002", "available"))
	session.adventurers.append(_adventurer("test_003", "available"))

	assert_true(session.assign_adventurer_to_selected_party("test_001"))
	assert_true(session.assign_adventurer_to_selected_party("test_002"))
	assert_false(session.assign_adventurer_to_selected_party("test_003"), "Fourth member must be rejected at level 1")

	assert_eq(session.get_selected_party().member_ids.size(), 3)


func test_assign_adventurer_to_party_accepts_fourth_member_after_upgrade() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.assign_adventurer_to_selected_party("warrior_001")
	session.adventurers.append(_adventurer("test_001", "available"))
	session.adventurers.append(_adventurer("test_002", "available"))
	session.adventurers.append(_adventurer("test_003", "available"))

	assert_true(session.assign_adventurer_to_selected_party("test_001"))
	assert_true(session.assign_adventurer_to_selected_party("test_002"))
	session.gold = session.GUILD_HALL_UPGRADE_COST
	session.upgrade_guild_hall()

	assert_true(session.assign_adventurer_to_selected_party("test_003"), "Fourth member must be accepted after upgrade")

	assert_eq(session.get_selected_party().member_ids.size(), 4)


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
	session.PERK_TREE_SIZE = SENTINEL
	session.WARRIOR_JUGGERNAUT_HP_PERCENT = SENTINEL
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
		session.PERK_TREE_SIZE,
		GameConfig.get_int("progression", "perk_tree_size", SENTINEL),
		"progression.perk_tree_size must come from GameConfig"
	)
	assert_eq(
		session.WARRIOR_JUGGERNAUT_HP_PERCENT,
		GameConfig.get_int("progression", "warrior_juggernaut_hp_percent", SENTINEL),
		"progression.warrior_juggernaut_hp_percent must come from GameConfig"
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


func test_weapons_catalog_has_the_documented_iron_and_steel_damage_price_and_melee_range() -> void:
	assert_eq(GameSessionScript.WEAPONS.dagger_iron, {"name_key": "item.dagger_iron", "slot": "weapon", "category": "dagger", "damage_min": 1, "damage_max": 4, "min_range": 1, "max_range": 1, "price": 10})
	assert_eq(GameSessionScript.WEAPONS.dagger_steel, {"name_key": "item.dagger_steel", "slot": "weapon", "category": "dagger", "damage_min": 2, "damage_max": 5, "min_range": 1, "max_range": 1, "price": 30})
	assert_eq(GameSessionScript.WEAPONS.shortsword_iron, {"name_key": "item.shortsword_iron", "slot": "weapon", "category": "sword", "damage_min": 1, "damage_max": 6, "min_range": 1, "max_range": 1, "price": 20})
	assert_eq(GameSessionScript.WEAPONS.shortsword_steel, {"name_key": "item.shortsword_steel", "slot": "weapon", "category": "sword", "damage_min": 2, "damage_max": 7, "min_range": 1, "max_range": 1, "price": 60})
	assert_eq(GameSessionScript.WEAPONS.longsword_iron, {"name_key": "item.longsword_iron", "slot": "weapon", "category": "sword", "damage_min": 1, "damage_max": 8, "min_range": 1, "max_range": 1, "price": 30})
	assert_eq(GameSessionScript.WEAPONS.longsword_steel, {"name_key": "item.longsword_steel", "slot": "weapon", "category": "sword", "damage_min": 2, "damage_max": 9, "min_range": 1, "max_range": 1, "price": 90})
	assert_eq(GameSessionScript.WEAPONS.two_handed_sword_iron, {"name_key": "item.two_handed_sword_iron", "slot": "weapon", "category": "sword", "damage_min": 1, "damage_max": 10, "min_range": 1, "max_range": 1, "price": 35})
	assert_eq(GameSessionScript.WEAPONS.two_handed_sword_steel, {"name_key": "item.two_handed_sword_steel", "slot": "weapon", "category": "sword", "damage_min": 2, "damage_max": 11, "min_range": 1, "max_range": 1, "price": 105})


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


func test_new_session_starts_with_a_level_one_shop_and_cash() -> void:
	assert_eq(GameSession.shop_level, 1)
	assert_eq(GameSession.shop_gold, 100)


func test_shop_catalogue_unlocks_iron_then_steel_weapons() -> void:
	assert_true(GameSession.get_shop_catalogue_item_ids().all(func(item_id): return item_id.ends_with("_iron")))
	assert_false(GameSession.buy_item("dagger_steel"))
	GameSession.gold = GameSession.SHOP_UPGRADE_COST
	assert_true(GameSession.upgrade_shop())
	assert_true(GameSession.get_shop_catalogue_item_ids().has("dagger_steel"))


func test_level_zero_legacy_shop_has_no_catalogue_or_sales() -> void:
	GameSession.shop_level = 0
	GameSession.shop_gold = 0
	GameSession.banked_gear = {"dagger_iron": 1}
	GameSession.gold = 100
	assert_eq(GameSession.get_shop_catalogue_item_ids(), [] as Array[String])
	assert_false(GameSession.buy_item("dagger_iron"))
	assert_false(GameSession.sell_item("dagger_iron"))


func test_shop_sale_is_atomic_when_cash_is_insufficient() -> void:
	GameSession.banked_gear = {"shortsword_iron": 1}
	GameSession.shop_gold = 9
	assert_false(GameSession.sell_item("shortsword_iron"))
	assert_eq(GameSession.banked_gear.shortsword_iron, 1)
	assert_eq(GameSession.gold, 0)
	assert_eq(GameSession.shop_gold, 9)


func test_shop_buy_transfers_player_gold_to_shop() -> void:
	GameSession.gold = 10
	assert_true(GameSession.buy_item("dagger_iron"))
	assert_eq(GameSession.gold, 0)
	assert_eq(GameSession.shop_gold, 110)


func test_shop_refills_on_turn_ten_but_never_lowers_overcap_cash() -> void:
	GameSession.world_turn = 9
	GameSession.shop_gold = 1
	GameSession.end_world_turn()
	assert_eq(GameSession.shop_gold, 100)
	GameSession.world_turn = 19
	GameSession.shop_gold = 300
	GameSession.end_world_turn()
	assert_eq(GameSession.shop_gold, 300)


func test_blocked_end_turn_does_not_refill_shop_at_turn_boundary() -> void:
	GameSession.world_turn = 9
	GameSession.shop_gold = 1
	GameSession.selected_encounter = GameSession.GOBLIN_CAMP_ID
	assert_false(GameSession.end_world_turn())
	assert_eq(GameSession.world_turn, 9)
	assert_eq(GameSession.shop_gold, 1)


func test_locked_legacy_shop_successful_turn_adds_no_income_or_refill() -> void:
	GameSession.shop_level = 0
	GameSession.shop_gold = 1
	GameSession.gold = 10
	GameSession.world_turn = 9
	GameSession.end_world_turn()
	assert_eq(GameSession.gold, 10)
	assert_eq(GameSession.shop_gold, 1)


func test_invalid_shop_snapshot_keeps_live_state_unchanged() -> void:
	GameSession.gold = 77
	GameSession.shop_level = 2
	GameSession.shop_gold = 150
	var data := GameSession.export_campaign_snapshot()
	data.shop_level = 4
	var result := GameSession.import_campaign_snapshot(data)
	assert_false(result.ok)
	assert_eq(GameSession.gold, 77)
	assert_eq(GameSession.shop_level, 2)
	assert_eq(GameSession.shop_gold, 150)


func test_shop_upgrade_from_level_one_to_two_costs_one_hundred_fifty_gold() -> void:
	assert_false(GameSession.can_upgrade_shop())
	GameSession.gold = GameSession.SHOP_UPGRADE_COST
	assert_true(GameSession.upgrade_shop())
	assert_eq(GameSession.gold, 0)
	assert_eq(GameSession.shop_level, 2)


## Level 2 -> 3 costs SHOP_LEVEL_3_UPGRADE_COST (300), a different amount
## than the level 1 -> 2 upgrade (150) -- see _shop_upgrade_cost(). Once at
## level 3 (the max), a further upgrade is rejected.
func test_shop_upgrade_from_level_two_to_three_costs_three_hundred_gold_and_then_maxes_out() -> void:
	GameSession.gold = GameSession.SHOP_UPGRADE_COST
	GameSession.upgrade_shop()
	GameSession.gold = GameSession.SHOP_LEVEL_3_UPGRADE_COST - 1

	assert_false(GameSession.upgrade_shop(), "One gold short of the level 2 -> 3 cost must fail")

	GameSession.gold = GameSession.SHOP_LEVEL_3_UPGRADE_COST

	assert_true(GameSession.upgrade_shop())
	assert_eq(GameSession.shop_level, 3)
	assert_eq(GameSession.gold, 0)
	assert_false(GameSession.can_upgrade_shop(), "Shop level 3 is the max tier")
	assert_false(GameSession.upgrade_shop())


## Shop Tier 3 unlocks direct purchase of a Minor Healing Potion (restores
## 2-8 HP for 20 gold -- see docs/plans/2026-08-18-core-loop-and-engagement/
## 03-encampment-buildings-and-tier-model.md).
func test_healing_potion_purchase_is_gated_on_shop_level_three() -> void:
	GameSession.gold = 1000
	assert_false(GameSession.can_buy_healing_potion(), "Shop level 1 does not sell healing potions")
	assert_false(GameSession.buy_healing_potion())

	GameSession.shop_level = 2
	assert_false(GameSession.can_buy_healing_potion(), "Shop level 2 does not sell healing potions")

	GameSession.shop_level = 3
	assert_true(GameSession.can_buy_healing_potion())
	assert_true(GameSession.buy_healing_potion())
	assert_eq(GameSession.gold, 980, "A healing potion costs 20 gold")
	assert_eq(GameSession.banked_gear.get("greater_healing_potion", 0), 1)


func test_healing_potion_purchase_requires_twenty_gold() -> void:
	GameSession.shop_level = 3
	GameSession.gold = 19

	assert_false(GameSession.can_buy_healing_potion())
	assert_false(GameSession.buy_healing_potion())
	assert_eq(GameSession.gold, 19)
	assert_eq(GameSession.banked_gear.get("greater_healing_potion", 0), 0)


func test_end_world_turn_adds_shop_income() -> void:
	GameSession.create_party()
	GameSession.end_world_turn()
	assert_eq(GameSession.gold, GameSession.SHOP_INCOME_PER_TURN)


## Step 2 of docs/plans/2026-08-18-core-loop-and-engagement: the economy
## floor's passive Shop income tiers (2/5/10 gold per World Map Turn).
func test_end_world_turn_shop_income_scales_with_shop_level() -> void:
	GameSession.shop_level = 1
	GameSession.end_world_turn()
	assert_eq(GameSession.gold, 2, "Shop level 1 grants 2 gold/turn")

	GameSession.reset()
	GameSession.shop_level = 2
	GameSession.end_world_turn()
	assert_eq(GameSession.gold, 5, "Shop level 2 grants 5 gold/turn")

	GameSession.reset()
	GameSession.shop_level = 3
	GameSession.end_world_turn()
	assert_eq(GameSession.gold, 10, "Shop level 3 grants 10 gold/turn")


## Soft-lock prevention: every recovery system (healing, workshop jobs,
## encounter/recruitment vacancies, Shop income) must keep advancing on
## World Map Turns even with zero parties, or a party with zero living
## members -- e.g. right after a wipe, before the player has recruited a
## replacement.
func test_end_world_turn_advances_every_recovery_system_with_no_deployable_party() -> void:
	GameSession.reset()
	GameSession.parties = []
	GameSession.set_adventurer_health("warrior_001", 1)
	GameSession.blacksmith_level = 2
	GameSession.gold = 100
	assert_true(GameSession.start_blacksmith_craft("shortsword_iron"), "Test setup must actually start the job")
	var starting_world_turn: int = GameSession.world_turn
	var starting_gold: int = GameSession.gold

	var advanced: bool = GameSession.end_world_turn()

	assert_false(advanced, "No deployed party means no auto-move step")
	assert_eq(GameSession.world_turn, starting_world_turn + 1)
	assert_eq(GameSession.get_current_health("warrior_001"), 1 + GameSession.HEAL_RATE_ENCAMPED, "Roster healing advances")
	assert_eq(GameSession.gold, starting_gold + GameSession.SHOP_INCOME_PER_TURN, "Shop income advances")
	assert_eq(
		GameSession.get_blacksmith_job_turns_remaining(GameSession.blacksmith_craft_job),
		GameSession.BLACKSMITH_CRAFT_DURATION_TURNS - 1,
		"The blacksmith job clock advances"
	)


## Same as above, but for a party record that still exists (deployed=false,
## encamped) with zero living members -- e.g. the party dict a wipe leaves
## behind before it is ever removed or repopulated.
func test_end_world_turn_advances_recovery_when_the_only_party_has_no_living_members() -> void:
	GameSession.reset()
	GameSession.create_party()
	var starting_world_turn: int = GameSession.world_turn
	var starting_gold: int = GameSession.gold

	var advanced: bool = GameSession.end_world_turn()

	assert_false(advanced, "The party has no living members, so nothing can auto-move")
	assert_eq(GameSession.world_turn, starting_world_turn + 1)
	assert_eq(GameSession.gold, starting_gold + GameSession.SHOP_INCOME_PER_TURN)


## Soft-lock prevention: a fresh recruitment offer must always include at
## least one level-1 candidate costing 50 gold or less, so a player who just
## hit zero gold (e.g. after a wipe) can still recruit a legal replacement
## once passive income accrues.
func test_recruitment_refill_always_offers_an_affordable_level_one_recruit() -> void:
	GameSession.reset()
	GameSession.reset_injectable_rolls()
	# Empty the live offers and advance past every vacancy's delay so a
	# refill actually happens.
	GameSession.recruitment_candidates = []
	GameSession.recruitment_vacancies = [{"turns_remaining": 1}]
	GameSession.gold = 0

	GameSession.end_world_turn()

	assert_false(GameSession.recruitment_candidates.is_empty(), "A refill must actually occur")
	var affordable_level_one := GameSession.recruitment_candidates.any(
		func(candidate: Dictionary) -> bool: return int(candidate.level) == 1 and int(candidate.cost) <= 50
	)
	assert_true(affordable_level_one, "At least one refreshed offer must be a level-1 recruit costing <= 50 gold")


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


func test_sell_item_requires_enough_stock_and_shop_cash() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"shortsword_iron": 1}

	assert_false(GameSession.sell_item("shortsword_iron", 2), "Only 1 in stock")

	var sold: bool = GameSession.sell_item("shortsword_iron", 1)
	assert_true(sold)
	assert_eq(GameSession.banked_gear.shortsword_iron, 0)
	assert_eq(GameSession.gold, 10)
	assert_eq(GameSession.shop_gold, 90)


func test_sell_item_handles_mana_crystals() -> void:
	GameSession.reset()
	GameSession.mana_crystals = {1: 2}

	var sold: bool = GameSession.sell_item("mana_crystal_1", 2)

	assert_true(sold)
	assert_eq(GameSession.mana_crystals[1], 0)
	assert_eq(GameSession.gold, 10)


func test_buy_item_requires_enough_gold_then_banks_the_item() -> void:
	GameSession.reset()
	assert_false(GameSession.buy_item("dagger_iron"), "No gold yet")

	GameSession.gold = 10
	var bought: bool = GameSession.buy_item("dagger_iron")

	assert_true(bought)
	assert_eq(GameSession.gold, 0)
	assert_eq(GameSession.banked_gear.dagger_iron, 1)
	assert_eq(GameSession.shop_gold, 110)


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


## Step 2 of docs/plans/2026-08-18-core-loop-and-engagement: party-wipe
## forfeiture (resolve_party_wipe()) -- "a wipe loses all gold and loot" but
## must never touch already-completed campaign progress or anything already
## banked before the run that ended in a wipe.
func test_resolve_party_wipe_forfeits_unbanked_gold_and_pending_loot_but_preserves_progress_and_banked_state() -> void:
	GameSession.reset()
	GameSession.gold = 250
	GameSession.pending_reward = 40
	GameSession.pending_mana_crystals = {1: 2}
	GameSession.pending_gear = {"dagger_iron": 1}
	GameSession.banked_gear = {"leather_armor": 3}
	GameSession.mana_crystals = {1: 5}
	GameSession.guild_hall_level = 2
	GameSession.completed_objectives = ["obj_tier1_1_goblin_outpost"]

	GameSession.resolve_party_wipe()

	assert_eq(GameSession.gold, 0, "A wipe loses all gold, banked included")
	assert_eq(GameSession.pending_reward, 0)
	assert_eq(GameSession.pending_mana_crystals, {})
	assert_eq(GameSession.pending_gear, {})
	assert_eq(GameSession.banked_gear, {"leather_armor": 3}, "Already-banked gear is preserved")
	assert_eq(GameSession.mana_crystals, {1: 5}, "Already-banked crystals are preserved")
	assert_eq(GameSession.guild_hall_level, 2, "Building levels are preserved")
	assert_eq(
		GameSession.completed_objectives, ["obj_tier1_1_goblin_outpost"],
		"Completed campaign objectives are preserved"
	)


## A unique item instance still sitting in pending_gear (recovered from a
## fallen member this same run, never banked) is truly lost on a wipe, not
## left as an orphaned, unreferenced owned_item_instances record.
func test_resolve_party_wipe_discards_an_unbanked_recovered_item_instances_record() -> void:
	GameSession.reset()
	GameSession.banked_gear["dagger_steel"] = 1
	var instance_id: String = GameSession.materialize_banked_item_instance("dagger_steel")
	GameSession.equip_item_from_bank("warrior_001", instance_id)
	GameSession.resolve_battle_deaths({"warrior_001": 0})
	assert_true(GameSession.pending_gear.has(instance_id), "Test setup: the instance is pending, not yet banked")

	GameSession.resolve_party_wipe()

	assert_false(GameSession.owned_item_instances.has(instance_id), "An unbanked recovered instance is lost on a wipe")
	assert_false(GameSession.banked_item_instance_ids.has(instance_id))


func test_reset_clears_the_trading_post() -> void:
	GameSession.shop_level = 2

	GameSession.reset()

	assert_eq(GameSession.shop_level, 1)


func test_player_power_is_adventurer_count_plus_guild_hall_level() -> void:
	GameSession.reset()
	assert_eq(GameSession._player_power(), 5, "Four starting adventurers plus Guild Hall level 1")
	GameSession.recruit_adventurer()
	assert_eq(GameSession._player_power(), 6)
	GameSession.guild_hall_level = 2
	assert_eq(GameSession._player_power(), 7)



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
		"campaign_objective_id": GameSession.campaign_objective_id,
		"completed_objectives": GameSession.completed_objectives.duplicate(true),
		"unlocked_authored_encounters": GameSession.unlocked_authored_encounters.duplicate(true),
		"is_campaign_completed": GameSession.is_campaign_completed,
		"is_free_play_active": GameSession.is_free_play_active,
		"completed_encounters": GameSession.completed_encounters.duplicate(true),
		"active_encounters": GameSession.active_encounters.duplicate(true),
		"encounter_vacancies": GameSession.encounter_vacancies.duplicate(true),
		"used_encounter_template_ids": GameSession._used_encounter_template_ids.duplicate(true),
		"world_turn": GameSession.world_turn,
		"gold": GameSession.gold,
		"guild_hall_level": GameSession.guild_hall_level,
		"blacksmith_level": GameSession.blacksmith_level,
		"blacksmith_craft_job": GameSession.blacksmith_craft_job.duplicate(true),
		"blacksmith_sharpening_job": GameSession.blacksmith_sharpening_job.duplicate(true),
		"pending_reward": GameSession.pending_reward,
		"mana_crystals": GameSession.mana_crystals.duplicate(true),
		"banked_gear": GameSession.banked_gear.duplicate(true),
		"pending_mana_crystals": GameSession.pending_mana_crystals.duplicate(true),
		"pending_gear": GameSession.pending_gear.duplicate(true),
		"battle_reward": GameSession.battle_reward,
		"battle_mana_crystals": GameSession.battle_mana_crystals.duplicate(true),
		"battle_gear": GameSession.battle_gear.duplicate(true),
		"has_trading_post": GameSession.has_trading_post,
		"shop_level": GameSession.shop_level,
		"shop_gold": GameSession.shop_gold,
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


## Task 2 (docs/plans/2026-08-21-stage-2-party-readiness/
## 02-class-progression-and-perks.md): a pre-Stage-2 save may already hold
## the legacy bonus_move perk. Importing it must not migrate/strip it away,
## and -- the actual regression this locks -- must not let it silently
## consume one of the two new class-owned slots either (see _pending_perk_
## slot_count()'s own doc comment): a lone bonus_move save at level 6 still
## earns both of its class's real perks.
func test_importing_a_legacy_lone_bonus_move_save_normalizes_without_granting_an_extra_slot() -> void:
	GameSession.adventurers[0].level = 6
	GameSession.adventurers[0].stats.max_health = 20
	GameSession.adventurers[0].progression.perks = [GameSessionScript.BONUS_MOVE_PERK_ID]
	var snapshot := GameSession.export_campaign_snapshot()
	GameSession.reset()

	var result := GameSession.import_campaign_snapshot(snapshot)

	assert_true(result.ok, result.error)
	var warrior := GameSession.get_adventurer(GameSessionScript.WARRIOR_ID)
	assert_eq(
		warrior.progression.perks, [GameSessionScript.BONUS_MOVE_PERK_ID],
		"The legacy perk is preserved on import, not migrated away"
	)
	assert_true(
		GameSession.is_perk_choice_pending(GameSessionScript.WARRIOR_ID),
		"A lone bonus_move save must still earn both of its class's real perk slots at level 6"
	)
	assert_eq(
		GameSession.get_available_perks(GameSessionScript.WARRIOR_ID),
		[GameSessionScript.WARRIOR_JUGGERNAUT_PERK_ID, GameSessionScript.WARRIOR_BULWARK_PERK_ID],
		"Not just one slot -- bonus_move must not have consumed either of the two new slots"
	)
	assert_true(GameSession.choose_perk(GameSessionScript.WARRIOR_ID, GameSessionScript.WARRIOR_JUGGERNAUT_PERK_ID))
	assert_true(GameSession.choose_perk(GameSessionScript.WARRIOR_ID, GameSessionScript.WARRIOR_BULWARK_PERK_ID))
	assert_false(GameSession.is_perk_choice_pending(GameSessionScript.WARRIOR_ID), "Both real slots are now spent")


## A malformed/foreign perk id must reject the whole import atomically --
## live session state stays exactly as it was before the attempt, same as
## every other reject-atomically snapshot contract test in this file (see
## test_alchemy_snapshot_rejects_more_than_ten_carried_items_without_
## mutating_live_state() for the same pattern).
func test_importing_a_foreign_perk_id_is_rejected_without_mutating_live_state() -> void:
	var snapshot := GameSession.export_campaign_snapshot()
	snapshot.adventurers[0]["level"] = 3
	snapshot.adventurers[0].progression["perks"] = [GameSessionScript.SCOUT_QUICKDRAW_PERK_ID]
	var before := _capture_durable_fields()

	var result := GameSession.import_campaign_snapshot(snapshot)

	assert_false(result.ok)
	assert_string_contains(result.error, "perk")
	assert_eq(_capture_durable_fields(), before)


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
	GameSession.complete_campaign_objective("obj_tier1_1_goblin_outpost")
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
		"GUILD_HALL_LEVEL_3_PARTY_CAP": true,
		"GUILD_HALL_UPGRADE_COST": true,
		"GUILD_HALL_LEVEL_3_UPGRADE_COST": true,
		"GUILD_HALL_MAX_LEVEL": true,
		"GUILD_HALL_LEVEL_1_ROSTER_CAP": true,
		"GUILD_HALL_LEVEL_2_ROSTER_CAP": true,
		"GUILD_HALL_LEVEL_3_ROSTER_CAP": true,
		"GUILD_HALL_LEVEL_2_OFFER_CAP": true,
		"GUILD_HALL_LEVEL_3_OFFER_CAP": true,
		"TEMPLE_BUILD_COST": true,
		"TRADING_POST_PURCHASE_COST": true,
		"TRADING_POST_INCOME_PER_TURN": true,
		"SHOP_INCOME_PER_TURN": true,
		"SHOP_INCOME_LEVEL_2": true,
		"SHOP_INCOME_LEVEL_3": true,
		"SHOP_UPGRADE_COST": true,
		"SHOP_LEVEL_3_UPGRADE_COST": true,
		"EFFECTIVE_HIT_CHANCE_CAP": true,
		"ATTACK_TO_HIT_CHANCE_DIVISOR": true,
		"ENCOUNTER_INSTANCE_CAP": true,
		"RECRUITMENT_OFFER_CAP": true,
		"ENCOUNTER_VACANCY_TURNS": true,
		"RECRUITMENT_VACANCY_TURNS": true,
		"ENCOUNTER_VACANCY_JITTER_TURNS": true,
		"RECRUITMENT_VACANCY_JITTER_TURNS": true,
		"HEAL_RATE_ENCAMPED": true,
		"HEAL_RATE_RESTING": true,
		"HEAL_RATE_MOVING": true,
		"PERK_TREE_SIZE": true,
		"WARRIOR_JUGGERNAUT_HP_PERCENT": true,
		"WARRIOR_BULWARK_GUARD": true,
		"SCOUT_QUICKDRAW_ACTION_POINTS": true,
		"SCOUT_KEEN_EYES_INTEL_RANGE_BONUS": true,
		"CLERIC_MEDITATION_SPELL_RANGE_BONUS": true,
		"CLERIC_DEVOUT_HP_PERCENT": true,
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
	assert_eq(GameSession.adventurers.size(), 4)



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
## is covered above): a Guild Hall or Shop upgrade must
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


func test_campaign_guide_clears_once_the_shop_is_upgraded() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	GameSession.return_deployed_party_to_settlement()
	GameSession.gold = GameSession.SHOP_UPGRADE_COST
	assert_eq(GameSession.get_campaign_guide_state(), GameSession.CAMPAIGN_GUIDE_FIRST_IMPROVEMENT)
	GameSession.record_campaign_guide_progress(GameSession.CAMPAIGN_GUIDE_FIRST_IMPROVEMENT)

	assert_true(GameSession.upgrade_shop())

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


## --- Owned equipment instances ----------------------------------------------

func test_materializing_a_banked_base_item_creates_one_unique_owned_instance() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"longsword_iron": 1}

	assert_true(GameSession.materialize_banked_item_instance("longsword_iron", "gear_00042"))
	assert_eq(GameSession.banked_gear, {"longsword_iron": 0})
	assert_eq(GameSession.owned_item_instances.gear_00042, {
		"id": "gear_00042",
		"base_item_id": "longsword_iron",
		"treatment_id": "",
		"enhancement_id": "",
		"rune_id": "",
		"modifier_tiers": {},
	})
	assert_eq(GameSession.banked_item_instance_ids, ["gear_00042"])


func test_materializing_a_duplicate_instance_id_rejects_without_consuming_the_base_item() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"longsword_iron": 2}

	assert_true(GameSession.materialize_banked_item_instance("longsword_iron", "gear_00042"))
	var instances_before: Dictionary = GameSession.owned_item_instances.duplicate(true)
	var banked_instances_before: Array = GameSession.banked_item_instance_ids.duplicate()

	assert_false(GameSession.materialize_banked_item_instance("longsword_iron", "gear_00042"))
	assert_eq(GameSession.banked_gear, {"longsword_iron": 1})
	assert_eq(GameSession.owned_item_instances, instances_before)
	assert_eq(GameSession.banked_item_instance_ids, banked_instances_before)


func test_an_advanced_modifier_replaces_its_lower_tier_while_other_categories_stack() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"longsword_iron": 1}
	assert_true(GameSession.materialize_banked_item_instance("longsword_iron", "gear_00042"))

	assert_true(GameSession.set_item_instance_modifier("gear_00042", "treatment", "sharpened", 1))
	assert_true(GameSession.set_item_instance_modifier("gear_00042", "enhancement", "accuracy_basic", 1))
	assert_true(GameSession.set_item_instance_modifier("gear_00042", "enhancement", "accuracy_advanced", 2))

	var instance: Dictionary = GameSession.owned_item_instances.gear_00042
	assert_eq(instance.treatment_id, "sharpened")
	assert_eq(instance.enhancement_id, "accuracy_advanced")
	assert_eq(instance.modifier_tiers, {"treatment": 1, "enhancement": 2})


func test_a_lower_modifier_tier_is_rejected_without_mutating_the_owned_instance() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"longsword_iron": 1}
	assert_true(GameSession.materialize_banked_item_instance("longsword_iron", "gear_00042"))
	assert_true(GameSession.set_item_instance_modifier("gear_00042", "enhancement", "accuracy_advanced", 2))
	var before: Dictionary = GameSession.owned_item_instances.gear_00042.duplicate(true)

	assert_false(GameSession.set_item_instance_modifier("gear_00042", "enhancement", "accuracy_basic", 1))
	assert_eq(GameSession.owned_item_instances.gear_00042, before)


func test_an_owned_instance_transfers_from_stores_to_an_adventurer_and_can_be_reactivated() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"dagger_iron": 1}
	assert_true(GameSession.materialize_banked_item_instance("dagger_iron", "gear_00042"))

	assert_true(GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "gear_00042"))
	var equipment: Dictionary = GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment
	assert_eq(equipment.weapon, "gear_00042")
	assert_eq(equipment.weapon_inventory, [GameSession.DEFAULT_WEAPON_ID, "gear_00042"])
	assert_eq(GameSession.banked_item_instance_ids, [])
	assert_eq(GameSession.get_effective_weapon_damage_range(GameSession.WARRIOR_ID), Vector2i(1, 4))
	assert_true(GameSession.activate_carried_item(GameSession.WARRIOR_ID, "weapon", GameSession.DEFAULT_WEAPON_ID))
	assert_true(GameSession.activate_carried_item(GameSession.WARRIOR_ID, "weapon", "gear_00042"))
	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.weapon, "gear_00042")


func test_owned_instances_survive_a_campaign_snapshot_round_trip_without_aliasing() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"dagger_iron": 1}
	assert_true(GameSession.materialize_banked_item_instance("dagger_iron", "gear_00042"))
	assert_true(GameSession.set_item_instance_modifier("gear_00042", "treatment", "sharpened", 1))
	var snapshot := GameSession.export_campaign_snapshot()
	GameSession.reset()

	assert_true(GameSession.import_campaign_snapshot(snapshot).ok)
	assert_eq(GameSession.owned_item_instances.gear_00042.treatment_id, "sharpened")
	assert_eq(GameSession.banked_item_instance_ids, ["gear_00042"])
	snapshot.owned_item_instances.gear_00042.treatment_id = "mutated"
	assert_eq(GameSession.owned_item_instances.gear_00042.treatment_id, "sharpened")


func test_selling_a_banked_owned_instance_removes_its_record_exactly_once() -> void:
	GameSession.reset()
	GameSession.has_trading_post = true
	GameSession.banked_gear = {"dagger_iron": 1}
	assert_true(GameSession.materialize_banked_item_instance("dagger_iron", "gear_00042"))

	assert_true(GameSession.sell_item("gear_00042"))
	assert_eq(GameSession.gold, 5)
	assert_false(GameSession.owned_item_instances.has("gear_00042"))
	assert_eq(GameSession.banked_item_instance_ids, [])
	assert_false(GameSession.sell_item("gear_00042"))
	assert_eq(GameSession.gold, 5)


func test_import_rejects_an_owned_instance_in_two_locations_without_mutating_live_state() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"dagger_iron": 1}
	assert_true(GameSession.materialize_banked_item_instance("dagger_iron", "gear_00042"))
	var snapshot := GameSession.export_campaign_snapshot()
	snapshot.adventurers[0].equipment.weapon_inventory.append("gear_00042")
	var before := _capture_durable_fields()

	var result := GameSession.import_campaign_snapshot(snapshot)

	assert_false(result.ok)
	assert_string_contains(result.error, "owned item instance")
	assert_eq(_capture_durable_fields(), before)


func test_buying_an_owned_instance_id_is_rejected_without_creating_a_stack_entry() -> void:
	GameSession.reset()
	GameSession.has_trading_post = true
	GameSession.gold = 10
	GameSession.banked_gear = {"dagger_iron": 1}
	assert_true(GameSession.materialize_banked_item_instance("dagger_iron", "gear_00042"))

	assert_false(GameSession.buy_item("gear_00042"))
	assert_eq(GameSession.gold, 10)
	assert_eq(GameSession.banked_gear, {"dagger_iron": 0})
	assert_eq(GameSession.banked_item_instance_ids, ["gear_00042"])


func test_import_rejects_an_active_owned_instance_pointer_missing_from_its_inventory() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"dagger_iron": 1}
	assert_true(GameSession.materialize_banked_item_instance("dagger_iron", "gear_00042"))
	var snapshot := GameSession.export_campaign_snapshot()
	snapshot.adventurers[0].equipment.weapon = "gear_00042"
	var before := _capture_durable_fields()

	var result := GameSession.import_campaign_snapshot(snapshot)

	assert_false(result.ok)
	assert_string_contains(result.error, "active owned item instance")
	assert_eq(_capture_durable_fields(), before)


func test_import_rejects_an_owned_instance_with_malformed_modifier_data() -> void:
	GameSession.reset()
	GameSession.banked_gear = {"dagger_iron": 1}
	assert_true(GameSession.materialize_banked_item_instance("dagger_iron", "gear_00042"))
	var snapshot := GameSession.export_campaign_snapshot()
	snapshot.owned_item_instances.gear_00042.modifier_tiers = "not a dictionary"
	var before := _capture_durable_fields()

	var result := GameSession.import_campaign_snapshot(snapshot)

	assert_false(result.ok)
	assert_string_contains(result.error, "modifier tiers")
	assert_eq(_capture_durable_fields(), before)


func test_tier_1_encounter_completion_reward_averages_25_gold() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(min_val: int, max_val: int) -> int: return (min_val + max_val) / 2
	session.enter_encounter(GameSessionScript.GOBLIN_CAMP_ID)

	session.complete_current_encounter()

	# 20 base completion bonus (difficulty 1 * ~20) + 3 kill loot = 23 gold
	assert_between(session.battle_reward, 22, 26, "Tier 1 encounter reward should average ~25 gold")


func test_tier_2_encounter_completion_reward_averages_50_gold() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(min_val: int, max_val: int) -> int: return (min_val + max_val) / 2
	session.enter_encounter(GameSessionScript.ORC_OUTPOST_ID)

	session.complete_current_encounter()

	# 40 base completion bonus (difficulty 2 * ~20) + 6 kill loot = 46 gold
	assert_between(session.battle_reward, 44, 52, "Tier 2 encounter reward should average ~50 gold")

