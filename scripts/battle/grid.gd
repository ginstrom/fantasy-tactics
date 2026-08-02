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
