extends Node2D

signal board_changed
signal encounter_activated(encounter_id: String)
signal settlement_activated(location_id: String)

const GridScript := preload("res://scripts/battle/grid.gd")

const GRID_WIDTH := 5
const GRID_HEIGHT := 5
const TILE_SIZE := 64
const PARTY_MOVE_RANGE := 1

const SETTLEMENT_ID := "starting_settlement"
const SETTLEMENT_POSITION := Vector2i(0, 0)
const PARTY_START := SETTLEMENT_POSITION

const TILE_COLOR_LIGHT := Color(0.2, 0.3, 0.2)
const TILE_COLOR_DARK := Color(0.15, 0.22, 0.15)
const PARTY_COLOR := Color(0.3, 0.5, 0.9)
const SETTLEMENT_COLOR := Color(0.5, 0.7, 0.4)
const ENCOUNTER_COLOR := Color(0.9, 0.6, 0.2)
const ENCOUNTER_COMPLETE_COLOR := Color(0.5, 0.5, 0.5)
const SELECTION_RING_COLOR := Color(1, 1, 1, 0.6)
const LEGAL_MOVE_COLOR := Color(0.4, 0.9, 0.4, 0.5)
const ROUTE_SEGMENT_COLOR := Color(0.9, 0.9, 0.3, 0.6)
const ROUTE_TARGET_COLOR := Color(0.9, 0.9, 0.3, 0.9)
const HOVER_ROUTE_SEGMENT_COLOR := Color(0.4, 0.9, 0.9, 0.5)
const HOVER_ROUTE_TARGET_COLOR := Color(0.4, 0.9, 0.9, 0.8)

# Expedition labels sit above their marker by default. This floor keeps a
# label on grid row 0 (or any row close enough to the top) from rendering
# off the top edge of the viewport.
const EXPEDITION_LABEL_MIN_Y := 112.0

var grid
var party_position: Vector2i = PARTY_START
var party_selected: bool = false
var hover_route: Array[Vector2i] = []

@onready var tile_container: Node2D = $Tiles
@onready var highlight_container: Node2D = $Highlights
@onready var marker_container: Node2D = $Markers
@onready var route_container: Node2D = $Routes
@onready var turn_label: Label = $HUD/TurnLabel
@onready var information_panel: PanelContainer = $HUD/InformationPanel


func _ready() -> void:
	grid = GridScript.new(GRID_WIDTH, GRID_HEIGHT)
	party_position = GameSession.get_deployed_party_position()
	information_panel.party_selected.connect(_on_information_panel_party_selected)
	_draw_tiles()
	_draw_markers()
	_draw_routes()
	_update_highlights()
	_update_turn_label()
	_refresh_information_panel()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()
		return

	if event is InputEventMouseMotion:
		_update_hover_route(_to_grid_position(get_local_mouse_position()))
		return

	if not (event is InputEventMouseButton) or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		if party_selected:
			get_viewport().set_input_as_handled()
			cancel_route_setting()
			party_selected = false
			_draw_routes()
			_update_highlights()
			_refresh_information_panel()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	var tile_pos := _to_grid_position(get_local_mouse_position())
	if not grid.is_in_bounds(tile_pos):
		return

	get_viewport().set_input_as_handled()
	_handle_tile_click(tile_pos)


func get_legal_moves() -> Array[Vector2i]:
	if not GameSession.has_deployed_party():
		return []

	var is_blocked := func(_pos: Vector2i) -> bool: return false
	return grid.get_tiles_in_range(party_position, PARTY_MOVE_RANGE, is_blocked)


func try_move_party(target: Vector2i) -> bool:
	if not GameSession.has_deployed_party():
		return false

	if not target in get_legal_moves():
		return false

	party_position = target
	return true


func try_activate_current_tile() -> bool:
	if not GameSession.has_deployed_party():
		return false

	var encounter_id := _expedition_id_at(party_position)
	if encounter_id == "" or GameSession.is_encounter_complete(encounter_id):
		return false

	encounter_activated.emit(encounter_id)
	return true


