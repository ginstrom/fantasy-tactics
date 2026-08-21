extends Node2D

signal board_changed
signal encounter_activated(encounter_id: String)
signal settlement_activated(location_id: String)

const GridScript := preload("res://scripts/battle/grid.gd")

const GRID_WIDTH := 7
const GRID_HEIGHT := 7
const TILE_SIZE := 64
const PARTY_MOVE_RANGE := 1

const SETTLEMENT_ID := "starting_settlement"
const SETTLEMENT_POSITION := Vector2i(3, 3)
const PARTY_START := SETTLEMENT_POSITION

const SETTLEMENT_COLOR := Color(0.5, 0.7, 0.4)
const ENCOUNTER_COLOR := Color(0.9, 0.6, 0.2)
const SELECTION_RING_COLOR := Color(1, 1, 1, 0.6)
const LEGAL_MOVE_COLOR := Color(0.4, 0.9, 0.4, 0.5)
const ROUTE_SEGMENT_COLOR := Color(0.9, 0.9, 0.3, 0.6)
const ROUTE_TARGET_COLOR := Color(0.9, 0.9, 0.3, 0.9)
const HOVER_ROUTE_SEGMENT_COLOR := Color(0.4, 0.9, 0.9, 0.5)
const HOVER_ROUTE_TARGET_COLOR := Color(0.4, 0.9, 0.9, 0.8)
## World Map Fog & Strategic Scouting Visuals (Technical Design §4,
## docs/plans/2026-08-18-core-loop-and-engagement/
## 07-visual-perspective-and-tactical-polish.md): once a Scout has earned
## the star-count reveal (_get_marker_star_text() below), render it in a
## high-contrast gold with a dark outline so it stays sharp/legible over the
## marker/tile art -- purely a presentation change, layered on top of the
## same reveal gating GameSession.get_party_scouting_intel() already
## enforces (see that function's own doc comment); it changes nothing about
## when or what is revealed.
const STAR_LABEL_COLOR := Color(1.0, 0.85, 0.2)
const STAR_LABEL_OUTLINE_COLOR := Color(0.1, 0.08, 0.02)
const STAR_LABEL_OUTLINE_SIZE := 4
const STAR_LABEL_FONT_SIZE := 18

# Expedition labels sit above their marker by default. This floor keeps a
# label on grid row 0 (or any row close enough to the top) from rendering
# off the top edge of the viewport.
const EXPEDITION_LABEL_MIN_Y := 112.0

var grid
var party_position: Vector2i = PARTY_START
var party_selected: bool = false
var hover_route: Array[Vector2i] = []
var repathing: bool = false
## The active-encounter instance id currently under the mouse, or "" when
## the cursor isn't over one (see _update_hovered_encounter()). Drives
## InformationPanel's Scout-intel preview (docs/plans/2026-08-18-core-loop-
## and-engagement/04-cleric-class-and-scout-reconnaissance.md) whenever the
## party itself isn't selected -- party_selected always wins so hovering an
## encounter while mid-route-planning never clobbers the party summary.
var hovered_encounter_id: String = ""

## The encounter_activated id awaiting a player choice on the arrival panel,
## or "" when the panel is closed (see _on_encounter_activated()/_close_
## arrival_panel()). Both the Enter and Withdraw handlers read this instead
## of re-deriving the id from party_position, since the panel may still be
## open after a later click elsewhere moved party_position on.
var pending_arrival_encounter_id: String = ""

@onready var board: Node2D = $Board
@onready var tile_container: Node2D = $Board/Tiles
@onready var highlight_container: Node2D = $Board/Highlights
@onready var marker_container: Node2D = $Board/Markers
@onready var route_container: Node2D = $Board/Routes
@onready var turn_label: Label = %TurnLabel
@onready var end_turn_button: Button = %EndTurnButton
@onready var information_panel: PanelContainer = %InformationPanel
@onready var campaign_guide: PanelContainer = %CampaignGuide
@onready var campaign_objective_banner: PanelContainer = %CampaignObjectiveBanner
@onready var hint_label: Label = %Hint
@onready var arrival_panel: PanelContainer = %ArrivalPanel


