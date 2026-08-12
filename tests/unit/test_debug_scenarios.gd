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
	assert_eq(
		GameSession.get_deployed_party_position(),
		GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position,
		"The scenario must deploy to the catalog's position, not a second hardcoded source of truth"
	)
	assert_eq(GameSession.selected_encounter, "")


func test_orc_outpost_creates_a_staffed_deployed_party_at_the_outpost() -> void:
	assert_true(DebugScenarios.apply("orc_outpost"))
	assert_true(GameSession.has_deployed_party())
	assert_eq(GameSession.get_selected_party().member_ids, [GameSession.WARRIOR_ID])
	assert_eq(
		GameSession.get_deployed_party_position(),
		GameSession.get_expedition(GameSession.ORC_OUTPOST_ID).position
	)
	assert_eq(GameSession.selected_encounter, "")


func test_unknown_scenario_fails_after_reset_without_creating_a_party() -> void:
	assert_false(DebugScenarios.apply("unknown"))
	assert_eq(GameSession.parties, [])


func test_stocked_stores_creates_a_staffed_party_with_a_trading_post_and_banked_items() -> void:
	assert_true(DebugScenarios.apply("stocked_stores"))
	assert_eq(GameSession.get_selected_party().member_ids, [GameSession.WARRIOR_ID])
	assert_true(GameSession.has_trading_post)
	assert_eq(GameSession.mana_crystals, {1: 2})
	assert_eq(GameSession.banked_gear, {"shortsword_iron": 1})
	assert_eq(GameSession.gold, 500, "Enough gold to actually buy something from the Shop")


func test_scenario_ids_are_in_display_order() -> void:
	assert_eq(DebugScenarios.scenario_ids(), [
		"new_campaign",
		"encampment",
		"party_manager",
		"party_ready",
		"party_empty",
		"world_map",
		"goblin_camp",
		"orc_outpost",
		"ruined_fortress",
		"stocked_stores",
	])


func test_party_empty_creates_an_encamped_party_with_no_members() -> void:
	assert_true(DebugScenarios.apply("party_empty"))
	assert_false(GameSession.has_deployed_party())
	assert_eq(GameSession.get_selected_party().member_ids, [] as Array[String])