func _expedition_id_at(pos: Vector2i) -> String:
	for encounter_id in GameSession.EXPEDITIONS.keys():
		if GameSession.EXPEDITIONS[encounter_id].position == pos:
			return encounter_id
	return ""


func build_route(from: Vector2i, destination: Vector2i) -> Array[Vector2i]:
	if not grid.is_in_bounds(from) or not grid.is_in_bounds(destination):
		return []
	if from == destination:
		return []

	var route: Array[Vector2i] = []
	var current := from
	while current.x != destination.x:
		current.x += 1 if destination.x > current.x else -1
		route.append(current)
	while current.y != destination.y:
		current.y += 1 if destination.y > current.y else -1
		route.append(current)
	return route


func get_route_destination() -> Vector2i:
	var route := GameSession.get_deployed_party_route()
	if route.is_empty():
		return party_position
	return route[route.size() - 1]


func cancel_route_setting() -> void:
	hover_route = []


func _has_route_affordance() -> bool:
	return (
		party_selected
		and GameSession.has_deployed_party()
		and GameSession.get_deployed_party_route().is_empty()
	)


func _update_hover_route(tile_pos: Vector2i) -> void:
	if not _has_route_affordance() or not grid.is_in_bounds(tile_pos):
		hover_route = []
	else:
		hover_route = build_route(party_position, tile_pos)
	_draw_routes()


func _on_end_turn_pressed() -> void:
	GameSession.end_world_turn()
	party_position = GameSession.get_deployed_party_position()
	_draw_markers()
	_draw_routes()
	_update_highlights()
	_update_turn_label()
	board_changed.emit()


func _handle_tile_click(tile_pos: Vector2i) -> void:
	if not GameSession.has_deployed_party():
		return

	if tile_pos == party_position:
		if not party_selected:
			party_selected = true
			_update_highlights()
			_refresh_information_panel()
			return

		if not GameSession.get_deployed_party_route().is_empty():
			GameSession.clear_deployed_party_route()
			hover_route = []
			_draw_routes()
			_update_highlights()
			return

		if tile_pos == SETTLEMENT_POSITION:
			settlement_activated.emit(SETTLEMENT_ID)
			return

		if try_activate_current_tile():
			party_selected = false
			hover_route = []
			_draw_markers()
			_draw_routes()
			_update_highlights()
			_refresh_information_panel()
			return

		party_selected = false
		hover_route = []
		_draw_routes()
		_update_highlights()
		_refresh_information_panel()
		return

	if not party_selected:
		return

	if tile_pos == get_route_destination():
		if GameSession.take_next_route_step():
			party_position = GameSession.get_deployed_party_position()
			hover_route = []
			_draw_markers()
			_draw_routes()
			_update_highlights()
			board_changed.emit()
		return

	var route := build_route(party_position, tile_pos)
	if not route.is_empty() and GameSession.set_deployed_party_route(route):
		hover_route = []
		_draw_markers()
		_draw_routes()
		_update_highlights()


func _on_encounter_activated(encounter_id: String) -> void:
	GameManager.enter_battle(encounter_id)


