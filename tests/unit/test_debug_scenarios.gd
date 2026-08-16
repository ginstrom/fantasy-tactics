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
	assert_eq(GameSession.get_selected_party().member_ids.size(), 4, "Orc Outpost scenario deploys 4 warriors")
	assert_eq(
		GameSession.get_deployed_party_position(),
		GameSession.get_expedition(GameSession.ORC_OUTPOST_ID).position
	)
	assert_eq(GameSession.selected_encounter, "")

	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var encounter: Dictionary = {}
	for enc in GameSession.get_active_encounters():
		if enc.template_id == GameSession.ORC_OUTPOST_ID:
			encounter = enc
			break
	assert_eq(encounter.enemy.count, 2, "Orc Outpost scenario fields 2 orcs")
	assert_eq(encounter.enemy.name_key, "battle.enemy.orc")







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


## --- Versioned debug manifest loader (Step 1) -----------------------------
##
## These scenarios never touch config/debug_scenarios.json -- every test
## writes its own manifest to TEST_MANIFEST_PATH under user:// (the same
## test-injectable-path convention test_save_repository.gd establishes) so a
## bad manifest here can never corrupt another test's shared cache.

const TEST_MANIFEST_PATH := "user://test_debug_scenarios_manifest.json"


func after_each() -> void:
	if FileAccess.file_exists(TEST_MANIFEST_PATH):
		DirAccess.remove_absolute(TEST_MANIFEST_PATH)


