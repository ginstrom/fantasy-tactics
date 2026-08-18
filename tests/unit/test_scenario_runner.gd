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


## Step 2 of docs/plans/2026-08-18-critical-hits-and-flanking: crit_roll must
## be seeded exactly like hit_roll/damage_roll (see battle_state_factory.gd),
## so re-running the same critical-capable case with the same root seed
## reproduces byte-identical records -- including damage (which a critical
## hit amplifies) and survivors.
func test_run_case_reproduces_byte_identical_records_for_a_critical_capable_scenario() -> void:
	var case := _case({
		"scenario_id": "critical_capable_runner",
		"player": {
			"units": [
				{
					"id": "hero", "template_id": "warrior", "position": {"x": 0, "y": 0},
					"modifiers": {"damage_min": 20, "damage_max": 20},
				},
			],
		},
		"enemy": {"template_id": "goblin", "count": 1},
		"randomness": {"root_seed": 20260810, "iterations": 20},
	})
	var runner := ScenarioRunner.new()

	var first: Array = runner.run_case(case)
	var second: Array = runner.run_case(case)

	assert_eq(first, second, "Identical iteration seeds must reproduce byte-identical records")
	assert_eq(first.size(), 20)
	for record in first:
		assert_has(record, "damage")
		assert_has(record, "survivors")


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


## --- Flanking scripted tactical trace (docs/plans/2026-08-18-critical-hits-
## and-flanking/03-flanking-tactics-and-combat-resolution.md) ---
##
## A test-only policy override (see the "broken" IllegalPolicy above for the
## same mutate-after-expand() pattern) that proves the front/side/rear
## modifiers through the runner's real public surface rather than calling
## get_flank_type() or try_attack_selected_unit() in isolation. It never
## mutates unit state directly -- it only selects the attacker and calls the
## same public try_attack_selected_unit() every interactive click and every
## other policy ultimately calls, after injecting deterministic rolls the
## same way test_battle_controller.gd does. Recording last_attack_result
## itself (rather than trusting run_case()'s own record) is required here:
## that aggregated record only sums damage/attempts/kills across the whole
## battle, it never carries a single attack's resolved flank/effective_*
## fields.
class ScriptedFlankPolicy extends RefCounted:
	var recorded: Array = []
	var _hit_roll: float
	var _crit_roll: float
	var _damage: int

	func _init(hit_roll: float, crit_roll: float, damage: int) -> void:
		_hit_roll = hit_roll
		_crit_roll = crit_roll
		_damage = damage

	func take_turn(controller, _rng) -> Dictionary:
		var attacker = null
		var defender = null
		for unit in controller.units:
			if unit.side == 0:
				attacker = unit
			else:
				defender = unit
		controller.selected_unit = attacker
		controller.hit_roll = func() -> float: return _hit_roll
		controller.crit_roll = func() -> float: return _crit_roll
		controller.damage_roll = func(_min_value: int, _max_value: int) -> int: return _damage
		if not controller.try_attack_selected_unit(defender.grid_position):
			return {"ok": false, "error": {"code": "attack_rejected"}}
		recorded.append(controller.last_attack_result.duplicate())
		return {"ok": true, "steps": [controller.last_attack_result]}


## The lone goblin's max_health modifier (13 base - 10 = 3) guarantees even a
## non-critical hit (the fixed damage of 4 below) defeats it in one blow, so
## is_battle_won() ends the battle before the enemy ever gets a turn -- three
## separate isolated cases (front/side/rear), each fielding its own fresh
## controller, so a unit turning to face its target after attacking (see
## try_attack_selected_unit()) can never leak into the next angle's setup.
func _flank_trace_case(case_id: String, enemy_facing: String) -> Dictionary:
	return _case({
		"scenario_id": case_id,
		"player": {"units": [{"id": "hero", "template_id": "warrior", "position": {"x": 0, "y": 3}}]},
		"enemy": {
			"units": [
				{
					"id": "goblin", "template_id": "goblin", "position": {"x": 1, "y": 3},
					"facing": enemy_facing, "modifiers": {"max_health": -10},
				},
			],
		},
		"rules": {"round_limit": 5},
	})


