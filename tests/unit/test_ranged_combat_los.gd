extends GutTest

const GridScript := preload("res://scripts/battle/grid.gd")
const UnitScript := preload("res://scripts/battle/unit.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")


func _make_controller(width: int, height: int) -> Node2D:
	var controller: Node2D = BattleControllerScript.new()
	controller.grid = GridScript.new(width, height)
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


func test_battle_controller_allows_a_bow_target_at_range_three_but_rejects_it_for_melee() -> void:
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
	assert_false(controller.get_legal_attack_targets(attacker).has(enemy))
	assert_false(controller.try_attack_selected_unit(enemy.grid_position))


func test_ranged_attack_spends_three_action_points() -> void:
	var controller := _make_controller(6, 6)
	var attacker := UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE)
	var enemy := UnitScript.new(Vector2i(0, 3), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY)
	attacker.attack_max_range = 3
	controller.units = [attacker, enemy]
	controller.selected_unit = attacker

	assert_true(controller.try_attack_selected_unit(enemy.grid_position))
	assert_eq(attacker.action_points_remaining, 3)
