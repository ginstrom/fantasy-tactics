extends GutTest
## Covers scripts/tools/battle_scenarios/scenario_expander.gd: deterministic
## expansion of a raw scenario's optional `matrix` of named axes into
## individually identified, normalized, validated concrete cases. See
## docs/plans/2026-08-10-initial-campaign-and-automation/
## 05-battle-scenario-contract.md.

const ScenarioExpander := preload("res://scripts/tools/battle_scenarios/scenario_expander.gd")
const ScenarioContract := preload("res://scripts/tools/battle_scenarios/scenario_contract.gd")


func before_each() -> void:
	GameSession.reset()


func _base_scenario() -> Dictionary:
	return {
		"scenario_id": "matrix_scenario",
		"player": {"template_id": "warrior", "count": 1},
		"enemy": {"template_id": "goblin", "count": 1},
	}


## --- Single-case pass-through (no matrix) -----------------------------------

func test_expand_with_no_matrix_returns_exactly_one_case() -> void:
	var cases := ScenarioExpander.expand(_base_scenario())

	assert_eq(cases.size(), 1)
	assert_eq(cases[0].case_id, "matrix_scenario")
	assert_eq(cases[0].errors, [])
	assert_eq(cases[0].scenario, ScenarioContract.normalize(_base_scenario()))


func test_expand_with_no_matrix_derives_one_iteration_seed_per_iteration() -> void:
	var raw := _base_scenario()
	raw.randomness = {"root_seed": 7, "iterations": 3}

	var cases := ScenarioExpander.expand(raw)

	assert_eq(cases[0].iteration_seeds.size(), 3)
	for i in 3:
		assert_eq(cases[0].iteration_seeds[i], ScenarioContract.derive_iteration_seed(7, "matrix_scenario", i))


## --- Named-axis expansion ----------------------------------------------------

func test_expand_a_single_axis_produces_one_case_per_level() -> void:
	var raw := _base_scenario()
	raw.matrix = {
		"party_size": [
			{"value": 1, "overrides": {"player": {"template_id": "warrior", "count": 1}}},
			{"value": 2, "overrides": {"player": {"template_id": "warrior", "count": 2}}},
		],
	}

	var cases := ScenarioExpander.expand(raw)

	assert_eq(cases.size(), 2)
	assert_eq(cases[0].case_id, "matrix_scenario__party_size=1")
	assert_eq(cases[0].scenario.player.units.size(), 1)
	assert_eq(cases[1].case_id, "matrix_scenario__party_size=2")
	assert_eq(cases[1].scenario.player.units.size(), 2)


func test_expand_multiple_axes_produces_the_cross_product_sorted_by_axis_name() -> void:
	var raw := _base_scenario()
	# Declared out of alphabetical order on purpose: "party_size" sorts after
	# "monster", so case ids must reorder axes into "monster=..." first
	# regardless of key declaration order in the source Dictionary.
	raw.matrix = {
		"party_size": [
			{"value": 1, "overrides": {"player": {"template_id": "warrior", "count": 1}}},
			{"value": 2, "overrides": {"player": {"template_id": "warrior", "count": 2}}},
		],
		"monster": [
			{"value": "goblin", "overrides": {"enemy": {"template_id": "goblin", "count": 1}}},
			{"value": "orc", "overrides": {"enemy": {"template_id": "orc", "count": 1}}},
		],
	}

	var cases := ScenarioExpander.expand(raw)
	var case_ids: Array = []
	for c in cases:
		case_ids.append(c.case_id)

	assert_eq(cases.size(), 4, "2 party_size levels x 2 monster levels = 4 cases")
	assert_eq(
		case_ids,
		[
			"matrix_scenario__monster=goblin,party_size=1",
			"matrix_scenario__monster=goblin,party_size=2",
			"matrix_scenario__monster=orc,party_size=1",
			"matrix_scenario__monster=orc,party_size=2",
		],
	)


func test_expand_records_the_axis_values_actually_applied_to_each_case() -> void:
	var raw := _base_scenario()
	raw.matrix = {
		"party_size": [
			{"value": 1, "overrides": {"player": {"template_id": "warrior", "count": 1}}},
			{"value": 2, "overrides": {"player": {"template_id": "warrior", "count": 2}}},
		],
	}

	var cases := ScenarioExpander.expand(raw)

	assert_eq(cases[0].axis_values, {"party_size": 1})
	assert_eq(cases[1].axis_values, {"party_size": 2})


func test_expand_overrides_only_the_targeted_field_and_keeps_the_rest_of_the_base() -> void:
	var raw := _base_scenario()
	raw.rules = {"round_limit": 5}
	raw.matrix = {
		"party_size": [
			{"value": 1, "overrides": {"player": {"template_id": "warrior", "count": 1}}},
		],
	}

	var cases := ScenarioExpander.expand(raw)

	assert_eq(cases[0].scenario.rules.round_limit, 5, "Fields untouched by any axis override must survive expansion")


## --- Reproducibility ----------------------------------------------------------

func test_expand_is_reproducible_across_repeated_calls_with_identical_input() -> void:
	var raw := _base_scenario()
	raw.randomness = {"root_seed": 99, "iterations": 2}
	raw.matrix = {
		"party_size": [
			{"value": 1, "overrides": {"player": {"template_id": "warrior", "count": 1}}},
			{"value": 2, "overrides": {"player": {"template_id": "warrior", "count": 2}}},
		],
	}

	var first_run := ScenarioExpander.expand(raw)
	var second_run := ScenarioExpander.expand(raw)

	assert_eq(first_run, second_run, "Expanding the same raw scenario twice must produce identical cases and seeds")


## --- Pre-construction failure surfaces, does not crash or silently drop ------

func test_expand_surfaces_validation_errors_on_the_offending_case_without_dropping_it() -> void:
	var raw := _base_scenario()
	raw.enemy = {"template_id": "goblin", "count": 999}

	var cases := ScenarioExpander.expand(raw)

	assert_eq(cases.size(), 1, "An invalid case must still be returned, not silently dropped")
	assert_true(cases[0].errors.size() > 0, "The invalid case must carry its validation errors")
	var has_unsupported_count := false
	for error in cases[0].errors:
		if String(error).begins_with("unsupported_count"):
			has_unsupported_count = true
	assert_true(has_unsupported_count)
	assert_eq(cases[0].iteration_seeds, [], "An invalid case must not carry misleading iteration seeds")


func test_expand_flags_a_case_id_collision_caused_by_duplicate_axis_values() -> void:
	var raw := _base_scenario()
	raw.matrix = {
		"party_size": [
			{"value": 1, "overrides": {"player": {"template_id": "warrior", "count": 1}}},
			{"value": 1, "overrides": {"player": {"template_id": "warrior", "count": 2}}},
		],
	}

	var cases := ScenarioExpander.expand(raw)

	assert_eq(cases.size(), 2, "Both colliding cases must still be returned")
	assert_eq(cases[0].case_id, cases[1].case_id)
	for c in cases:
		var has_duplicate := false
		for error in c.errors:
			if String(error).begins_with("duplicate_id"):
				has_duplicate = true
		assert_true(has_duplicate, "A case_id collision from duplicate axis values must fail before construction")
