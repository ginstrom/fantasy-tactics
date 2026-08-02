extends RefCounted

var grid_position: Vector2i
var color: Color


func _init(p_grid_position: Vector2i, p_color: Color) -> void:
	grid_position = p_grid_position
	color = p_color
