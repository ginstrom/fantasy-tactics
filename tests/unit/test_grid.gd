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


## --- get_shortest_path(): deterministic BFS route, not just distance -------

func test_shortest_path_returns_a_single_tile_path_when_start_equals_target() -> void:
	var grid = GridScript.new(6, 6)
	var is_blocked := func(_pos: Vector2i) -> bool: return false

	var path: Array[Vector2i] = grid.get_shortest_path(Vector2i(2, 2), Vector2i(2, 2), 3, is_blocked)

	assert_eq(path, [Vector2i(2, 2)])


func test_shortest_path_returns_empty_when_the_target_is_unreachable_within_move_range() -> void:
	var grid = GridScript.new(6, 6)
	var is_blocked := func(_pos: Vector2i) -> bool: return false

	var path: Array[Vector2i] = grid.get_shortest_path(Vector2i(0, 0), Vector2i(5, 5), 3, is_blocked)

	assert_eq(path, [] as Array[Vector2i])


func test_shortest_path_returns_empty_when_the_target_tile_is_blocked() -> void:
	var grid = GridScript.new(6, 6)
	var is_blocked := func(pos: Vector2i) -> bool: return pos == Vector2i(1, 0)

	var path: Array[Vector2i] = grid.get_shortest_path(Vector2i(0, 0), Vector2i(1, 0), 3, is_blocked)

	assert_eq(path, [] as Array[Vector2i])


func test_shortest_path_detours_around_a_blocked_tile() -> void:
	var grid = GridScript.new(6, 6)
	var is_blocked := func(pos: Vector2i) -> bool: return pos == Vector2i(1, 0)

	var path: Array[Vector2i] = grid.get_shortest_path(Vector2i(0, 0), Vector2i(2, 0), 4, is_blocked)

	assert_false(path.has(Vector2i(1, 0)), "The path must never pass through a blocked tile")
	assert_eq(path[0], Vector2i(0, 0))
	assert_eq(path[-1], Vector2i(2, 0))


## Of the three equally-short (distance-3) routes from (0,0) to (2,1) --
## RRD, RDR, DRR -- BFS must resolve the tie using get_adjacent()'s own
## UP/DOWN/LEFT/RIGHT neighbor order, not an arbitrary or path-agnostic
## rule. Tracing that order by hand: from (0,0) the DOWN neighbor (0,1) is
## discovered before the RIGHT neighbor (1,0), so every tile reachable only
## through (0,1) claims its predecessor before the RIGHT-first branch can,
## and the deterministic winning route is (0,0)-(0,1)-(1,1)-(2,1).
func test_shortest_path_breaks_ties_between_equally_short_routes_using_get_adjacents_neighbor_order() -> void:
	var grid = GridScript.new(6, 6)
	var is_blocked := func(_pos: Vector2i) -> bool: return false

	var path: Array[Vector2i] = grid.get_shortest_path(Vector2i(0, 0), Vector2i(2, 1), 5, is_blocked)

	assert_eq(path, [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)])


## --- is_attack_adjacent(): eight-directional, combat-only ------------------

func test_is_attack_adjacent_is_true_for_cardinal_and_diagonal_neighbors() -> void:
	var grid = GridScript.new(6, 6)

	assert_true(grid.is_attack_adjacent(Vector2i(2, 2), Vector2i(3, 2)), "Cardinal neighbor")
	assert_true(grid.is_attack_adjacent(Vector2i(2, 2), Vector2i(2, 1)), "Cardinal neighbor")
	assert_true(grid.is_attack_adjacent(Vector2i(2, 2), Vector2i(3, 3)), "Diagonal neighbor")
	assert_true(grid.is_attack_adjacent(Vector2i(2, 2), Vector2i(1, 3)), "Diagonal neighbor")


func test_is_attack_adjacent_is_false_for_the_same_tile_or_anything_two_tiles_away() -> void:
	var grid = GridScript.new(6, 6)

	assert_false(grid.is_attack_adjacent(Vector2i(2, 2), Vector2i(2, 2)), "A tile is not adjacent to itself")
	assert_false(grid.is_attack_adjacent(Vector2i(2, 2), Vector2i(4, 2)), "Two cardinal tiles away")
	assert_false(grid.is_attack_adjacent(Vector2i(2, 2), Vector2i(4, 4)), "Two diagonal tiles away")


## --- Terrain: Cover tiles (Stage 5 D2) --------------------------------------

func test_a_tile_with_no_authored_cover_reports_cover_none() -> void:
	var grid = GridScript.new(6, 6)

	assert_eq(grid.get_cover(Vector2i(2, 2)), GridScript.COVER_NONE)


func test_get_cover_reports_the_authored_tier_for_a_cover_tile() -> void:
	var grid = GridScript.new(6, 6)
	grid.cover_tiles[Vector2i(1, 1)] = GridScript.COVER_LOW
	grid.cover_tiles[Vector2i(2, 2)] = GridScript.COVER_HIGH

	assert_eq(grid.get_cover(Vector2i(1, 1)), GridScript.COVER_LOW)
	assert_eq(grid.get_cover(Vector2i(2, 2)), GridScript.COVER_HIGH)
	assert_eq(grid.get_cover(Vector2i(3, 3)), GridScript.COVER_NONE, "An unauthored tile is never treated as cover")


## --- Visibility: get_visible_tiles() (Stage 5 D2) ---------------------------

func test_get_visible_tiles_includes_the_viewers_own_tile() -> void:
	var grid = GridScript.new(6, 6)

	var visible: Dictionary = grid.get_visible_tiles([Vector2i(2, 2)], [])

	assert_true(visible.has(Vector2i(2, 2)))


func test_get_visible_tiles_includes_every_tile_with_an_unobstructed_line_when_nothing_blocks() -> void:
	var grid = GridScript.new(4, 4)

	var visible: Dictionary = grid.get_visible_tiles([Vector2i(0, 0)], [])

	assert_true(visible.has(Vector2i(3, 3)), "The farthest tile is still visible with no blockers")
	assert_eq(visible.size(), 16, "Every tile on a small, empty board is visible from one viewer")


func test_get_visible_tiles_excludes_a_tile_whose_only_line_is_blocked() -> void:
	var grid = GridScript.new(4, 4)

	var visible: Dictionary = grid.get_visible_tiles([Vector2i(0, 0)], [Vector2i(0, 1)])

	assert_false(visible.has(Vector2i(0, 3)), "Every straight line to (0,3) from (0,0) passes through the blocker at (0,1)")
	assert_true(visible.has(Vector2i(0, 1)), "The blocking tile itself is still visible -- it is the line's destination there")
	assert_true(visible.has(Vector2i(3, 0)), "An unrelated direction is unaffected by the blocker")


func test_get_visible_tiles_unions_across_multiple_viewers() -> void:
	var grid = GridScript.new(6, 6)

	var visible: Dictionary = grid.get_visible_tiles([Vector2i(0, 0), Vector2i(5, 5)], [])

	assert_true(visible.has(Vector2i(0, 0)))
	assert_true(visible.has(Vector2i(5, 5)))


func test_get_visible_tiles_ignores_an_out_of_bounds_viewer_without_crashing() -> void:
	var grid = GridScript.new(4, 4)

	var visible: Dictionary = grid.get_visible_tiles([Vector2i(-1, -1)], [])

	assert_eq(visible, {})