func _ready() -> void:
	AudioManager.play_music("music_world_map")
	grid = GridScript.new(GRID_WIDTH, GRID_HEIGHT)
	party_position = GameSession.get_deployed_party_position()
	information_panel.party_selected.connect(_on_information_panel_party_selected)
	_draw_tiles()
	_draw_markers()
	_draw_routes()
	_update_highlights()
	_update_turn_label()
	_refresh_turn_controls()
	_refresh_information_panel()
	_refresh_campaign_guide()
	campaign_objective_banner.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()
		return

	if event is InputEventMouseMotion:
		var tile_pos := _to_grid_position(board.make_input_local(event).position)
		_update_hover_route(tile_pos)
		_update_hovered_encounter(tile_pos)
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

	var click_local_pos: Vector2 = board.make_input_local(event).position
	var tile_pos := _to_grid_position(click_local_pos)
	if not grid.is_in_bounds(tile_pos):
		return

	get_viewport().set_input_as_handled()
	if OS.is_debug_build():
		print(
			"[world_map click] mouse_local=%s tile_pos=%s party_position=%s party_selected=%s has_deployed_party=%s route=%s"
			% [
				click_local_pos, tile_pos, party_position, party_selected,
				GameSession.has_deployed_party(), GameSession.get_deployed_party_route()
			]
		)
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
	if GameSession.selected_encounter != "" and GameSession.selected_encounter != encounter_id:
		return false

	encounter_activated.emit(encounter_id)
	return true


func _expedition_id_at(pos: Vector2i) -> String:
	for instance in GameSession.get_active_encounters():
		if instance.position == pos:
			return instance.id
	var objective_marker := _current_campaign_objective_marker()
	if not objective_marker.is_empty() and objective_marker.position == pos:
		return objective_marker.id
	return ""


## The World Map marker for the current campaign_objective_id's expedition,
## sourced independently of GameSession.active_encounters/
## get_active_encounters() -- see GameSession.reset() (only ever seeds the
## two sandbox templates, goblin_camp/orc_outpost, into active_encounters)
## and enter_encounter()'s authored-id gate (can_enter_encounter() checks
## unlocked_authored_encounters/completed_encounters directly; an authored
## node is never turned into a live active-encounter instance in normal
## play, only by a debug scenario that seeds one explicitly). Without this,
## a fresh campaign has no clickable route onto any of the 12 authored nodes
## at all -- only the debug menu's direct battlefield jump could reach one.
## Deliberately never appended into active_encounters itself: doing so would
## count against ENCOUNTER_INSTANCE_CAP and the sandbox vacancy-refill
## economy (_start_encounter_vacancy()/_advance_encounter_vacancies()), both
## of which assume active_encounters holds only sandbox instances.
## GameSession.get_expedition()'s own instance-then-template fallback is what
## lets every other authored-id caller (get_threat_stars(),
## get_party_scouting_intel()) already work correctly against this id with
## no changes of their own, whether or not it is a live active-encounter
## instance. Returns {} once the campaign is complete (campaign_objective_id
## is "" from that point on -- see GameSession.get_current_campaign_
## objective()), so no such marker renders once there is no current
## objective left to point at.
func _current_campaign_objective_marker() -> Dictionary:
	var objective := GameSession.get_current_campaign_objective()
	var encounter_id: String = objective.get("encounter_id", "")
	if encounter_id == "":
		return {}
	var expedition := GameSession.get_expedition(encounter_id)
	if not expedition.has("position"):
		return {}
	return {"id": encounter_id, "position": expedition.position}


func _get_difficulty_stars(difficulty: int) -> String:
	# Clamp difficulty to the 1-5 range GameSession.get_threat_stars() itself
	# clamps to (see that function's own doc comment) and return a star
	# string.
	var clamped := clampi(difficulty, 1, 5)
	return "★".repeat(clamped)


## Per index.md's locked decision, an encounter marker's difficulty stars are
## gated behind Scout reconnaissance exactly like enemy composition -- both
## are withheld until the deployed party contains a Scout within Manhattan
## distance 3 of this encounter (see GameSession.get_party_scouting_intel()).
## Returns "" (no stars drawn) when that intel hasn't been earned yet. Once
## intel is earned, the rendered star count is GameSession.get_threat_
## stars()' dynamic 1-5 rating (docs/plans/2026-08-18-core-loop-and-
## engagement/05-authored-encounters-and-final-boss.md) -- which rises with
## world turns elapsed on top of the encounter's own base difficulty -- not
## the static intel.danger_tier value (still used elsewhere, e.g. to decide
## whether intel has been earned at all).
func _get_marker_star_text(encounter_id: String) -> String:
	var intel := GameSession.get_party_scouting_intel(GameSession.selected_party_id, encounter_id)
	if intel.is_empty() or not bool(intel.has_intel):
		return ""
	return _get_difficulty_stars(GameSession.get_threat_stars(encounter_id))


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
	repathing = false


func _has_route_affordance() -> bool:
	if not party_selected or not GameSession.has_deployed_party():
		return false
	return GameSession.get_deployed_party_route().is_empty() or repathing