func _write_manifest(data: Dictionary) -> void:
	var file := FileAccess.open(TEST_MANIFEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _valid_manifest(scenarios: Array = []) -> Dictionary:
	if scenarios.is_empty():
		scenarios = [
			{
				"id": "alpha",
				"name_key": "debug.alpha",
				"category": "Campaign",
				"description": "First scenario.",
				"launch": {"scene": "encampment"},
				"campaign_snapshot": {"version": 1},
			},
			{
				"id": "beta",
				"name_key": "debug.beta",
				"category": "Battle",
				"description": "Second scenario.",
				"launch": {"scene": "battlefield"},
				"campaign_snapshot": {"version": 1},
			},
		]
	return {"manifest_version": 1, "scenarios": scenarios}


func test_load_scenarios_preserves_source_order() -> void:
	_write_manifest(_valid_manifest())

	var result := DebugScenarios.load_scenarios(TEST_MANIFEST_PATH)

	assert_true(result.ok)
	assert_eq(result.errors, [])
	var ids: Array = []
	for scenario in DebugScenarios.get_all_scenarios():
		ids.append(scenario.id)
	assert_eq(ids, ["alpha", "beta"])


func test_load_scenarios_rejects_unsupported_manifest_version() -> void:
	var manifest := _valid_manifest()
	manifest.manifest_version = 2
	_write_manifest(manifest)

	var result := DebugScenarios.load_scenarios(TEST_MANIFEST_PATH)

	assert_false(result.ok)
	assert_true(result.errors.size() > 0)


func test_load_scenarios_rejects_duplicate_ids() -> void:
	var scenarios: Array = _valid_manifest().scenarios
	scenarios[1].id = "alpha"
	_write_manifest({"manifest_version": 1, "scenarios": scenarios})

	assert_false(DebugScenarios.load_scenarios(TEST_MANIFEST_PATH).ok)


func test_load_scenarios_rejects_empty_id() -> void:
	var scenarios: Array = _valid_manifest().scenarios
	scenarios[0].id = ""
	_write_manifest({"manifest_version": 1, "scenarios": scenarios})

	assert_false(DebugScenarios.load_scenarios(TEST_MANIFEST_PATH).ok)


func test_load_scenarios_rejects_non_string_name_key() -> void:
	var scenarios: Array = _valid_manifest().scenarios
	scenarios[0].name_key = 5
	_write_manifest({"manifest_version": 1, "scenarios": scenarios})

	assert_false(DebugScenarios.load_scenarios(TEST_MANIFEST_PATH).ok)


func test_load_scenarios_rejects_non_string_category() -> void:
	var scenarios: Array = _valid_manifest().scenarios
	scenarios[0].category = 5
	_write_manifest({"manifest_version": 1, "scenarios": scenarios})

	assert_false(DebugScenarios.load_scenarios(TEST_MANIFEST_PATH).ok)


func test_load_scenarios_rejects_an_invalid_launch_scene() -> void:
	var scenarios: Array = _valid_manifest().scenarios
	scenarios[0].launch = {"scene": "not_a_real_scene"}
	_write_manifest({"manifest_version": 1, "scenarios": scenarios})

	assert_false(DebugScenarios.load_scenarios(TEST_MANIFEST_PATH).ok)


func test_load_scenarios_rejects_a_missing_campaign_snapshot() -> void:
	var scenarios: Array = _valid_manifest().scenarios
	scenarios[0].erase("campaign_snapshot")
	_write_manifest({"manifest_version": 1, "scenarios": scenarios})

	assert_false(DebugScenarios.load_scenarios(TEST_MANIFEST_PATH).ok)


func test_load_scenarios_rejects_a_non_dictionary_campaign_snapshot() -> void:
	var scenarios: Array = _valid_manifest().scenarios
	scenarios[0].campaign_snapshot = "not a dictionary"
	_write_manifest({"manifest_version": 1, "scenarios": scenarios})

	assert_false(DebugScenarios.load_scenarios(TEST_MANIFEST_PATH).ok)


func test_load_scenarios_reports_every_validation_error_in_one_pass() -> void:
	var scenarios: Array = _valid_manifest().scenarios
	scenarios[0].name_key = 5
	scenarios[1].category = 7
	_write_manifest({"manifest_version": 1, "scenarios": scenarios})

	var result := DebugScenarios.load_scenarios(TEST_MANIFEST_PATH)

	assert_false(result.ok)
	assert_eq(result.errors.size(), 2, "Both invalid entries should be reported, not just the first")


func test_reload_with_invalid_json_preserves_the_previous_cache_and_reports_diagnostics() -> void:
	_write_manifest(_valid_manifest())
	assert_true(DebugScenarios.load_scenarios(TEST_MANIFEST_PATH).ok)
	var before := DebugScenarios.get_all_scenarios()

	var file := FileAccess.open(TEST_MANIFEST_PATH, FileAccess.WRITE)
	file.store_string("{not valid json")
	file.close()
	var result := DebugScenarios.load_scenarios(TEST_MANIFEST_PATH)

	assert_false(result.ok)
	assert_true(result.errors.size() > 0)
	assert_eq(DebugScenarios.get_all_scenarios(), before)


func test_reload_with_a_missing_file_preserves_the_previous_cache_and_reports_diagnostics() -> void:
	_write_manifest(_valid_manifest())
	assert_true(DebugScenarios.load_scenarios(TEST_MANIFEST_PATH).ok)
	var before := DebugScenarios.get_all_scenarios()

	var result := DebugScenarios.load_scenarios("user://test_debug_scenarios_missing_manifest.json")

	assert_false(result.ok)
	assert_true(result.errors.size() > 0)
	assert_eq(DebugScenarios.get_all_scenarios(), before)


func test_reload_with_one_invalid_entry_preserves_the_previous_cache_and_reports_diagnostics() -> void:
	_write_manifest(_valid_manifest())
	assert_true(DebugScenarios.load_scenarios(TEST_MANIFEST_PATH).ok)
	var before := DebugScenarios.get_all_scenarios()

	var scenarios: Array = _valid_manifest().scenarios
	scenarios[1].launch = {"scene": "not_a_real_scene"}
	_write_manifest({"manifest_version": 1, "scenarios": scenarios})
	var result := DebugScenarios.load_scenarios(TEST_MANIFEST_PATH)

	assert_false(result.ok)
	assert_true(result.errors.size() > 0)
	assert_eq(DebugScenarios.get_all_scenarios(), before)


func test_get_scenario_returns_a_copy_callers_cannot_use_to_mutate_the_cache() -> void:
	_write_manifest(_valid_manifest())
	DebugScenarios.load_scenarios(TEST_MANIFEST_PATH)

	var scenario := DebugScenarios.get_scenario("alpha")
	scenario.category = "Mutated"
	scenario.campaign_snapshot["version"] = 999

	var fresh := DebugScenarios.get_scenario("alpha")
	assert_eq(fresh.category, "Campaign")
	assert_eq(fresh.campaign_snapshot.version, 1)


func test_get_scenario_returns_empty_dictionary_for_an_unknown_id() -> void:
	_write_manifest(_valid_manifest())
	DebugScenarios.load_scenarios(TEST_MANIFEST_PATH)

	assert_eq(DebugScenarios.get_scenario("unknown"), {})


func test_get_scenarios_by_category_groups_in_source_order() -> void:
	_write_manifest(_valid_manifest([
		{"id": "a", "name_key": "debug.a", "category": "Battle", "description": "", "launch": {"scene": "battlefield"}, "campaign_snapshot": {}},
		{"id": "b", "name_key": "debug.b", "category": "Campaign", "description": "", "launch": {"scene": "encampment"}, "campaign_snapshot": {}},
		{"id": "c", "name_key": "debug.c", "category": "Battle", "description": "", "launch": {"scene": "battlefield"}, "campaign_snapshot": {}},
	]))

	DebugScenarios.load_scenarios(TEST_MANIFEST_PATH)
	var grouped := DebugScenarios.get_scenarios_by_category()

	assert_eq(grouped.size(), 2)
	assert_eq(grouped[0].category, "Battle")
	assert_eq(grouped[0].scenarios.size(), 2)
	assert_eq(grouped[1].category, "Campaign")
	assert_eq(grouped[1].scenarios.size(), 1)
