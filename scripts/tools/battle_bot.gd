class_name BattleBot
extends RefCounted
## Greedy player-turn policy for headless battle simulation (see
## docs/plans/2026-08-07-config-and-automation/04-headless-battle-sim-and-logging.md).
## Mirrors BattleController._take_enemy_unit_actions()'s own "move toward
## the nearest living opponent, then attack if adjacent" policy, aimed at
## the opposite side, driven entirely through BattleController's public
## API (get_legal_moves/try_move_selected_unit/try_attack_selected_unit) —
## battle_controller.gd itself is never modified.

const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")


## Acts with every living PLAYER unit while it has AP for legal actions,
## in current units-array order, and returns the resulting move/attack
## steps (same shape as BattleController.run_enemy_turn()'s own return
## value). Leaves controller.active_side untouched — ending the turn is
## the caller's responsibility (see battle_sim.gd).
static func take_player_turn(controller) -> Array:
	var steps: Array = []
	for unit in controller.units.duplicate():
		if not unit.is_alive() or unit.side != BattleControllerScript.Side.PLAYER:
			continue
		steps.append_array(_take_unit_actions(controller, unit))
	return steps


static func _take_unit_actions(controller, unit) -> Array:
	var steps: Array = []
	controller.selected_unit = unit
	var guard: int = int(unit.max_action_points) + 1
	while unit.action_points_remaining > 0 and guard > 0:
		guard -= 1
		var target = _nearest_living_enemy(controller, unit.grid_position)
		if target == null:
			break
		if controller.get_legal_attack_targets(unit).has(target):
			if controller.try_attack_selected_unit(target.grid_position):
				steps.append(controller.last_attack_result)
				continue
			break
		var destination: Vector2i = _best_move_toward(controller, unit, target.grid_position)
		var from: Vector2i = unit.grid_position
		if destination != from and controller.try_move_selected_unit(destination):
			steps.append({"type": "move", "unit": unit, "from": from, "to": destination})
			continue
		break

	return steps


## Mirror of BattleController._nearest_living_unit(), aimed at ENEMY instead of
## PLAYER: closest by grid distance, ties broken by reading order rather than
## by whichever unit happens to come first in the units array.
static func _nearest_living_enemy(controller, from_pos: Vector2i):
	var nearest = null
	var nearest_distance := -1
	for unit in controller.units:
		if unit.side != BattleControllerScript.Side.ENEMY or not unit.is_alive():
			continue
		var distance := _grid_distance(from_pos, unit.grid_position)
		if (
			nearest == null
			or distance < nearest_distance
			or (distance == nearest_distance and _reading_order_is_earlier(unit.grid_position, nearest.grid_position))
		):
			nearest = unit
			nearest_distance = distance
	return nearest


## Mirror of BattleController._best_move_toward(). Note the has_candidate seed:
## like the enemy AI, the first legal move is accepted unconditionally, so the
## unit always relocates when any legal move exists — even one that does not
## get closer — and only a strictly closer (or equally close but earlier in
## reading order) tile displaces it.
static func _best_move_toward(controller, unit, target_pos: Vector2i) -> Vector2i:
	var best: Vector2i = unit.grid_position
	var best_distance := _grid_distance(unit.grid_position, target_pos)
	var has_candidate := false
	for candidate in controller.get_legal_moves(unit):
		var candidate_distance := _grid_distance(candidate, target_pos)
		if (
			not has_candidate
			or candidate_distance < best_distance
			or (candidate_distance == best_distance and _reading_order_is_earlier(candidate, best))
		):
			best = candidate
			best_distance = candidate_distance
			has_candidate = true
	return best


static func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


## Top-to-bottom, left-to-right, matching BattleController's private helper of
## the same name (which cannot be reused from here — battle_controller.gd is
## never modified, and this file only touches its public API).
static func _reading_order_is_earlier(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x
