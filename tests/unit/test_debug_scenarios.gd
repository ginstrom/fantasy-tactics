extends GutTest

const DebugScenarios := preload("res://scripts/debug/debug_scenarios.gd")


func before_each() -> void:
	GameSession.reset()


func test_party_ready_creates_a_staffed_undeployed_party() -> void:
	assert_true(DebugScenarios.apply("party_ready"))
	assert_false(GameSession.has_deployed_party())
	assert_eq(GameSession.get_selected_party().member_ids, [GameSession.WARRIOR_ID])


func test_world_map_creates_a_deployed_party_away_from_settlement() -> void:
	assert_true(DebugScenarios.apply("world_map"))
	assert_true(GameSession.has_deployed_party())
	assert_eq(GameSession.get_deployed_party_position(), Vector2i(1, 0))


func test_goblin_camp_creates_a_staffed_deployed_party_at_the_camp() -> void:
	assert_true(DebugScenarios.apply("goblin_camp"))
	assert_true(GameSession.has_deployed_party())
	assert_eq(GameSession.get_selected_party().member_ids, [GameSession.WARRIOR_ID])
	assert_eq(GameSession.get_deployed_party_position(), Vector2i(4, 4))
	assert_eq(GameSession.selected_encounter, "")


func test_unknown_scenario_fails_after_reset_without_creating_a_party() -> void:
	assert_false(DebugScenarios.apply("unknown"))
	assert_eq(GameSession.parties, [])


func test_scenario_ids_are_in_display_order() -> void:
	assert_eq(DebugScenarios.scenario_ids(), [
		"new_campaign",
		"encampment",
		"party_manager",
		"party_ready",
		"world_map",
		"goblin_camp",
	])
