class_name ScenarioRunner
extends RefCounted
## Scene-free execution of one expanded scenario case. The factory supplies
## deterministic combat rolls; policies only select legal public actions.

const BattleStateFactory := preload("res://scripts/tools/battle_scenarios/battle_state_factory.gd")
const GreedyPlayerPolicy := preload("res://scripts/tools/battle_scenarios/greedy_player_policy.gd")
const CurrentEnemyPolicy := preload("res://scripts/tools/battle_scenarios/current_enemy_policy.gd")
const SeededRandom := preload("res://scripts/tools/battle_scenarios/seeded_random.gd")
const RUNNER_VERSION := 1
const ENGINE_VERSION := 1

var _policy_overrides: Dictionary


func _init(policy_overrides: Dictionary = {}) -> void:
	_policy_overrides = policy_overrides


func run_case(case: Dictionary) -> Array:
	if not case.get("errors", []).is_empty():
		return [_error_record(case, {"code": "scenario_invalid", "details": case.errors})]
	var records: Array = []
	for iteration_index in case.iteration_seeds.size():
		records.append(_run_iteration(case, iteration_index, int(case.iteration_seeds[iteration_index])))
	return records


func write_records(path: String, records: Array) -> Dictionary:
	if FileAccess.file_exists(path):
		return {"ok": false, "error": {"code": "output_exists", "path": path}}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": {"code": "output_open_failed", "path": path}}
	for record in records:
		file.store_line(JSON.stringify(record))
	file.close()
	return {"ok": true}


func _run_iteration(case: Dictionary, iteration_index: int, iteration_seed: int) -> Dictionary:
	var controller = BattleStateFactory.build(case.scenario, iteration_seed)
	var policy_rng := SeededRandom.new(iteration_seed)
	var player_policy = _resolve_policy(String(case.scenario.policies.player))
	var enemy_policy = _resolve_policy(String(case.scenario.policies.enemy))
	if player_policy == null or enemy_policy == null:
		controller.free()
		return _error_record(case, {"code": "policy_unknown"}, iteration_index, iteration_seed)

	var attempts := 0
	var rejections := 0
	var damage := 0
	var kills := 0
	var rounds := 0
	var outcome := "stalemate"
	var error: Dictionary = {}
	while rounds < int(case.scenario.rules.round_limit):
		rounds += 1
		var player_result: Dictionary = player_policy.take_turn(controller, policy_rng)
		if not bool(player_result.get("ok", false)):
			error = player_result.get("error", {"code": "policy_error"})
			break
		var player_metrics := _step_metrics(player_result.get("steps", []))
		attempts += player_metrics.attempts
		damage += player_metrics.damage
		kills += player_metrics.kills
		if controller.is_battle_won():
			outcome = "victory"
			break
		if controller.is_battle_lost():
			outcome = "defeat"
			break
		controller.end_turn()

		var enemy_result: Dictionary = enemy_policy.take_turn(controller, policy_rng)
		if not bool(enemy_result.get("ok", false)):
			error = enemy_result.get("error", {"code": "policy_error"})
			break
		var enemy_metrics := _step_metrics(enemy_result.get("steps", []))
		attempts += enemy_metrics.attempts
		damage += enemy_metrics.damage
		kills += enemy_metrics.kills
		if controller.is_battle_won():
			outcome = "victory"
			break
		if controller.is_battle_lost():
			outcome = "defeat"
			break
		controller.end_turn()

	if not error.is_empty():
		outcome = "error"
	var record := _record(case, iteration_index, iteration_seed, outcome, rounds, attempts, rejections, damage, kills, controller)
	if not error.is_empty():
		record["error"] = error
	controller.free()
	return record


func _resolve_policy(policy_name: String):
	if _policy_overrides.has(policy_name):
		return _policy_overrides[policy_name]
	match policy_name:
		"greedy_pursuit": return GreedyPlayerPolicy.new()
		"current_enemy_policy": return CurrentEnemyPolicy.new()
		_: return null


func _step_metrics(steps: Array) -> Dictionary:
	var result := {"attempts": steps.size(), "damage": 0, "kills": 0}
	for step in steps:
		if step is Dictionary and String(step.get("type", "")) == "attack":
			result.damage += int(step.get("damage", 0))
			if bool(step.get("defeated", false)):
				result.kills += 1
	return result


func _record(case: Dictionary, iteration_index: int, iteration_seed: int, outcome: String, rounds: int, attempts: int, rejections: int, damage: int, kills: int, controller) -> Dictionary:
	return {
		"contract_version": int(case.scenario.contract_version),
		"runner_version": RUNNER_VERSION,
		"engine_version": ENGINE_VERSION,
		"case_id": String(case.case_id),
		"iteration_index": iteration_index,
		"iteration_seed": iteration_seed,
		"normalized_case": case.scenario.duplicate(true),
		"config_fingerprint": "",
		"policies": case.scenario.policies.duplicate(true),
		"outcome": outcome,
		"rounds": rounds,
		"attempts": attempts,
		"rejections": rejections,
		"damage": damage,
		"kills": kills,
		"survivors": _survivors(controller),
		"raw_record": {"format": "jsonl", "elapsed_ms": 0},
	}


func _error_record(case: Dictionary, error: Dictionary, iteration_index: int = -1, iteration_seed: int = 0) -> Dictionary:
	return {
		"contract_version": int(case.get("scenario", {}).get("contract_version", 1)),
		"runner_version": RUNNER_VERSION,
		"engine_version": ENGINE_VERSION,
		"case_id": String(case.get("case_id", "")),
		"iteration_index": iteration_index,
		"iteration_seed": iteration_seed,
		"outcome": "error",
		"error": error,
	}


func _survivors(controller) -> Dictionary:
	var result := {"player": [], "enemy": []}
	for unit in controller.units:
		var side_key := "player" if int(unit.side) == 0 else "enemy"
		result[side_key].append({"id": String(unit.display_name), "health": int(unit.health), "max_health": int(unit.max_health)})
	return result
