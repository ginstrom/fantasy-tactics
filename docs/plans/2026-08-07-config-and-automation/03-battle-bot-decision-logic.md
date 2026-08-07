# Task 3: `BattleBot` player-turn decision logic

## Objective

Add a headless-testable `BattleBot` that plays one player-side turn on a
`BattleController`: move each living, unacted player unit toward the
nearest living enemy, attacking if already (or newly) adjacent. This is the
same policy `BattleController._take_enemy_unit_actions()` already uses for
the enemy side, aimed at the opposite side and driven entirely through
`BattleController`'s existing public API (`get_legal_moves`,
`try_move_selected_unit`, `try_attack_selected_unit`) — no changes to
`battle_controller.gd` itself.

## Files

- Create: `scripts/tools/battle_bot.gd`
- Test: `tests/unit/test_battle_bot.gd`

## Steps

1. Write the failing test file `tests/unit/test_battle_bot.gd`, following
   the same bare-`BattleController` construction pattern already used in
   `tests/unit/test_battle_controller.gd` (`_make_controller` there skips
   `_ready()`/the scene tree entirely by setting `.grid` directly):

   ```gdscript
   extends GutTest

   const GridScript := preload("res://scripts/battle/grid.gd")
   const UnitScript := preload("res://scripts/battle/unit.gd")
   const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")


   func _make_controller(width: int, height: int) -> Node2D:
   	var controller: Node2D = BattleControllerScript.new()
   	controller.grid = GridScript.new(width, height)
   	autofree(controller)
   	return controller


   func test_moves_toward_the_nearest_enemy_when_out_of_attack_range() -> void:
   	var controller := _make_controller(6, 6)
   	var player := UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
   	var enemy := UnitScript.new(Vector2i(5, 5), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
   	controller.units = [player, enemy]

   	var steps: Array = BattleBot.take_player_turn(controller)

   	assert_ne(player.grid_position, Vector2i(0, 0), "Bot should move the unit toward the enemy")
   	assert_false(player.has_acted, "Out of range: no attack should have been made")
   	assert_eq(steps.size(), 1)
   	assert_eq(steps[0].type, "move")


   func test_attacks_an_adjacent_enemy_instead_of_moving() -> void:
   	var controller := _make_controller(6, 6)
   	var player := UnitScript.new(Vector2i(2, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
   	var enemy := UnitScript.new(Vector2i(3, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
   	controller.units = [player, enemy]
   	controller.hit_roll = func() -> float: return 0.0

   	var steps: Array = BattleBot.take_player_turn(controller)

   	assert_eq(player.grid_position, Vector2i(2, 2), "Already adjacent: unit should not move")
   	assert_true(player.has_acted, "Adjacent enemy should be attacked")
   	assert_eq(steps.size(), 1)
   	assert_eq(steps[0].type, "attack")
   	assert_eq(steps[0].defender, enemy)


   func test_moves_then_attacks_in_the_same_turn_once_in_range() -> void:
   	var controller := _make_controller(6, 6)
   	var player := UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
   	var enemy := UnitScript.new(Vector2i(2, 0), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
   	controller.units = [player, enemy]
   	controller.hit_roll = func() -> float: return 0.0

   	var steps: Array = BattleBot.take_player_turn(controller)

   	assert_eq(player.grid_position, Vector2i(1, 0), "Should move exactly one tile adjacent, not overshoot")
   	assert_true(player.has_acted)
   	assert_eq(steps.size(), 2)
   	assert_eq(steps[0].type, "move")
   	assert_eq(steps[1].type, "attack")


   func test_ignores_units_that_are_already_defeated() -> void:
   	var controller := _make_controller(6, 6)
   	var dead_player := UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
   	dead_player.health = 0
   	var enemy := UnitScript.new(Vector2i(1, 0), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
   	controller.units = [dead_player, enemy]

   	var steps: Array = BattleBot.take_player_turn(controller)

   	assert_eq(steps.size(), 0)
   	assert_eq(dead_player.grid_position, Vector2i(0, 0))
   ```

2. Run it and confirm it fails because `BattleBot` doesn't exist yet:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_bot.gd -gexit
   ```

   Expected: parser/compile error referencing an undefined `BattleBot`
   identifier.

3. Create `scripts/tools/battle_bot.gd`:

   ```gdscript
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


   ## Acts once with every living, not-yet-acted PLAYER unit on `controller`,
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
   	var target = _nearest_living_enemy(controller, unit.grid_position)
   	if target == null:
   		return steps

   	controller.selected_unit = unit
   	if not target.grid_position in controller.grid.get_adjacent(unit.grid_position):
   		var destination: Vector2i = _best_move_toward(controller, unit, target.grid_position)
   		var from: Vector2i = unit.grid_position
   		if destination != from and controller.try_move_selected_unit(destination):
   			steps.append({"type": "move", "unit": unit, "from": from, "to": destination})

   	if not unit.has_acted and target.is_alive() and target.grid_position in controller.grid.get_adjacent(unit.grid_position):
   		if controller.try_attack_selected_unit(target.grid_position):
   			steps.append(controller.last_attack_result)

   	return steps


   static func _nearest_living_enemy(controller, from_pos: Vector2i):
   	var nearest = null
   	var nearest_distance := -1
   	for unit in controller.units:
   		if unit.side != BattleControllerScript.Side.ENEMY or not unit.is_alive():
   			continue
   		var distance := _grid_distance(from_pos, unit.grid_position)
   		if nearest == null or distance < nearest_distance:
   			nearest = unit
   			nearest_distance = distance
   	return nearest


   static func _best_move_toward(controller, unit, target_pos: Vector2i) -> Vector2i:
   	var best: Vector2i = unit.grid_position
   	var best_distance := _grid_distance(unit.grid_position, target_pos)
   	for candidate in controller.get_legal_moves(unit):
   		var candidate_distance := _grid_distance(candidate, target_pos)
   		if candidate_distance < best_distance:
   			best = candidate
   			best_distance = candidate_distance
   	return best


   static func _grid_distance(a: Vector2i, b: Vector2i) -> int:
   	return abs(a.x - b.x) + abs(a.y - b.y)
   ```

   This is shaped exactly like the existing `DebugScenarios`
   (`scripts/debug/debug_scenarios.gd`): `class_name`, `extends RefCounted`,
   all-static functions, no instance state — usable as `BattleBot.foo(...)`
   from anywhere with no `preload`.

4. Rerun the focused suite; expect all four tests green:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_bot.gd -gexit
   ```

5. Run the full suite — `battle_controller.gd` was never modified, so
   nothing else should be affected:

   ```bash
   make check
   ```

6. Commit:

   ```bash
   git add scripts/tools/battle_bot.gd tests/unit/test_battle_bot.gd
   git commit -m "feat: add BattleBot greedy player-turn policy for headless battles"
   ```

## Milestone

`BattleBot.take_player_turn(controller)` correctly moves-and-attacks (or
just attacks, or just moves) for every living player unit on a
`BattleController`, proven against a bare (non-scene) controller exactly
like `test_battle_controller.gd`'s own existing tests — no scene
instantiation needed yet. Task 4 wires this into a real, full battle.
