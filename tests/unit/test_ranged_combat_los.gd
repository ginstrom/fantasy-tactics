extends GutTest

const GridScript := preload("res://scripts/battle/grid.gd")
const UnitScript := preload("res://scripts/battle/unit.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")


func _make_controller(width: int, height: int) -> Node2D:
	var controller: Node2D = BattleControllerScript.new()
	controller.grid = GridScript.new(width, height)
	# Stage 5 D2 tactical primitives: pin Dodge/Parry off so every guaranteed-
	# hit assertion in this file stays deterministic -- see
	# test_battle_controller.gd's own _make_controller() for the identical
	# fix and its full rationale.
	controller.dodge_roll = func() -> float: return 1.0
	controller.parry_roll = func() -> float: return 1.0
	autofree(controller)
	return controller


func test_grid_line_of_sight_is_unobstructed_without_intermediate_blockers() -> void:
	var grid := GridScript.new(4, 4)

	assert_true(grid.has_line_of_sight(Vector2i(0, 0), Vector2i(0, 3), []))


func test_grid_line_of_sight_is_blocked_by_an_intermediate_unit() -> void:
	var grid := GridScript.new(4, 4)

	assert_false(grid.has_line_of_sight(Vector2i(0, 0), Vector2i(0, 3), [Vector2i(0, 1)]))
	assert_false(grid.has_line_of_sight(Vector2i(0, 0), Vector2i(0, 3), [Vector2i(0, 2)]))


func test_attackable_tiles_include_only_in_range_positions_with_line_of_sight() -> void:
	var grid := GridScript.new(4, 4)

	var tiles: Array[Vector2i] = grid.get_attackable_tiles(Vector2i(0, 0), 1, 3, [Vector2i(0, 1)])

	assert_true(tiles.has(Vector2i(1, 0)))
	assert_true(tiles.has(Vector2i(2, 0)))
	assert_true(tiles.has(Vector2i(0, 1)), "An occupied target tile remains attackable")
	assert_false(tiles.has(Vector2i(0, 2)))
	assert_false(tiles.has(Vector2i(0, 3)))
	assert_false(tiles.has(Vector2i(3, 1)), "Positions farther than the maximum Manhattan range are excluded")


func test_battle_controller_allows_a_bow_target_at_range_three_and_automates_a_melee_move_and_attack() -> void:
	var controller := _make_controller(6, 6)
	var attacker := UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE)
	var enemy := UnitScript.new(Vector2i(0, 3), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY)
	controller.units = [attacker, enemy]
	controller.selected_unit = attacker
	attacker.attack_max_range = 3

	assert_true(controller.get_legal_attack_targets(attacker).has(enemy))
	assert_true(controller.try_attack_selected_unit(enemy.grid_position))

	attacker.action_points_remaining = attacker.max_action_points
	attacker.attack_max_range = 1
	assert_false(
		controller.get_legal_attack_targets(attacker).has(enemy),
		"Direct range is still governed by weapon reach alone"
	)
	# Switched to melee at range 3, the unit no longer just refuses the shot:
	# automated move-and-attack (see find_best_move_and_attack_tile()) steps
	# it into melee range and lands the attack, since 2 move + 3 attack AP
	# fits within its 6 AP budget.
	assert_true(controller.try_attack_selected_unit(enemy.grid_position))
	assert_eq(attacker.grid_position, Vector2i(0, 2), "The unit steps to the nearest melee-range tile")
	assert_eq(attacker.action_points_remaining, 1, "6 AP - 2 move - 3 attack = 1 remaining")


func test_ranged_attack_spends_three_action_points() -> void:
	var controller := _make_controller(6, 6)
	var attacker := UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE)
	var enemy := UnitScript.new(Vector2i(0, 3), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY)
	attacker.attack_max_range = 3
	controller.units = [attacker, enemy]
	controller.selected_unit = attacker

	assert_true(controller.try_attack_selected_unit(enemy.grid_position))
	assert_eq(attacker.action_points_remaining, 3)
