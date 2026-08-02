extends Node2D

signal board_changed

const GridScript := preload("res://scripts/battle/grid.gd")
const UnitScript := preload("res://scripts/battle/unit.gd")

const GRID_WIDTH := 6
const GRID_HEIGHT := 6
const TILE_SIZE := 64

const TILE_COLOR_LIGHT := Color(0.24, 0.24, 0.28)
const TILE_COLOR_DARK := Color(0.18, 0.18, 0.21)
const SELECTION_RING_COLOR := Color(1, 1, 1, 0.6)
const LEGAL_MOVE_COLOR := Color(0.4, 0.9, 0.4, 0.5)

enum Side { PLAYER, ENEMY }

const UNIT_MOVE_RANGE := 3

var grid
var units: Array = []
var selected_unit = null
var active_side: int = Side.PLAYER

@onready var tile_container: Node2D = $Tiles
@onready var unit_container: Node2D = $Units
@onready var highlight_container: Node2D = $Highlights


func _ready() -> void:
	grid = GridScript.new(GRID_WIDTH, GRID_HEIGHT)
	units = [
		UnitScript.new(Vector2i(1, 1), Color(0.3, 0.5, 0.9), Side.PLAYER, UNIT_MOVE_RANGE),
		UnitScript.new(Vector2i(4, 4), Color(0.9, 0.4, 0.3), Side.ENEMY, UNIT_MOVE_RANGE),
	]
	_draw_tiles()
	_draw_units()
	_update_highlights()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return

	var tile_pos := _to_grid_position(get_local_mouse_position())
	if not grid.is_in_bounds(tile_pos):
		return

	get_viewport().set_input_as_handled()
	_handle_tile_click(tile_pos)


func get_unit_at(pos: Vector2i):
	for unit in units:
		if unit.grid_position == pos:
			return unit
	return null


func get_legal_moves(unit) -> Array[Vector2i]:
	if unit.has_moved:
		return []
	var is_blocked := func(pos: Vector2i) -> bool: return get_unit_at(pos) != null
	return grid.get_tiles_in_range(unit.grid_position, unit.move_range, is_blocked)


func try_move_selected_unit(target: Vector2i) -> bool:
	if selected_unit == null:
		return false
	if selected_unit.side != active_side:
		return false
	if not target in get_legal_moves(selected_unit):
		return false

	selected_unit.grid_position = target
	selected_unit.has_moved = true
	return true


func end_turn() -> void:
	active_side = Side.ENEMY if active_side == Side.PLAYER else Side.PLAYER
	for unit in units:
		if unit.side == active_side:
			unit.has_moved = false
	_select_unit(null)


func _handle_tile_click(tile_pos: Vector2i) -> void:
	var clicked_unit = get_unit_at(tile_pos)
	if clicked_unit != null:
		if clicked_unit.side == active_side:
			_select_unit(clicked_unit)
		return

	if try_move_selected_unit(tile_pos):
		_draw_units()
		_select_unit(null)


func _select_unit(unit) -> void:
	selected_unit = unit
	_update_highlights()
	board_changed.emit()


func _to_grid_position(local_pos: Vector2) -> Vector2i:
	return Vector2i(floori(local_pos.x / TILE_SIZE), floori(local_pos.y / TILE_SIZE))


func _draw_tiles() -> void:
	for child in tile_container.get_children():
		child.queue_free()

	for y in grid.height:
		for x in grid.width:
			var tile := ColorRect.new()
			tile.size = Vector2(TILE_SIZE, TILE_SIZE)
			tile.position = Vector2(x, y) * TILE_SIZE
			tile.color = TILE_COLOR_LIGHT if (x + y) % 2 == 0 else TILE_COLOR_DARK
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile_container.add_child(tile)


func _draw_units() -> void:
	for child in unit_container.get_children():
		child.queue_free()

	var margin := TILE_SIZE * 0.15
	for unit in units:
		var body := ColorRect.new()
		body.size = Vector2(TILE_SIZE, TILE_SIZE) - Vector2(margin, margin) * 2
		body.position = Vector2(unit.grid_position) * TILE_SIZE + Vector2(margin, margin)
		body.color = unit.color
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unit_container.add_child(body)


func _update_highlights() -> void:
	if not is_inside_tree():
		return

	for child in highlight_container.get_children():
		child.queue_free()

	if selected_unit == null:
		return

	var ring_margin := TILE_SIZE * 0.05
	var ring := ColorRect.new()
	ring.size = Vector2(TILE_SIZE, TILE_SIZE) - Vector2(ring_margin, ring_margin) * 2
	ring.position = Vector2(selected_unit.grid_position) * TILE_SIZE + Vector2(ring_margin, ring_margin)
	ring.color = SELECTION_RING_COLOR
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight_container.add_child(ring)

	for move in get_legal_moves(selected_unit):
		var highlight := ColorRect.new()
		highlight.size = Vector2(TILE_SIZE, TILE_SIZE)
		highlight.position = Vector2(move) * TILE_SIZE
		highlight.color = LEGAL_MOVE_COLOR
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		highlight_container.add_child(highlight)