func _update_hover_route(tile_pos: Vector2i) -> void:
	if not _has_route_affordance() or not grid.is_in_bounds(tile_pos):
		hover_route = []
	else:
		hover_route = build_route(party_position, tile_pos)
	_draw_routes()


## Scout strategic reconnaissance preview (see hovered_encounter_id's own doc
## comment): re-resolves the information panel only when the hovered
## encounter id actually changes, so mouse motion within the same tile
## doesn't thrash a refresh every frame.
func _update_hovered_encounter(tile_pos: Vector2i) -> void:
	var encounter_id := _expedition_id_at(tile_pos)
	if encounter_id == hovered_encounter_id:
		return
	hovered_encounter_id = encounter_id
	_refresh_information_panel()


func _on_end_turn_pressed() -> void:
	if GameSession.selected_encounter != "":
		return
	if OS.is_debug_build():
		print(
			"[world_map end_turn] before: party_position=%s route=%s"
			% [party_position, GameSession.get_deployed_party_route()]
		)
	GameSession.end_world_turn()
	party_position = GameSession.get_deployed_party_position()
	if OS.is_debug_build():
		print(
			"[world_map end_turn] after: party_position=%s route=%s"
			% [party_position, GameSession.get_deployed_party_route()]
		)
	_check_for_arrival()
	_draw_markers()
	_draw_routes()
	_update_highlights()
	_update_turn_label()
	_refresh_turn_controls()
	_refresh_campaign_guide()
	board_changed.emit()


func _handle_tile_click(tile_pos: Vector2i) -> void:
	if not GameSession.has_deployed_party():
		# The World Map remains reachable from the pause menu before a party is
		# formed. Its always-visible settlement marker is the recovery route
		# back to Encampment in that state.
		if tile_pos == SETTLEMENT_POSITION:
			settlement_activated.emit(SETTLEMENT_ID)
		return

	if tile_pos == party_position:
		if not party_selected:
			party_selected = true
			_update_highlights()
			_refresh_information_panel()
			_refresh_campaign_guide()
			return

		if not GameSession.get_deployed_party_route().is_empty():
			if repathing:
				# A second reclick while already repathing means the player wants
				# out of the route entirely, not just to preview a new one — clear
				# it and fall through to this tile's own activation checks below.
				GameSession.clear_deployed_party_route()
				repathing = false
				hover_route = []
				_draw_routes()
				_update_highlights()
			else:
				# Reclicking a routed party must not discard it — it stays visible
				# while a new one can be previewed/committed (see repathing).
				repathing = true
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
			_refresh_campaign_guide()
			return

		party_selected = false
		hover_route = []
		_draw_routes()
		_update_highlights()
		_refresh_information_panel()
		_refresh_campaign_guide()
		return

	if not party_selected:
		return

	if tile_pos == get_route_destination():
		if GameSession.take_next_route_step():
			party_position = GameSession.get_deployed_party_position()
			hover_route = []
			repathing = false
			_check_for_arrival()
			_draw_markers()
			_draw_routes()
			_update_highlights()
			_refresh_campaign_guide()
			board_changed.emit()
		return

	var route := build_route(party_position, tile_pos)
	if not route.is_empty() and GameSession.set_deployed_party_route(route):
		hover_route = []
		repathing = false
		_draw_markers()
		_draw_routes()
		_update_highlights()
		_refresh_campaign_guide()


## Manual playtesting found that a party who *walks* onto an available
## encounter -- an automatic World Map Turn route step, or a manual one-tile
## step onto a route's own destination tile -- never saw the arrival panel
## at all, since only an explicit re-click on an already-standing-there
## party (try_activate_current_tile(), still used by that path) opened it.
## Called after every party-position-changing move; mirrors try_activate_
## current_tile()'s own gating exactly, but opens the panel directly instead
## of requiring a further click to notice arrival.
func _check_for_arrival() -> void:
	# Several existing tests build a bare WorldMapScript instance that is
	# never added to the tree (see _make_world_map() in test_world_map.gd),
	# so @onready arrival_panel never resolves -- mirrors the same guard
	# _draw_markers()/_update_highlights()/_refresh_turn_controls() already
	# use for exactly that reason.
	if not is_inside_tree() or arrival_panel.visible:
		return
	var encounter_id := _expedition_id_at(party_position)
	if encounter_id == "" or GameSession.is_encounter_complete(encounter_id):
		return
	if GameSession.selected_encounter != "" and GameSession.selected_encounter != encounter_id:
		return
	_on_encounter_activated(encounter_id)


