extends GutTest

const DebugScenarios := preload("res://scripts/debug/debug_scenarios.gd")


func before_each() -> void:
	GameSession.reset()
	DebugScenarios.load_scenarios()


## --- Canonical campaign snapshot fixtures (Step 2) -------------------------
##
## Each baseline scenario's campaign_snapshot in config/debug_scenarios.json
## is the literal GameSession.export_campaign_snapshot() output captured
## once from that scenario's established baseline state (see docs/plans/
## 2026-08-16-debug-menu-json-config/index.md's "Manifest contract"). apply()
## must import that fixture through GameSession.import_campaign_snapshot()
## unchanged, so a fresh export right after apply() must match the shipped
## fixture exactly -- proving apply() neither mutates the fixture on the way
## in nor leaves any stale field from a prior GameSession state behind.


func _assert_fixture_round_trips(scenario_id: String) -> void:
	var scenario := DebugScenarios.get_scenario(scenario_id)
	assert_false(scenario.is_empty(), "scenario %s must be in the shipped manifest" % scenario_id)

	var result := DebugScenarios.apply(scenario_id)

	assert_true(result.ok, "scenario %s should apply cleanly: %s" % [scenario_id, result.errors])
	assert_eq(
		GameSession.export_campaign_snapshot(), scenario.campaign_snapshot,
		"scenario %s's live state should match its manifest fixture exactly" % scenario_id
	)


func test_new_campaign_fixture_round_trips_through_apply_and_export() -> void:
	_assert_fixture_round_trips("new_campaign")


func test_encampment_fixture_round_trips_through_apply_and_export() -> void:
	_assert_fixture_round_trips("encampment")


func test_party_manager_fixture_round_trips_through_apply_and_export() -> void:
	_assert_fixture_round_trips("party_manager")


func test_party_ready_fixture_round_trips_through_apply_and_export() -> void:
	_assert_fixture_round_trips("party_ready")
	assert_false(GameSession.has_deployed_party())
	assert_eq(GameSession.get_selected_party().member_ids, [GameSession.WARRIOR_ID])


func test_party_empty_fixture_round_trips_through_apply_and_export() -> void:
	_assert_fixture_round_trips("party_empty")
	assert_false(GameSession.has_deployed_party())
	assert_eq(GameSession.get_selected_party().member_ids, [] as Array[String])


func test_world_map_fixture_round_trips_through_apply_and_export() -> void:
	_assert_fixture_round_trips("world_map")
	assert_true(GameSession.has_deployed_party())
	assert_eq(GameSession.get_deployed_party_position(), Vector2i(1, 0))


func test_goblin_camp_fixture_round_trips_through_apply_and_export() -> void:
	_assert_fixture_round_trips("goblin_camp")
	assert_true(GameSession.has_deployed_party())
	assert_eq(GameSession.get_selected_party().member_ids, [GameSession.WARRIOR_ID])
	assert_eq(
		GameSession.get_deployed_party_position(),
		GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position,
		"The fixture must deploy to the catalog's position, not a second hardcoded source of truth"
	)
	# Set by the fixture itself (see Step 3's side-effect-free debug launch:
	# the dispatcher never calls GameSession.enter_encounter(), so a
	# battlefield scenario's selected_encounter must already be baked in).
	assert_eq(GameSession.selected_encounter, GameSession.GOBLIN_CAMP_ID)


