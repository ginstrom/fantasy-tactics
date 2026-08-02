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
