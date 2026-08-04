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
const ENEMY_STEP_MOVE := "move"
const ENEMY_STEP_ATTACK := "attack"
const WARRIOR_START := Vector2i(1, 1)
const WARRIOR_COLOR := Color(0.3, 0.5, 0.9)
const WARRIOR_MAX_HEALTH := 3
const WARRIOR_ATTACK_DAMAGE := 2
const WARRIOR_HIT_CHANCE := 0.6
const WARRIOR_ATTACK_NAME := "Sword"
const GOBLIN_START := Vector2i(4, 4)
const GOBLIN_COLOR := Color(0.9, 0.4, 0.3)
const GOBLIN_MAX_HEALTH := 3
const GOBLIN_ATTACK_DAMAGE := 1
const GOBLIN_HIT_CHANCE := 0.3
const GOBLIN_ATTACK_NAME := "Short Sword"

var grid
var units: Array = []
var selected_unit = null
var active_side: int = Side.PLAYER
var input_locked: bool = false
var hit_roll: Callable = func() -> float: return randf()
var last_attack_result: Dictionary = {}

@onready var tile_container: Node2D = $Tiles
@onready var unit_container: Node2D = $Units
@onready var highlight_container: Node2D = $Highlights


func _ready() -> void:
	grid = GridScript.new(GRID_WIDTH, GRID_HEIGHT)
	units = [
		UnitScript.new(
			WARRIOR_START, WARRIOR_COLOR, Side.PLAYER, UNIT_MOVE_RANGE,
			WARRIOR_MAX_HEALTH, WARRIOR_ATTACK_DAMAGE, WARRIOR_HIT_CHANCE, WARRIOR_ATTACK_NAME
		),
		UnitScript.new(
			GOBLIN_START, GOBLIN_COLOR, Side.ENEMY, UNIT_MOVE_RANGE,
			GOBLIN_MAX_HEALTH, GOBLIN_ATTACK_DAMAGE, GOBLIN_HIT_CHANCE, GOBLIN_ATTACK_NAME
		),
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
	last_attack_result = {}
	return true


func try_attack_selected_unit(target_pos: Vector2i) -> bool:
	if selected_unit == null or not selected_unit.is_alive():
		return false
	if selected_unit.side != active_side:
		return false
	if selected_unit.has_acted:
		return false
	if not target_pos in grid.get_adjacent(selected_unit.grid_position):
		return false

	var target = get_unit_at(target_pos)
	if target == null or target.side == selected_unit.side or not target.is_alive():
		return false

	selected_unit.has_acted = true
	var hit: bool = hit_roll.call() < selected_unit.hit_chance
	var damage: int = selected_unit.attack_damage if hit else 0
	if hit:
		target.take_damage(damage)
	var defeated: bool = hit and not target.is_alive()
	if defeated:
		units.erase(target)

	last_attack_result = {
		"type": "attack",
		"attacker": selected_unit,
		"defender": target,
		"hit": hit,
		"damage": damage,
		"defeated": defeated,
	}
	return true


func end_turn() -> void:
	active_side = Side.ENEMY if active_side == Side.PLAYER else Side.PLAYER
	for unit in units:
		if unit.side == active_side:
			unit.has_moved = false
			unit.has_acted = false
	_select_unit(null)


func is_battle_won() -> bool:
	for unit in units:
		if unit.side == Side.ENEMY and unit.is_alive():
			return false
	return true


func is_battle_lost() -> bool:
	for unit in units:
		if unit.side == Side.PLAYER and unit.is_alive():
			return false
	return true


func run_enemy_turn() -> Array:
	var steps: Array = []
	for unit in units.duplicate():
		if not unit.is_alive() or unit.side != Side.ENEMY:
			continue
		steps.append_array(_take_enemy_unit_actions(unit))
	selected_unit = null
	return steps


func _take_enemy_unit_actions(unit) -> Array:
	var steps: Array = []
	var target = _nearest_living_unit(unit.grid_position, Side.PLAYER)
	if target == null:
		return steps

	selected_unit = unit
	if not target.grid_position in grid.get_adjacent(unit.grid_position):
		var destination := _best_move_toward(unit, target.grid_position)
		var from: Vector2i = unit.grid_position
		if destination != from and try_move_selected_unit(destination):
			steps.append({"type": ENEMY_STEP_MOVE, "unit": unit, "from": from, "to": destination})

	if not unit.has_acted and target.is_alive() and target.grid_position in grid.get_adjacent(unit.grid_position):
		if try_attack_selected_unit(target.grid_position):
			steps.append(last_attack_result)
	return steps


func _nearest_living_unit(from_pos: Vector2i, side: int):
	var nearest = null
	var nearest_distance := -1
	for unit in units:
		if unit.side != side or not unit.is_alive():
			continue
		var distance := _grid_distance(from_pos, unit.grid_position)
		if (
			nearest == null
			or distance < nearest_distance
			or (distance == nearest_distance and _reading_order_is_earlier(unit.grid_position, nearest.grid_position))
		):
			nearest = unit
			nearest_distance = distance
	return nearest


func _best_move_toward(unit, target_pos: Vector2i) -> Vector2i:
	var best: Vector2i = unit.grid_position
	var best_distance := _grid_distance(unit.grid_position, target_pos)
	var has_candidate := false
	for candidate in get_legal_moves(unit):
		var candidate_distance := _grid_distance(candidate, target_pos)
		if (
			not has_candidate
			or candidate_distance < best_distance
			or (candidate_distance == best_distance and _reading_order_is_earlier(candidate, best))
		):
			best = candidate
			best_distance = candidate_distance
			has_candidate = true
	return best


func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func _reading_order_is_earlier(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


func _handle_tile_click(tile_pos: Vector2i) -> void:
	if input_locked:
		return

	var clicked_unit = get_unit_at(tile_pos)
	if clicked_unit != null:
		if clicked_unit.side == active_side:
			_select_unit(clicked_unit)
			return

		if selected_unit != null and try_attack_selected_unit(tile_pos):
			_draw_units()
			_select_unit_after_action()
		return

	if try_move_selected_unit(tile_pos):
		_draw_units()
		_select_unit_after_action()


func _select_unit_after_action() -> void:
	if selected_unit == null or not selected_unit.is_alive():
		_select_unit(null)
		return
	if selected_unit.has_moved and selected_unit.has_acted:
		_select_unit(null)
		return
	_select_unit(selected_unit)


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