## Unlike the old field-by-field DebugScenarios.apply(), this scenario's
## fixture cannot pin GameSession.enemy_composition_roll/enemy_count_roll --
## Callables have no JSON representation, and the manifest contract
## deliberately excludes direct GameSession battle overrides (see docs/
## plans/2026-08-16-debug-menu-json-config/index.md's "Architecture and
## scope"). So the fixture's active_encounters preview reflects whatever
## composition/count real randomness rolled when it was captured -- assert
## the encounter instance exists at the outpost's position and let
## _assert_fixture_round_trips cover its exact captured composition; do not
## call GameSession.enter_encounter() here, which would re-roll it live.
func test_orc_outpost_fixture_round_trips_through_apply_and_export() -> void:
	_assert_fixture_round_trips("orc_outpost")
	assert_true(GameSession.has_deployed_party())
	assert_eq(GameSession.get_selected_party().member_ids.size(), 4, "Orc Outpost scenario deploys 4 warriors")
	assert_eq(
		GameSession.get_deployed_party_position(),
		GameSession.get_expedition(GameSession.ORC_OUTPOST_ID).position
	)
	# Set by the fixture itself -- see the sibling assertion in
	# test_goblin_camp_fixture_round_trips_through_apply_and_export().
	assert_eq(GameSession.selected_encounter, GameSession.ORC_OUTPOST_ID)

	var has_outpost_encounter := false
	for enc in GameSession.get_active_encounters():
		if enc.template_id == GameSession.ORC_OUTPOST_ID:
			has_outpost_encounter = true
			break
	assert_true(has_outpost_encounter, "the Orc Outpost encounter should be active at import")


## See test_orc_outpost_fixture_round_trips_through_apply_and_export()'s own
## comment: the fixture's captured Kobold count is whatever real randomness
## rolled at generation time, not a guaranteed maximum -- that guarantee
## required pinning GameSession's roll Callables, which the manifest
## contract deliberately excludes.
func test_ruined_fortress_fixture_round_trips_through_apply_and_export() -> void:
	_assert_fixture_round_trips("ruined_fortress")
	assert_eq(GameSession.get_selected_party().member_ids.size(), 3, "Ruined Fortress fixture fields three Warriors")

	var has_fortress_encounter := false
	for enc in GameSession.get_active_encounters():
		if enc.template_id == GameSession.RUINED_FORTRESS_ID:
			has_fortress_encounter = true
			break
	assert_true(has_fortress_encounter, "the Ruined Fortress encounter should be active at import")


func test_stocked_stores_fixture_round_trips_through_apply_and_export() -> void:
	_assert_fixture_round_trips("stocked_stores")
	assert_eq(GameSession.get_selected_party().member_ids, [GameSession.WARRIOR_ID])
	assert_true(GameSession.has_trading_post)
	assert_eq(GameSession.mana_crystals, {1: 2})
	assert_eq(GameSession.banked_gear, {"shortsword_iron": 1})
	assert_eq(GameSession.gold, 500, "Enough gold to actually buy something from the Shop")