func test_scripted_trace_proves_the_front_flank_modifier() -> void:
	var case := _flank_trace_case("flank_trace_front", "left")
	case.scenario.policies.player = "scripted_flank"
	var policy := ScriptedFlankPolicy.new(0.0, 0.40, 4)
	var runner := ScenarioRunner.new({"scripted_flank": policy})

	runner.run_case(case)

	assert_eq(policy.recorded.size(), 1, "The guaranteed kill must end the battle before the enemy ever acts")
	var result: Dictionary = policy.recorded[0]
	assert_eq(result.flank, "front")
	assert_almost_eq(result.effective_crit_chance, 0.05, 0.0001, "Front applies no crit bonus over the 5% base")
	assert_false(result.critical, "An injected 0.40 roll must not crit at the 5% front threshold")
	assert_eq(result.damage, 4, "A non-critical hit deals the injected raw 4 damage against the goblin's 0% resistance")


func test_scripted_trace_proves_the_side_flank_modifier() -> void:
	var case := _flank_trace_case("flank_trace_side", "up")
	case.scenario.policies.player = "scripted_flank"
	var policy := ScriptedFlankPolicy.new(0.0, 0.40, 4)
	var runner := ScenarioRunner.new({"scripted_flank": policy})

	runner.run_case(case)

	assert_eq(policy.recorded.size(), 1, "The guaranteed kill must end the battle before the enemy ever acts")
	var result: Dictionary = policy.recorded[0]
	assert_eq(result.flank, "side")
	assert_almost_eq(result.effective_crit_chance, 0.25, 0.0001, "0.05 base + the configured 0.20 side crit bonus")
	assert_false(result.critical, "An injected 0.40 roll must not crit at the 25% side threshold")
	assert_eq(result.damage, 4, "A non-critical hit deals the injected raw 4 damage against the goblin's 0% resistance")


func test_scripted_trace_proves_the_rear_flank_modifier() -> void:
	var case := _flank_trace_case("flank_trace_rear", "right")
	case.scenario.policies.player = "scripted_flank"
	var policy := ScriptedFlankPolicy.new(0.0, 0.40, 4)
	var runner := ScenarioRunner.new({"scripted_flank": policy})

	runner.run_case(case)

	assert_eq(policy.recorded.size(), 1, "The guaranteed kill must end the battle before the enemy ever acts")
	var result: Dictionary = policy.recorded[0]
	assert_eq(result.flank, "rear")
	assert_almost_eq(result.effective_crit_chance, 0.55, 0.0001, "0.05 base + the configured 0.50 rear crit bonus")
	assert_true(result.critical, "An injected 0.40 roll must crit at the 55% rear threshold")
	assert_eq(result.damage, 6, "round(4 * 1.5) = 6 damage on a critical hit against the goblin's 0% resistance")


## Runner smoke fixture (scenarios/battle/flanking-tactics.json): explicit
## positions and facings for a deterministic smoke run, proved reproducible
## exactly like test_run_case_reproduces_byte_identical_records_for_a_
## critical_capable_scenario above -- reports results but never asserts a
## greedy policy produces higher win/damage rates (see this plan step's own
## "must not assert" contract for this fixture).
func test_flanking_tactics_fixture_reproduces_byte_identical_records_for_the_same_seed() -> void:
	var text := FileAccess.get_file_as_string("res://scenarios/battle/flanking-tactics.json")
	var raw = JSON.parse_string(text)
	raw.randomness = {"root_seed": 20260818, "iterations": 20}
	var case := _case(raw)
	var runner := ScenarioRunner.new()

	var first: Array = runner.run_case(case)
	var second: Array = runner.run_case(case)

	assert_eq(first, second, "Identical iteration seeds must reproduce byte-identical records")
	assert_eq(first.size(), 20)
	for record in first:
		assert_ne(record.outcome, "error", "The flanking-tactics fixture must be a valid, runnable scenario")