## Pre-battle Withdraw (docs/plans/2026-08-21-stage-1-campaign-spine/
## 01-pre-battle-withdraw.md): arrival at an available encounter now opens
## the arrival panel instead of entering battle directly -- Enter/Withdraw/
## Cancel below decide what happens next.
func _on_encounter_activated(encounter_id: String) -> void:
	pending_arrival_encounter_id = encounter_id
	arrival_panel.visible = true


func _on_arrival_enter_pressed() -> void:
	var encounter_id := pending_arrival_encounter_id
	_close_arrival_panel()
	GameManager.enter_battle(encounter_id)


func _on_arrival_withdraw_pressed() -> void:
	var encounter_id := pending_arrival_encounter_id
	_close_arrival_panel()
	if GameManager.withdraw_from_encounter(encounter_id) == OK:
		hint_label.text = tr("world_map.arrival.withdraw_summary")
	party_position = GameSession.get_deployed_party_position()
	_draw_markers()
	_draw_routes()
	_update_highlights()
	_refresh_information_panel()
	_refresh_campaign_guide()


func _on_arrival_cancel_pressed() -> void:
	_close_arrival_panel()


func _close_arrival_panel() -> void:
	pending_arrival_encounter_id = ""
	arrival_panel.visible = false


func _on_settlement_activated(_location_id: String) -> void:
	GameManager.return_party_to_encampment()


func _to_grid_position(local_pos: Vector2) -> Vector2i:
	return Vector2i(floori(local_pos.x / TILE_SIZE), floori(local_pos.y / TILE_SIZE))


## Placeholder sprites (docs/plans/2026-08-20-placeholder-sprites/
## 03-world-map-sprites-and-acceptance.md): each ground tile is a
## catalog-backed Sprite2D at an unchanged Vector2(x, y) * TILE_SIZE
## position -- `centered = false` keeps that position meaning the tile's
## top-left corner exactly as the ColorRect it replaces did, so nothing else
## in this file (route/highlight/marker placement, _to_grid_position()) needs
## to be recomputed. Kenney's 16px ground art at the required integral 4x
## scale exactly fills one 64px TILE_SIZE cell. Mirrors battle_controller.gd's
## own _draw_tiles() (Step 2 of this plan) for the identical reason.
func _draw_tiles() -> void:
	for child in tile_container.get_children():
		child.queue_free()

	for y in grid.height:
		for x in grid.width:
			var tile := Sprite2D.new()
			tile.texture = SpriteCatalog.get_tile_texture((x + y) % 2 == 0)
			tile.centered = false
			tile.scale = Vector2(4, 4)
			tile.position = Vector2(x, y) * TILE_SIZE
			tile_container.add_child(tile)


## Draws one encounter marker + its star label at position, shared by both
## the sandbox active_encounters loop and the current-campaign-objective
## marker in _draw_markers() below -- the two sources render identically and
## behave identically for clicking/hovering (_expedition_id_at() matches
## both the same way).
func _draw_expedition_marker(encounter_id: String, tile_pos: Vector2i, margin: float) -> void:
	var encounter := ColorRect.new()
	encounter.size = Vector2(TILE_SIZE, TILE_SIZE) - Vector2(margin, margin) * 2
	encounter.position = Vector2(tile_pos) * TILE_SIZE + Vector2(margin, margin)
	encounter.color = ENCOUNTER_COLOR
	encounter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_container.add_child(encounter)

	var label := Label.new()
	label.text = _get_marker_star_text(encounter_id)
	var label_y := maxf(tile_pos.y * TILE_SIZE - TILE_SIZE * 0.6, EXPEDITION_LABEL_MIN_Y)
	label.position = Vector2(tile_pos.x * TILE_SIZE + TILE_SIZE * 0.1, label_y)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# High-contrast palette (Technical Design §4): only applied once Scout
	# intel has actually revealed a star count -- an empty (unrevealed)
	# label stays in the theme's default color rather than drawing an
	# eye-catching gold outline around nothing.
	if label.text != "":
		label.add_theme_color_override("font_color", STAR_LABEL_COLOR)
		label.add_theme_color_override("font_outline_color", STAR_LABEL_OUTLINE_COLOR)
		label.add_theme_constant_override("outline_size", STAR_LABEL_OUTLINE_SIZE)
		label.add_theme_font_size_override("font_size", STAR_LABEL_FONT_SIZE)
	marker_container.add_child(label)


