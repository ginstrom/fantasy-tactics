extends Node2D

signal board_changed
## Emitted from try_attack_selected_unit() exactly once per enemy-side unit,
## at the moment it is defeated, carrying that Unit instance. Battlefield
## connects to this to award kill XP per kill; it fires once per defeated
## unit (not once per battle — a battle can field multiple enemies), so
## Battlefield keys its award guard on the emitted unit's identity rather
## than treating the signal as a single one-shot battle event.
signal enemy_defeated(unit)

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

const GROUP := "battle_controller"

const UNIT_MOVE_RANGE := 3
const SUPER_POWER_MOVE_RANGE := 100
const SUPER_POWER_ATTACK_DAMAGE := 100
const SUPER_POWER_HIT_CHANCE := 1.0
const ENEMY_STEP_MOVE := "move"
const ENEMY_STEP_ATTACK := "attack"
const PLAYER_START_POSITIONS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 0),
]
const PLAYER_COLORS: Array[Color] = [
	Color(0.3, 0.5, 0.9), Color(0.3, 0.8, 0.5), Color(0.85, 0.8, 0.3),
	Color(0.7, 0.4, 0.85), Color(0.9, 0.6, 0.3),
]
const ENEMY_START_POSITIONS: Array[Vector2i] = [
	Vector2i(5, 5), Vector2i(4, 5), Vector2i(5, 4), Vector2i(3, 5),
	Vector2i(4, 4), Vector2i(5, 3), Vector2i(3, 4), Vector2i(4, 3),
]
const ENEMY_COLOR := Color(0.9, 0.4, 0.3)
const MIN_HIT_CHANCE := 0.05

var grid
var units: Array = []
var _player_adventurer_ids: Array[String] = []
var selected_unit = null
var active_side: int = Side.PLAYER
var input_locked: bool = false
var hit_roll: Callable = func() -> float: return randf()
var damage_roll: Callable = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
var last_attack_result: Dictionary = {}

@onready var tile_container: Node2D = $Tiles
@onready var unit_container: Node2D = $Units
@onready var highlight_container: Node2D = $Highlights


func _ready() -> void:
	add_to_group(GROUP)
	grid = GridScript.new(GRID_WIDTH, GRID_HEIGHT)
	var enemy_stats := _get_enemy_stats()
	_player_adventurer_ids = _get_player_adventurer_ids()
	units = []
	for index in mini(_player_adventurer_ids.size(), PLAYER_START_POSITIONS.size()):
		var adventurer_id: String = _player_adventurer_ids[index]
		var damage_range: Vector2i = GameSession.get_effective_weapon_damage_range(adventurer_id)
		units.append(UnitScript.new(
			PLAYER_START_POSITIONS[index], PLAYER_COLORS[index % PLAYER_COLORS.size()], Side.PLAYER,
			GameSession.get_effective_move_range(adventurer_id),
			GameSession.get_effective_max_health(adventurer_id),
			damage_range.x,
			damage_range.y,
			GameSession.get_effective_hit_chance(adventurer_id),
			GameSession.get_effective_weapon_name(adventurer_id),
			adventurer_id,
			GameSession.get_effective_defense(adventurer_id),
			GameSession.get_effective_resistance(adventurer_id)
		))
	var enemy_count: int = enemy_stats.get("count", 1)
	for index in mini(enemy_count, ENEMY_START_POSITIONS.size()):
		units.append(UnitScript.new(
			ENEMY_START_POSITIONS[index], ENEMY_COLOR, Side.ENEMY, UNIT_MOVE_RANGE,
			enemy_stats.max_health, enemy_stats.attack_damage, enemy_stats.attack_damage, enemy_stats.hit_chance,
			tr(enemy_stats.attack_name_key), "", 0, 0, enemy_stats.get("kill_xp", 0)
		))
	# Round one is a new round too: open it with the first party member
	# already selected rather than forcing a manual pick.
	selected_unit = _first_living_player_unit()
	_draw_tiles()
	_draw_units()
	_update_highlights()


func _get_enemy_stats() -> Dictionary:
	var expedition: Dictionary = GameSession.get_expedition(GameSession.selected_encounter)
	if expedition.is_empty():
		# Scene-isolated tests instantiate the battlefield with no selected encounter;
		# fall back to the Goblin Camp enemy so those scenarios keep working.
		expedition = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	return expedition.enemy


## One player Unit is fielded per party member (see the campaign progression
## design doc's "Fielding" section), in stable party order. Scene-isolated
## tests that instantiate the battlefield with no selected party (or an empty
## one) fall back to the default Warrior, matching _get_enemy_stats()'s
## fallback pattern.
func _get_player_adventurer_ids() -> Array[String]:
	var party: Dictionary = GameSession.get_selected_party()
	if party.is_empty() or party.member_ids.is_empty():
		return [GameSession.WARRIOR_ID]
	return party.member_ids


const MOVE_KEY_DIRECTIONS := {
	KEY_W: Vector2i.UP, KEY_A: Vector2i.LEFT, KEY_S: Vector2i.DOWN, KEY_D: Vector2i.RIGHT,
}
const NUMBER_KEYS := {KEY_1: 1, KEY_2: 2, KEY_3: 3, KEY_4: 4, KEY_5: 5}


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_input(event)
	elif event is InputEventKey:
		_handle_key_input(event)