func _on_settlement_activated(_location_id: String) -> void:
	GameManager.return_party_to_encampment()


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

	for encounter_id in GameSession.EXPEDITIONS.keys():
		var record: Dictionary = GameSession.get_expedition(encounter_id)

		var encounter := ColorRect.new()
		encounter.size = Vector2(TILE_SIZE, TILE_SIZE) - Vector2(margin, margin) * 2
		encounter.position = Vector2(record.position) * TILE_SIZE + Vector2(margin, margin)
		encounter.color = (
			ENCOUNTER_COMPLETE_COLOR
			if GameSession.is_encounter_complete(encounter_id)
			else ENCOUNTER_COLOR
		)
		encounter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker_container.add_child(encounter)

		var label := Label.new()
		label.text = tr("world_map.expedition.label") % [
			tr(record.name_key), tr(record.danger_key), record.reward
		]
		var label_y := maxf(record.position.y * TILE_SIZE - TILE_SIZE * 0.6, EXPEDITION_LABEL_MIN_Y)
		label.position = Vector2(record.position.x * TILE_SIZE + TILE_SIZE * 0.1, label_y)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker_container.add_child(label)

	var settlement := ColorRect.new()
	settlement.size = Vector2(TILE_SIZE, TILE_SIZE) - Vector2(margin, margin) * 2
	settlement.position = Vector2(SETTLEMENT_POSITION) * TILE_SIZE + Vector2(margin, margin)
	settlement.color = SETTLEMENT_COLOR
	settlement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_container.add_child(settlement)

	if not GameSession.has_deployed_party():
		return

	var party := ColorRect.new()
	party.size = Vector2(TILE_SIZE, TILE_SIZE) - Vector2(margin, margin) * 2
	party.position = Vector2(party_position) * TILE_SIZE + Vector2(margin, margin)
	party.color = PARTY_COLOR
	party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_container.add_child(party)


func _draw_routes() -> void:
	if not is_inside_tree():
		return

	for child in route_container.get_children():
		child.queue_free()

	var committed_route := GameSession.get_deployed_party_route()
	_draw_route_path(committed_route, ROUTE_SEGMENT_COLOR, ROUTE_TARGET_COLOR)

	if _has_route_affordance() and not hover_route.is_empty() and hover_route != committed_route:
		_draw_route_path(hover_route, HOVER_ROUTE_SEGMENT_COLOR, HOVER_ROUTE_TARGET_COLOR)


func _draw_route_path(
	route: Array[Vector2i], segment_color: Color, target_color: Color
) -> void:
	if route.is_empty():
		return

	var segment_margin := TILE_SIZE * 0.35
	for step in route:
		var segment := ColorRect.new()
		segment.size = Vector2(TILE_SIZE, TILE_SIZE) - Vector2(segment_margin, segment_margin) * 2
		segment.position = Vector2(step) * TILE_SIZE + Vector2(segment_margin, segment_margin)
		segment.color = segment_color
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		route_container.add_child(segment)

	var destination := route[route.size() - 1]
	var target_margin := TILE_SIZE * 0.1
	var target := ColorRect.new()
	target.size = Vector2(TILE_SIZE, TILE_SIZE) - Vector2(target_margin, target_margin) * 2
	target.position = Vector2(destination) * TILE_SIZE + Vector2(target_margin, target_margin)
	target.color = target_color
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_container.add_child(target)

	var label := Label.new()
	label.text = tr("world_map.arrival_turns") % route.size()
	var label_y := maxf(destination.y * TILE_SIZE - TILE_SIZE * 0.6, EXPEDITION_LABEL_MIN_Y)
	label.position = Vector2(destination.x * TILE_SIZE + TILE_SIZE * 0.1, label_y)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_container.add_child(label)


func _update_turn_label() -> void:
	if not is_inside_tree():
		return
	turn_label.text = tr("world_map.turn") % GameSession.world_turn


func _refresh_information_panel() -> void:
	if not is_inside_tree():
		return
	# World Map has no separate row-selection concept; "the party" is the
	# single deployed party, so its click-to-select toggle simply chooses
	# whether the panel requests that party's contextual summary.
	if party_selected:
		information_panel.refresh_party(GameSession.selected_party_id, GameSession.pending_reward)
	else:
		information_panel.refresh()


## Mirrors the same signal-forwarding pattern parties.gd and party_details.gd
## use for their own View buttons: the panel never navigates itself, so this
## screen decides that pressing View Party opens Party Details.
func _on_information_panel_party_selected(party_id: String) -> void:
	GameManager.go_to_party_details(party_id)


func _update_highlights() -> void:
	if not is_inside_tree():
		return

	for child in highlight_container.get_children():
		child.queue_free()

	if not GameSession.has_deployed_party() or not party_selected:
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
