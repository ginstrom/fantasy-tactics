extends RefCounted

var width: int
var height: int


func _init(p_width: int, p_height: int) -> void:
	width = p_width
	height = p_height


func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height


func get_adjacent(pos: Vector2i) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = [
		pos + Vector2i.UP,
		pos + Vector2i.DOWN,
		pos + Vector2i.LEFT,
		pos + Vector2i.RIGHT,
	]

	var adjacent: Array[Vector2i] = []
	for candidate in candidates:
		if is_in_bounds(candidate):
			adjacent.append(candidate)
	return adjacent


## Battle range uses four-directional grid distance, matching movement and
## adjacency everywhere else in this project.
func get_manhattan_distance(from_pos: Vector2i, to_pos: Vector2i) -> int:
	return abs(from_pos.x - to_pos.x) + abs(from_pos.y - to_pos.y)


## Bresenham raycasting checks only intermediate tiles: a defender standing
## on the destination never blocks its own attack line.
func has_line_of_sight(start_tile: Vector2i, end_tile: Vector2i, blocking_tiles: Array[Vector2i]) -> bool:
	var x: int = start_tile.x
	var y: int = start_tile.y
	var end_x: int = end_tile.x
	var end_y: int = end_tile.y
	var delta_x: int = abs(end_x - x)
	var delta_y: int = abs(end_y - y)
	var step_x: int = 1 if x < end_x else -1
	var step_y: int = 1 if y < end_y else -1
	var error: int = delta_x - delta_y

	while x != end_x or y != end_y:
		var doubled_error: int = error * 2
		if doubled_error > -delta_y:
			error -= delta_y
			x += step_x
		if doubled_error < delta_x:
			error += delta_x
			y += step_y
		var tile := Vector2i(x, y)
		if tile != end_tile and blocking_tiles.has(tile):
			return false
	return true


func get_attackable_tiles(
	from_pos: Vector2i,
	min_range: int,
	max_range: int,
	blocking_tiles: Array[Vector2i] = []
) -> Array[Vector2i]:
	var attackable: Array[Vector2i] = []
	for y in height:
		for x in width:
			var tile := Vector2i(x, y)
			var distance: int = get_manhattan_distance(from_pos, tile)
			if distance < min_range or distance > max_range:
				continue
			if has_line_of_sight(from_pos, tile, blocking_tiles):
				attackable.append(tile)
	return attackable


func get_tiles_in_range(start: Vector2i, move_range: int, is_blocked: Callable) -> Array[Vector2i]:
	var visited := {start: true}
	var frontier: Array[Vector2i] = [start]
	var reachable: Array[Vector2i] = []

	for _step in move_range:
		var next_frontier: Array[Vector2i] = []
		for pos in frontier:
			for neighbor in get_adjacent(pos):
				if visited.has(neighbor):
					continue
				visited[neighbor] = true
				if is_blocked.call(neighbor):
					continue
				reachable.append(neighbor)
				next_frontier.append(neighbor)
		frontier = next_frontier

	return reachable


func get_tile_distances(start: Vector2i, move_range: int, is_blocked: Callable) -> Dictionary:
	var distances := {start: 0}
	var frontier: Array[Vector2i] = [start]

	for step in move_range:
		var next_frontier: Array[Vector2i] = []
		for pos in frontier:
			for neighbor in get_adjacent(pos):
				if distances.has(neighbor):
					continue
				if is_blocked.call(neighbor):
					continue
				distances[neighbor] = step + 1
				next_frontier.append(neighbor)
		frontier = next_frontier

	distances.erase(start)
	return distances