## Display order is a manifest/loader concern (see Step 1's
## test_load_scenarios_preserves_source_order); this test only pins the
## established real-manifest order so a reordering in config/
## debug_scenarios.json is a deliberate, visible change.
func test_scenarios_are_in_the_established_display_order() -> void:
	var ids: Array = []
	for scenario in DebugScenarios.get_all_scenarios():
		ids.append(scenario.id)
	assert_eq(ids, [
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


## --- apply() failure paths leave GameSession untouched (Step 2) -----------


func test_apply_with_an_unknown_scenario_id_leaves_gamesession_untouched() -> void:
	assert_true(DebugScenarios.apply("party_ready").ok)
	var before := GameSession.export_campaign_snapshot()

	var result := DebugScenarios.apply("unknown")

	assert_false(result.ok)
	assert_true(result.errors.size() > 0)
	assert_eq(GameSession.export_campaign_snapshot(), before)


func test_apply_with_an_invalid_embedded_snapshot_leaves_gamesession_untouched() -> void:
	assert_true(DebugScenarios.apply("party_ready").ok)
	var before := GameSession.export_campaign_snapshot()

	_write_manifest({
		"manifest_version": 1,
		"scenarios": [
			{
				"id": "broken",
				"name_key": "debug.broken",
				"category": "Campaign",
				"description": "A scenario with an invalid embedded snapshot.",
				"launch": {"scene": "encampment"},
				"campaign_snapshot": {"version": 1},
			},
		],
	})
	assert_true(DebugScenarios.load_scenarios(TEST_MANIFEST_PATH).ok)

	var result := DebugScenarios.apply("broken")

	assert_false(result.ok)
	assert_true(result.errors.size() > 0)
	assert_eq(GameSession.export_campaign_snapshot(), before)


## --- Versioned debug manifest loader (Step 1) -----------------------------
##
## Every test here writes its own manifest to TEST_MANIFEST_PATH under
## user:// (the same test-injectable-path convention test_save_repository.gd
## establishes) rather than editing config/debug_scenarios.json directly. A
## couple of Step 2's apply()-failure tests load that throwaway manifest,
## which replaces DebugScenarios' shared static cache for the rest of the
## suite -- after_each() always reloads the real manifest afterward so no
## test here can leak a synthetic scenario list into another test file.

const TEST_MANIFEST_PATH := "user://test_debug_scenarios_manifest.json"


func after_each() -> void:
	if FileAccess.file_exists(TEST_MANIFEST_PATH):
		DirAccess.remove_absolute(TEST_MANIFEST_PATH)
	DebugScenarios.load_scenarios()


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


## --- Shipped manifest regression evidence (Step 5) -------------------------
##
## Unlike every test above (which exercises the loader/importer against
## synthetic, test-injected manifests), these prove the real, checked-in
## config/debug_scenarios.json is authored correctly end-to-end -- the
## "documentation-oriented tests" docs/plans/2026-08-16-debug-menu-json-
## config/step-5-documentation-and-verification.md asks for.


func test_the_shipped_manifest_parses() -> void:
	var result := DebugScenarios.load_scenarios()

	assert_true(result.ok, "config/debug_scenarios.json should parse and validate: %s" % [result.errors])


func test_every_shipped_scenario_name_key_resolves_to_translated_text() -> void:
	for scenario in DebugScenarios.get_all_scenarios():
		var name_key: String = scenario.name_key
		assert_ne(
			tr(name_key), name_key,
			"scenario %s's name_key '%s' has no translations/en.tres entry" % [scenario.id, name_key]
		)


func test_every_shipped_fixture_passes_canonical_snapshot_import_validation() -> void:
	for scenario in DebugScenarios.get_all_scenarios():
		var result := DebugScenarios.apply(scenario.id)
		assert_true(result.ok, "scenario %s's fixture should import cleanly: %s" % [scenario.id, result.errors])


## --- Debug-scenario loot regression (Step 4: fix-debug-scenario-loot-
## regression) --------------------------------------------------------------
##
## Every active_encounters[].enemy entry in config/debug_scenarios.json was
## captured from the static EXPEDITIONS template stub (game_session.gd's
## EXPEDITIONS, not a resolved STAR_ENEMY_COMPOSITIONS entry), so none of
## them ever carried a loot_id. GameSession._roll_and_queue_loot() silently
## no-ops without one, so a debug-scenario victory queued no gold, gear, or
## mana crystals at all -- confirmed live via FN+F9 -> Goblin Camp Battle.
## The two tests below lock the fix: one enforces the fixture invariant
## across every shipped scenario so it can't silently regress, the other
## reproduces the exact bug end-to-end through the same
## complete_current_encounter() call battlefield.gd's victory handler makes.


func test_every_shipped_active_encounter_enemy_has_a_valid_loot_id() -> void:
	for scenario in DebugScenarios.get_all_scenarios():
		var active_encounters: Array = scenario.campaign_snapshot.get("active_encounters", [])
		for encounter in active_encounters:
			var enemy: Dictionary = encounter.get("enemy", {})
			var loot_id: String = enemy.get("loot_id", "")
			assert_true(
				GameSession.ENEMY_LOOT_TABLES.has(loot_id),
				(
					"scenario %s's %s encounter enemy must declare a loot_id present in ENEMY_LOOT_TABLES, got '%s'"
					% [scenario.id, encounter.get("template_id", "?"), loot_id]
				)
			)


func test_completing_the_goblin_camp_debug_scenario_queues_gold_and_a_mana_crystal() -> void:
	DebugScenarios.apply("goblin_camp")

	GameSession.complete_current_encounter()

	assert_eq(
		GameSession.battle_mana_crystals, {1: 1},
		"Goblin's mana_crystal_tier is 1 and the fixture fields exactly one goblin"
	)
	assert_true(
		GameSession.battle_reward > 0,
		"Completing the encounter should queue gold from the goblin's loot table"
	)
