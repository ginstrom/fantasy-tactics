extends GutTest

const GridScript := preload("res://scripts/battle/grid.gd")


func test_bounds_check_within_and_outside_the_grid() -> void:
	var grid = GridScript.new(4, 3)

	assert_true(grid.is_in_bounds(Vector2i(0, 0)), "Top-left corner is in bounds")
	assert_true(grid.is_in_bounds(Vector2i(3, 2)), "Bottom-right corner is in bounds")
	assert_false(grid.is_in_bounds(Vector2i(4, 0)), "Width is out of bounds")
	assert_false(grid.is_in_bounds(Vector2i(0, 3)), "Height is out of bounds")
	assert_false(grid.is_in_bounds(Vector2i(-1, 0)), "Negative x is out of bounds")


func test_adjacent_tiles_are_four_directional() -> void:
	var grid = GridScript.new(5, 5)

	var adjacent: Array[Vector2i] = grid.get_adjacent(Vector2i(2, 2))

	assert_eq(adjacent.size(), 4, "An interior tile has four neighbors")
	assert_true(adjacent.has(Vector2i(1, 2)), "Left neighbor")
	assert_true(adjacent.has(Vector2i(3, 2)), "Right neighbor")
	assert_true(adjacent.has(Vector2i(2, 1)), "Up neighbor")
	assert_true(adjacent.has(Vector2i(2, 3)), "Down neighbor")
	assert_false(adjacent.has(Vector2i(1, 1)), "Diagonal is not adjacent on a square grid")


func test_adjacent_tiles_are_clipped_to_grid_bounds() -> void:
	var grid = GridScript.new(3, 3)

	var corner_adjacent: Array[Vector2i] = grid.get_adjacent(Vector2i(0, 0))

	assert_eq(corner_adjacent.size(), 2, "A corner tile only has two in-bounds neighbors")
	assert_true(corner_adjacent.has(Vector2i(1, 0)))
	assert_true(corner_adjacent.has(Vector2i(0, 1)))


func test_tiles_in_range_includes_tiles_up_to_the_move_range() -> void:
	var grid = GridScript.new(6, 6)
	var is_blocked := func(_pos: Vector2i) -> bool: return false

	var reachable: Array[Vector2i] = grid.get_tiles_in_range(Vector2i(2, 2), 2, is_blocked)

	assert_true(reachable.has(Vector2i(3, 2)), "One tile away is reachable")
	assert_true(reachable.has(Vector2i(2, 0)), "Two tiles away is reachable")
	assert_false(reachable.has(Vector2i(2, 2)), "The starting tile is not its own destination")
	assert_false(reachable.has(Vector2i(2, 5)), "Three tiles away exceeds the move range")


func test_tiles_in_range_cannot_pass_through_blocked_tiles() -> void:
	var grid = GridScript.new(6, 6)
	var is_blocked := func(pos: Vector2i) -> bool: return pos == Vector2i(3, 2)

	var reachable: Array[Vector2i] = grid.get_tiles_in_range(Vector2i(2, 2), 3, is_blocked)

	assert_false(reachable.has(Vector2i(3, 2)), "A blocked tile is not itself reachable")
	assert_false(reachable.has(Vector2i(4, 2)), "Movement cannot pass through a blocked tile")
	assert_true(reachable.has(Vector2i(2, 4)), "An unblocked direction is unaffected")


func test_tile_distances_reports_step_cost_for_reachable_tiles() -> void:
	var grid = GridScript.new(6, 6)
	var is_blocked := func(_pos: Vector2i) -> bool: return false

	var distances: Dictionary = grid.get_tile_distances(Vector2i(2, 2), 2, is_blocked)

	assert_eq(distances[Vector2i(3, 2)], 1, "One tile away costs 1")
	assert_eq(distances[Vector2i(2, 0)], 2, "Two tiles away costs 2")
	assert_false(distances.has(Vector2i(2, 2)), "The start tile is absent from the result")
	assert_false(distances.has(Vector2i(2, 5)), "A tile beyond move_range is absent")


func test_tile_distances_costs_more_when_a_detour_is_required() -> void:
	var grid = GridScript.new(6, 6)
	var is_blocked := func(pos: Vector2i) -> bool: return pos == Vector2i(3, 2)

	var distances: Dictionary = grid.get_tile_distances(Vector2i(2, 2), 4, is_blocked)

	assert_eq(
		distances[Vector2i(4, 2)], 4,
		"With (3,2) blocked, every path to (4,2) must detour, costing 4 instead of the Manhattan 2"
	)
