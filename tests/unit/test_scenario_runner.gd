extends GutTest

const ScenarioContract := preload("res://scripts/tools/battle_scenarios/scenario_contract.gd")
const ScenarioExpander := preload("res://scripts/tools/battle_scenarios/scenario_expander.gd")
const ScenarioRunner := preload("res://scripts/tools/battle_scenarios/scenario_runner.gd")


class IllegalPolicy extends RefCounted:
	func take_turn(_controller, _rng) -> Dictionary:
		return {"ok": false, "error": {"code": "illegal_policy_intent", "intent": "teleport"}}


func _case(raw: Dictionary) -> Dictionary:
	return ScenarioExpander.expand(raw)[0]


func _tiny_case() -> Dictionary:
	return _case({
		"scenario_id": "tiny_runner",
		"player": {"units": [{"id": "hero", "template_id": "warrior", "position": {"x": 0, "y": 0}, "modifiers": {"damage_min": 99, "damage_max": 99}}]},
		"enemy": {"units": [{"id": "goblin", "template_id": "goblin", "position": {"x": 1, "y": 0}}]},
		"randomness": {"root_seed": 42, "iterations": 2},
	})


func test_run_case_records_reproducible_seeded_iterations_without_campaign_effects() -> void:
	var case := _tiny_case()
	var runner := ScenarioRunner.new()
	var gold_before: int = GameSession.gold
	var selected_before: String = GameSession.selected_encounter

	var first: Array = runner.run_case(case)
	var second: Array = runner.run_case(case)

	assert_eq(first, second)
	assert_eq(first.size(), 2)
	assert_eq(first[0].outcome, "victory")
	assert_eq(first[0].iteration_seed, ScenarioContract.derive_iteration_seed(42, case.case_id, 0))
	assert_eq(first[0].contract_version, ScenarioContract.CONTRACT_VERSION)
	assert_has(first[0], "normalized_case")
	assert_has(first[0], "attempts")
	assert_has(first[0], "survivors")
	assert_eq(GameSession.gold, gold_before)
	assert_eq(GameSession.selected_encounter, selected_before)


func test_run_case_classifies_a_round_cap_as_stalemate_not_a_loss() -> void:
	var case := _case({
		"scenario_id": "capped_runner",
		"player": {"template_id": "warrior", "count": 1},
		"enemy": {"template_id": "goblin", "count": 1},
		"rules": {"round_limit": 1},
	})

	var records: Array = ScenarioRunner.new().run_case(case)

	assert_eq(records.size(), 1)
	assert_eq(records[0].outcome, "stalemate")
	assert_eq(records[0].rounds, 1)


func test_invalid_case_becomes_one_machine_readable_error_record() -> void:
	var case := _case({
		"scenario_id": "invalid_runner",
		"player": {"template_id": "warrior", "count": 99},
		"enemy": {"template_id": "goblin", "count": 1},
	})

	var records: Array = ScenarioRunner.new().run_case(case)

	assert_eq(records.size(), 1)
	assert_eq(records[0].outcome, "error")
	assert_true(String(records[0].error.code).begins_with("scenario_invalid"))


func test_illegal_policy_intent_is_an_error_not_a_loss() -> void:
	var case := _tiny_case()
	case.scenario.policies.player = "broken"
	var runner := ScenarioRunner.new({"broken": IllegalPolicy.new()})

	var records: Array = runner.run_case(case)

	assert_eq(records[0].outcome, "error")
	assert_eq(records[0].error.code, "illegal_policy_intent")
