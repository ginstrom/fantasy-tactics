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
