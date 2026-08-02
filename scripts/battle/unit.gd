extends RefCounted

var grid_position: Vector2i
var color: Color
var side: int
var move_range: int
var has_moved: bool = false


func _init(p_grid_position: Vector2i, p_color: Color, p_side: int = 0, p_move_range: int = 1) -> void:
	grid_position = p_grid_position
	color = p_color
	side = p_side
	move_range = p_move_range
