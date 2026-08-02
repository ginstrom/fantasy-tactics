extends Node2D

signal board_changed
signal encounter_activated(encounter_id: String)

const GridScript := preload("res://scripts/battle/grid.gd")

const GRID_WIDTH := 5
const GRID_HEIGHT := 5
const TILE_SIZE := 64
const PARTY_MOVE_RANGE := 1

const ENCOUNTER_ID := "goblin_camp"
const PARTY_START := Vector2i(0, 0)
const ENCOUNTER_POSITION := Vector2i(4, 4)

const TILE_COLOR_LIGHT := Color(0.2, 0.3, 0.2)
const TILE_COLOR_DARK := Color(0.15, 0.22, 0.15)
const PARTY_COLOR := Color(0.3, 0.5, 0.9)
const ENCOUNTER_COLOR := Color(0.9, 0.6, 0.2)
const ENCOUNTER_COMPLETE_COLOR := Color(0.5, 0.5, 0.5)
const SELECTION_RING_COLOR := Color(1, 1, 1, 0.6)
const LEGAL_MOVE_COLOR := Color(0.4, 0.9, 0.4, 0.5)

var grid
var party_position: Vector2i = PARTY_START
var party_selected: bool = false

@onready var tile_container: Node2D = $Tiles
@onready var highlight_container: Node2D = $Highlights
@onready var marker_container: Node2D = $Markers


func _ready() -> void:
	grid = GridScript.new(GRID_WIDTH, GRID_HEIGHT)
	party_position = GameSession.party_position
	_draw_tiles()
	_draw_markers()
	_update_highlights()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.go_to_main_menu()
		return

	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return

	var tile_pos := _to_grid_position(get_local_mouse_position())
	if not grid.is_in_bounds(tile_pos):
		return

	get_viewport().set_input_as_handled()
	_handle_tile_click(tile_pos)


func get_legal_moves() -> Array[Vector2i]:
	var is_blocked := func(_pos: Vector2i) -> bool: return false
	return grid.get_tiles_in_range(party_position, PARTY_MOVE_RANGE, is_blocked)


func try_move_party(target: Vector2i) -> bool:
	if not target in get_legal_moves():
		return false

	party_position = target
	return true


func try_activate_current_tile() -> bool:
	if party_position != ENCOUNTER_POSITION:
		return false

	encounter_activated.emit(ENCOUNTER_ID)
	return true


func _handle_tile_click(tile_pos: Vector2i) -> void:
	if tile_pos == party_position:
		if try_activate_current_tile():
			party_selected = false
			_draw_markers()
			_update_highlights()
			return

		party_selected = not party_selected
		_update_highlights()
		return

	if party_selected and try_move_party(tile_pos):
		party_selected = false
		GameSession.party_position = party_position
		_draw_markers()
		_update_highlights()
		board_changed.emit()


func _on_encounter_activated(encounter_id: String) -> void:
	GameManager.enter_battle(encounter_id)


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


func _draw_markers() -> void:
	if not is_inside_tree():
		return

	for child in marker_container.get_children():
		child.queue_free()

	var margin := TILE_SIZE * 0.2

	var encounter := ColorRect.new()
	encounter.size = Vector2(TILE_SIZE, TILE_SIZE) - Vector2(margin, margin) * 2
	encounter.position = Vector2(ENCOUNTER_POSITION) * TILE_SIZE + Vector2(margin, margin)
	encounter.color = (
		ENCOUNTER_COMPLETE_COLOR
		if GameSession.is_encounter_complete(ENCOUNTER_ID)
		else ENCOUNTER_COLOR
	)
	encounter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_container.add_child(encounter)

	var party := ColorRect.new()
	party.size = Vector2(TILE_SIZE, TILE_SIZE) - Vector2(margin, margin) * 2
	party.position = Vector2(party_position) * TILE_SIZE + Vector2(margin, margin)
	party.color = PARTY_COLOR
	party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_container.add_child(party)


func _update_highlights() -> void:
	if not is_inside_tree():
		return

	for child in highlight_container.get_children():
		child.queue_free()

	if not party_selected:
		return

	var ring_margin := TILE_SIZE * 0.05
	var ring := ColorRect.new()
	ring.size = Vector2(TILE_SIZE, TILE_SIZE) - Vector2(ring_margin, ring_margin) * 2
	ring.position = Vector2(party_position) * TILE_SIZE + Vector2(ring_margin, ring_margin)
	ring.color = SELECTION_RING_COLOR
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight_container.add_child(ring)

	for move in get_legal_moves():
		var highlight := ColorRect.new()
		highlight.size = Vector2(TILE_SIZE, TILE_SIZE)
		highlight.position = Vector2(move) * TILE_SIZE
		highlight.color = LEGAL_MOVE_COLOR
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		highlight_container.add_child(highlight)