func _handle_mouse_input(event: InputEventMouseButton) -> void:
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var tile_pos := _to_grid_position(make_input_local(event).position)
	if not grid.is_in_bounds(tile_pos):
		return
	get_viewport().set_input_as_handled()
	_handle_tile_click(tile_pos)


func _handle_key_input(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	if MOVE_KEY_DIRECTIONS.has(event.keycode):
		get_viewport().set_input_as_handled()
		if try_step_selected_unit(MOVE_KEY_DIRECTIONS[event.keycode]):
			_draw_units()
			_select_unit_after_action()
		return
	if NUMBER_KEYS.has(event.keycode):
		get_viewport().set_input_as_handled()
		select_unit_by_number_key(NUMBER_KEYS[event.keycode])


func get_unit_at(pos: Vector2i):
	for unit in units:
		if unit.grid_position == pos:
			return unit
	return null


func _move_distances(unit) -> Dictionary:
	var is_blocked := func(pos: Vector2i) -> bool: return get_unit_at(pos) != null
	return grid.get_tile_distances(unit.grid_position, unit.moves_remaining, is_blocked)


func get_legal_moves(unit) -> Array[Vector2i]:
	if unit.moves_remaining <= 0:
		return []
	var moves: Array[Vector2i] = []
	moves.assign(_move_distances(unit).keys())
	return moves


func try_move_selected_unit(target: Vector2i) -> bool:
	if selected_unit == null:
		return false
	if selected_unit.side != active_side:
		return false
	if not target in get_legal_moves(selected_unit):
		return false

	var distances := _move_distances(selected_unit)
	selected_unit.grid_position = target
	selected_unit.moves_remaining -= distances[target]
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
	var effective_hit_chance: float = maxf(selected_unit.hit_chance - target.defense / 100.0, MIN_HIT_CHANCE)
	var hit: bool = hit_roll.call() < effective_hit_chance
	var damage: int = 0
	if hit:
		var raw_damage: int = damage_roll.call(selected_unit.damage_min, selected_unit.damage_max)
		damage = int(round(raw_damage * (1.0 - target.resistance / 100.0)))
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
	if defeated and target.side == Side.ENEMY:
		enemy_defeated.emit(target)
	return true


func try_step_selected_unit(direction: Vector2i) -> bool:
	if input_locked:
		return false
	if selected_unit == null or not selected_unit.is_alive():
		return false
	if selected_unit.side != active_side:
		return false
	var target: Vector2i = selected_unit.grid_position + direction
	if not grid.is_in_bounds(target):
		return false
	var occupant = get_unit_at(target)
	if occupant != null:
		if occupant.side == selected_unit.side:
			return false
		return try_attack_selected_unit(target)
	if selected_unit.moves_remaining <= 0:
		return false
	selected_unit.grid_position = target
	selected_unit.moves_remaining -= 1
	last_attack_result = {}
	return true


func select_unit_by_adventurer_id(adventurer_id: String) -> bool:
	if input_locked or active_side != Side.PLAYER:
		return false
	var unit = _get_unit_by_adventurer_id(adventurer_id)
	if unit == null or not unit.is_alive() or unit.side != Side.PLAYER:
		return false
	_select_unit(unit)
	return true


func select_unit_by_number_key(key_number: int) -> bool:
	var slot_index := key_number - 1
	if slot_index < 0 or slot_index >= _player_adventurer_ids.size():
		return false
	return select_unit_by_adventurer_id(_player_adventurer_ids[slot_index])


func _get_unit_by_adventurer_id(adventurer_id: String):
	for unit in units:
		if unit.adventurer_id == adventurer_id:
			return unit
	return null


func apply_super_power() -> void:
	for unit in units:
		if unit.side == Side.PLAYER:
			unit.move_range = SUPER_POWER_MOVE_RANGE
			unit.moves_remaining = SUPER_POWER_MOVE_RANGE
			unit.damage_min = SUPER_POWER_ATTACK_DAMAGE
			unit.damage_max = SUPER_POWER_ATTACK_DAMAGE
			unit.hit_chance = SUPER_POWER_HIT_CHANCE
	_update_highlights()
	board_changed.emit()


func end_turn() -> void:
	active_side = Side.ENEMY if active_side == Side.PLAYER else Side.PLAYER
	for unit in units:
		if unit.side == active_side:
			unit.moves_remaining = unit.move_range
			unit.has_acted = false
	# A new round starts once control returns to the player; open it with the
	# first party member already selected rather than forcing a manual pick.
	_select_unit(_first_living_player_unit() if active_side == Side.PLAYER else null)


func _first_living_player_unit():
	for adventurer_id in _player_adventurer_ids:
		var unit = _get_unit_by_adventurer_id(adventurer_id)
		if unit != null and unit.is_alive():
			return unit
	return null


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
	if selected_unit.moves_remaining <= 0 and selected_unit.has_acted:
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