func _draw_markers() -> void:
	if not is_inside_tree():
		return

	for child in marker_container.get_children():
		child.queue_free()

	var margin := TILE_SIZE * 0.2

	# Only active encounter instances are ever drawn — a cleared instance is
	# removed from GameSession.active_encounters (see GameSession.
	# complete_current_encounter) and simply vanishes rather than lingering as
	# a completed marker.
	var active_ids: Dictionary = {}
	for record in GameSession.get_active_encounters():
		active_ids[record.id] = true
		_draw_expedition_marker(record.id, record.position, margin)

	# The current campaign objective's own authored node (see
	# _current_campaign_objective_marker()'s doc comment) is drawn as its own
	# marker in addition to the sandbox active_encounters above -- unless a
	# debug scenario already seeded it directly into active_encounters, in
	# which case the loop above already drew it and this would double it up.
	var objective_marker := _current_campaign_objective_marker()
	if not objective_marker.is_empty() and not active_ids.has(objective_marker.id):
		_draw_expedition_marker(objective_marker.id, objective_marker.position, margin)

	var settlement := ColorRect.new()
	settlement.size = Vector2(TILE_SIZE, TILE_SIZE) - Vector2(margin, margin) * 2
	settlement.position = Vector2(SETTLEMENT_POSITION) * TILE_SIZE + Vector2(margin, margin)
	settlement.color = SETTLEMENT_COLOR
	settlement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_container.add_child(settlement)

	if not GameSession.has_deployed_party():
		return

	# Placeholder sprites (docs/plans/2026-08-20-placeholder-sprites/
	# 03-world-map-sprites-and-acceptance.md): a catalog-backed Sprite2D at
	# the required integral 4x nearest-neighbor scale, horizontally centered
	# on the party's tile and bottom-anchored so its feet meet the tile's own
	# bottom edge -- there is no separate shadow layer on the World Map (only
	# the Battlefield has one), so the tile's bottom edge is the baseline
	# itself, unlike battle_controller.gd's shadow-relative anchor. A
	# Sprite2D carries no Control mouse_filter at all, so -- unlike the
	# ColorRect it replaces -- it can never intercept a click; it is
	# inherently non-interactive.
	var party_sprite := Sprite2D.new()
	party_sprite.name = "PartySprite"
	party_sprite.texture = SpriteCatalog.get_unit_texture("world_party")
	party_sprite.scale = Vector2(4, 4)
	var tile_origin: Vector2 = Vector2(party_position) * TILE_SIZE
	# Integral nearest-neighbor placement (this plan's own invariant -- see
	# docs/plans/2026-08-20-placeholder-sprites/index.md's "no filtering or
	# fractional placement" line): at scale.y = 4, texture.get_height() *
	# scale.y / 2.0 is 2 * height, which is an integer for any integer
	# texture height, so this round() is a permanent no-op given integral
	# source art and an even 4x scale factor -- not a guard against any
	# particular future art size. It is kept only for consistency with the
	# equivalent (and load-bearing) rounding in battle_controller.gd's
	# _draw_units(), where the shadow-baseline math is not integral.
	party_sprite.position = Vector2(
		tile_origin.x + TILE_SIZE / 2.0,
		round(tile_origin.y + TILE_SIZE - (party_sprite.texture.get_height() * party_sprite.scale.y) / 2.0)
	)
	marker_container.add_child(party_sprite)


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


func _refresh_turn_controls() -> void:
	if not is_inside_tree():
		return
	# An open arrival panel is an unresolved player choice -- a further World
	# Map Turn must not be able to silently walk the party past it (see
	# _check_for_arrival()).
	end_turn_button.disabled = GameSession.selected_encounter != "" or arrival_panel.visible


func _refresh_information_panel() -> void:
	if not is_inside_tree():
		return
	# World Map has no separate row-selection concept; "the party" is the
	# single deployed party, so its click-to-select toggle simply chooses
	# whether the panel requests that party's contextual summary. A hovered
	# encounter (see hovered_encounter_id) only wins when the party itself
	# isn't selected, so mid-route-planning hover never clobbers the party
	# summary the player is actively looking at.
	if party_selected:
		information_panel.refresh_party(GameSession.selected_party_id, GameSession.pending_reward)
	elif hovered_encounter_id != "":
		information_panel.refresh_encounter(GameSession.selected_party_id, hovered_encounter_id)
	else:
		information_panel.refresh()


## Mirrors the same signal-forwarding pattern parties.gd and party_details.gd
## use for their own View buttons: the panel never navigates itself, so this
## screen decides that pressing View Party opens Party Details.
func _on_information_panel_party_selected(party_id: String) -> void:
	GameManager.go_to_party_details(party_id)


func _refresh_campaign_guide() -> void:
	if not is_inside_tree():
		return
	campaign_guide.refresh()


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
