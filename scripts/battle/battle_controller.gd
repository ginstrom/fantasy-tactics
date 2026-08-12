extends Node2D

signal board_changed
## Emitted from try_attack_selected_unit() exactly once per enemy-side unit,
## at the moment it is defeated, carrying that Unit instance. Battlefield
## connects to this to award kill XP per kill; it fires once per defeated
## unit (not once per battle — a battle can field multiple enemies), so
## Battlefield keys its award guard on the emitted unit's identity rather
## than treating the signal as a single one-shot battle event.
signal enemy_defeated(unit)
## Emitted whenever get_focused_unit()'s result changes -- either a live
## hover moved onto/off of a unit, or the pinned inspected_unit changed
## (see _select_unit()/_handle_tile_click()). Carries the new focused unit,
## or null when nothing is focused. Battlefield connects this to drive the
## new right-side unit detail panel; it never affects selection, movement,
## or combat.
signal unit_focus_changed(unit)
## Emitted after a successful hit has applied damage and any declarative rune
## effects have resolved. Consumers can present the outcome without owning
## combat rules.
signal completed_hit(result)

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

const BASE_ACTION_POINTS := 6
const MOVE_ACTION_POINT_COST := 1
const BASIC_ATTACK_ACTION_POINT_COST := 3
const ITEM_ACTION_POINT_COST := 2
const SUPER_POWER_ACTION_POINTS := 100
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
const THORN_RUNE_ID := "thorn"
const PARALYZED_STATUS_ID := "paralyzed"
const THORN_TRIGGER_CHANCE := 0.25

var grid
var units: Array = []
var _player_adventurer_ids: Array[String] = []
var selected_unit = null
var hovered_unit = null
var inspected_unit = null
var active_side: int = Side.PLAYER
var input_locked: bool = false
var hit_roll: Callable = func() -> float: return randf()
var damage_roll: Callable = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
var healing_roll: Callable = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
var rune_trigger_roll: Callable = func() -> float: return randf()
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
		var attack_range: Vector2i = GameSession.get_effective_weapon_attack_range(adventurer_id)
		var player_unit := UnitScript.new(
			PLAYER_START_POSITIONS[index], PLAYER_COLORS[index % PLAYER_COLORS.size()], Side.PLAYER,
			GameSession.get_effective_action_points(adventurer_id),
			GameSession.get_effective_max_health(adventurer_id),
			damage_range.x,
			damage_range.y,
			GameSession.get_effective_hit_chance(adventurer_id),
			GameSession.get_effective_weapon_name(adventurer_id),
			adventurer_id,
			GameSession.get_effective_defense(adventurer_id),
			GameSession.get_effective_resistance(adventurer_id)
		)
		player_unit.attack_min_range = attack_range.x
		player_unit.attack_max_range = attack_range.y
		player_unit.raw_damage_bonus = GameSession.get_effective_weapon_raw_damage_bonus(adventurer_id)
		player_unit.display_name = GameSession.get_adventurer(adventurer_id).get("name", "")
		var armor_instance_id := str(GameSession.get_adventurer(adventurer_id).equipment.armor)
		if GameSession.owned_item_instances.has(armor_instance_id):
			player_unit.rune_id = str(GameSession.owned_item_instances[armor_instance_id].get("rune_id", ""))
		units.append(player_unit)
	var enemy_count: int = enemy_stats.get("count", 1)
	var enemy_type_name: String = tr(enemy_stats.name_key)
	for index in mini(enemy_count, ENEMY_START_POSITIONS.size()):
		var enemy_unit := UnitScript.new(
			ENEMY_START_POSITIONS[index], ENEMY_COLOR, Side.ENEMY, BASE_ACTION_POINTS,
			enemy_stats.max_health, enemy_stats.get("damage_min", int(enemy_stats.get("attack_damage", 1))),
			enemy_stats.get("damage_max", int(enemy_stats.get("attack_damage", 1))), enemy_stats.hit_chance,
			tr(enemy_stats.attack_name_key), "", 0, 0, enemy_stats.get("kill_xp", 0)
		)
		enemy_unit.attack_min_range = int(enemy_stats.get("attack_min_range", 1))
		enemy_unit.attack_max_range = int(enemy_stats.get("attack_max_range", 1))
		enemy_unit.display_name = "%s %d" % [enemy_type_name, index + 1]
		enemy_unit.enemy_type_name = enemy_type_name
		units.append(enemy_unit)
	# Round one is a new round too: open it with the first party member
	# already selected rather than forcing a manual pick. Assigned directly
	# rather than via _select_unit(): that method also emits board_changed,
	# which is already statically connected to Battlefield._on_board_changed()
	# at scene-instantiation time (see battlefield.tscn's [connection] block)
	# -- but children finish _ready() before their parent, so Battlefield's
	# own @onready fields (grid, hint, ...) aren't assigned yet this early,
	# and that emit would crash. inspected_unit is set directly too, so
	# get_focused_unit() is already correct by the time Battlefield connects
	# unit_focus_changed and syncs the unit-info panel itself in its own
	# _ready() (see battlefield.gd, which calls _on_unit_focus_changed()
	# explicitly right after wiring that connection, the same way it already
	# calls _on_board_changed() explicitly for the same reason).
	selected_unit = _first_living_player_unit()
	inspected_unit = selected_unit
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
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
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


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	# make_input_local() requires tree membership; unit tests exercise this
	# against a bare BattleController built via script (see _make_controller()
	# in test_battle_controller.gd), which never enters the tree. Its events
	# are already expressed in this node's local space (see that helper's
	# _motion_event_over()), so falling back to the raw position is correct
	# there and never taken in real play, where the controller is always in
	# the tree by the time input reaches it.
	var local_pos: Vector2 = make_input_local(event).position if is_inside_tree() else event.position
	var tile_pos := _to_grid_position(local_pos)
	var unit = get_unit_at(tile_pos) if grid.is_in_bounds(tile_pos) else null
	_set_hovered_unit(unit)


func _set_hovered_unit(unit) -> void:
	if unit == hovered_unit:
		return
	hovered_unit = unit
	_emit_focus_changed()


## Only called from the one _handle_tile_click() branch where a click
## neither selects your own unit nor resolves as an attack (see that
## method) -- every selection path instead goes through _select_unit(),
## which pins the same way for free.
func _set_inspected_unit(unit) -> void:
	if unit == inspected_unit:
		return
	inspected_unit = unit
	_emit_focus_changed()


func get_focused_unit():
	return hovered_unit if hovered_unit != null else inspected_unit


func _emit_focus_changed() -> void:
	unit_focus_changed.emit(get_focused_unit())


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
	return grid.get_tile_distances(unit.grid_position, unit.action_points_remaining / MOVE_ACTION_POINT_COST, is_blocked)


func get_legal_moves(unit) -> Array[Vector2i]:
	if has_status(unit, PARALYZED_STATUS_ID) or unit.action_points_remaining < MOVE_ACTION_POINT_COST:
		return []
	var moves: Array[Vector2i] = []
	moves.assign(_move_distances(unit).keys())
	return moves


## Combat legality is centralized here so player input, keyboard attacks,
## enemy policy, and later UI previews all use the same range and LoS rules.
func get_legal_attack_targets(unit) -> Array:
	var legal_targets: Array = []
	if unit == null or not unit.is_alive():
		return legal_targets
	var blocking_tiles: Array[Vector2i] = []
	for candidate in units:
		if candidate != unit and candidate.is_alive():
			blocking_tiles.append(candidate.grid_position)
	for target in units:
		if target.side != unit.side and target.is_alive():
			var distance: int = grid.get_manhattan_distance(unit.grid_position, target.grid_position)
			if distance < unit.attack_min_range or distance > unit.attack_max_range:
				continue
			if grid.has_line_of_sight(unit.grid_position, target.grid_position, blocking_tiles):
				legal_targets.append(target)
	return legal_targets


func try_move_selected_unit(target: Vector2i) -> bool:
	if input_locked or selected_unit == null:
		return false
	if has_status(selected_unit, PARALYZED_STATUS_ID):
		return false
	if selected_unit.side != active_side:
		return false
	if not target in get_legal_moves(selected_unit):
		return false

	var distances := _move_distances(selected_unit)
	selected_unit.grid_position = target
	selected_unit.action_points_remaining -= distances[target] * MOVE_ACTION_POINT_COST
	last_attack_result = {}
	return true


func try_attack_selected_unit(target_pos: Vector2i) -> bool:
	if input_locked or selected_unit == null or not selected_unit.is_alive():
		return false
	if has_status(selected_unit, PARALYZED_STATUS_ID):
		return false
	if selected_unit.side != active_side:
		return false
	if selected_unit.action_points_remaining < BASIC_ATTACK_ACTION_POINT_COST:
		return false
	var target = get_unit_at(target_pos)
	if target == null or target.side == selected_unit.side or not target.is_alive():
		return false
	if not get_legal_attack_targets(selected_unit).has(target):
		return false

	selected_unit.action_points_remaining -= BASIC_ATTACK_ACTION_POINT_COST
	var effective_hit_chance: float = maxf(selected_unit.hit_chance - target.defense / 100.0, MIN_HIT_CHANCE)
	var hit: bool = hit_roll.call() < effective_hit_chance
	var damage: int = 0
	if hit:
		var raw_damage: int = damage_roll.call(selected_unit.damage_min, selected_unit.damage_max) + selected_unit.raw_damage_bonus
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
	if hit:
		_dispatch_completed_hit(selected_unit, target)
		completed_hit.emit(last_attack_result)
	if defeated and target.side == Side.ENEMY:
		enemy_defeated.emit(target)
	return true


func try_transfer_selected_item(item_id: String, recipient_adventurer_id: String) -> bool:
	if input_locked or selected_unit == null or not selected_unit.is_alive():
		return false
	if has_status(selected_unit, PARALYZED_STATUS_ID):
		return false
	if selected_unit.side != Side.PLAYER or active_side != Side.PLAYER:
		return false
	if selected_unit.action_points_remaining < ITEM_ACTION_POINT_COST:
		return false
	var recipient = _get_unit_by_adventurer_id(recipient_adventurer_id)
	if recipient == null or recipient.side != Side.PLAYER or not recipient.is_alive():
		return false
	if not GameSession.transfer_carried_item(selected_unit.adventurer_id, recipient_adventurer_id, item_id):
		return false
	selected_unit.action_points_remaining -= ITEM_ACTION_POINT_COST
	last_attack_result = {"type": "item_transfer", "item_id": item_id, "from": selected_unit, "to": recipient}
	return true


func try_use_selected_potion(potion_id: String) -> bool:
	if input_locked or selected_unit == null or not selected_unit.is_alive():
		return false
	if has_status(selected_unit, PARALYZED_STATUS_ID):
		return false
	if selected_unit.side != Side.PLAYER or active_side != Side.PLAYER:
		return false
	if selected_unit.action_points_remaining < ITEM_ACTION_POINT_COST or selected_unit.health >= selected_unit.max_health:
		return false
	var potion := GameSession.get_item_definition(potion_id)
	if str(potion.get("slot", "")) != "potion":
		return false
	if not GameSession.consume_carried_potion(selected_unit.adventurer_id, potion_id):
		return false
	var healed: int = healing_roll.call(int(potion.healing_min), int(potion.healing_max))
	selected_unit.health = mini(selected_unit.max_health, selected_unit.health + healed)
	selected_unit.action_points_remaining -= ITEM_ACTION_POINT_COST
	last_attack_result = {"type": "potion", "potion_id": potion_id, "unit": selected_unit, "healing": healed}
	return true


func try_step_selected_unit(direction: Vector2i) -> bool:
	if input_locked:
		return false
	if selected_unit == null or not selected_unit.is_alive():
		return false
	if has_status(selected_unit, PARALYZED_STATUS_ID):
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
	if selected_unit.action_points_remaining < MOVE_ACTION_POINT_COST:
		return false
	selected_unit.grid_position = target
	selected_unit.action_points_remaining -= MOVE_ACTION_POINT_COST
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
			unit.max_action_points = SUPER_POWER_ACTION_POINTS
			unit.action_points_remaining = SUPER_POWER_ACTION_POINTS
			unit.damage_min = SUPER_POWER_ATTACK_DAMAGE
			unit.damage_max = SUPER_POWER_ATTACK_DAMAGE
			unit.hit_chance = SUPER_POWER_HIT_CHANCE
	_update_highlights()
	board_changed.emit()


func end_turn() -> void:
	active_side = Side.ENEMY if active_side == Side.PLAYER else Side.PLAYER
	if active_side == Side.PLAYER:
		_clear_expired_statuses()
	for unit in units:
		if unit.side == active_side:
			unit.action_points_remaining = unit.max_action_points
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
	# Battlefield locks player input before calling here. Enemy policy still
	# reaches the rules exclusively through the public action methods, so let
	# this synchronous controller-owned loop through and restore the lock before
	# returning control to the view.
	var was_input_locked := input_locked
	input_locked = false
	for unit in units.duplicate():
		if not unit.is_alive() or unit.side != Side.ENEMY:
			continue
		steps.append_array(_take_enemy_unit_actions(unit))
	input_locked = was_input_locked
	selected_unit = null
	return steps


func _take_enemy_unit_actions(unit) -> Array:
	var steps: Array = []
	selected_unit = unit
	if has_status(unit, PARALYZED_STATUS_ID):
		unit.action_points_remaining = 0
		return steps
	var guard: int = int(unit.max_action_points) + 1
	while unit.action_points_remaining > 0 and guard > 0:
		guard -= 1
		var target = _nearest_living_unit(unit.grid_position, Side.PLAYER)
		if target == null:
			break
		if get_legal_attack_targets(unit).has(target):
			if try_attack_selected_unit(target.grid_position):
				steps.append(last_attack_result)
				continue
			break
		var destination := _best_enemy_move(unit, target)
		var from: Vector2i = unit.grid_position
		if destination != from and try_move_selected_unit(destination):
			steps.append({"type": ENEMY_STEP_MOVE, "unit": unit, "from": from, "to": destination})
			continue
		break
	return steps


func _best_enemy_move(unit, target) -> Vector2i:
	if unit.attack_max_range <= 1:
		return _best_move_toward(unit, target.grid_position)
	var distances := _move_distances(unit)
	var best: Vector2i = unit.grid_position
	var best_cost := -1
	for candidate in distances:
		var move_cost: int = int(distances[candidate]) * MOVE_ACTION_POINT_COST
		if unit.action_points_remaining - move_cost < BASIC_ATTACK_ACTION_POINT_COST:
			continue
		if not _can_attack_target_from(unit, candidate, target):
			continue
		if best_cost == -1 or move_cost < best_cost or (move_cost == best_cost and _reading_order_is_earlier(candidate, best)):
			best = candidate
			best_cost = move_cost
	return best if best_cost >= 0 else _best_move_toward(unit, target.grid_position)


func _can_attack_target_from(unit, from_pos: Vector2i, target) -> bool:
	var distance: int = grid.get_manhattan_distance(from_pos, target.grid_position)
	if distance < unit.attack_min_range or distance > unit.attack_max_range:
		return false
	var blocking_tiles: Array[Vector2i] = []
	for candidate in units:
		if candidate != unit and candidate.is_alive():
			blocking_tiles.append(candidate.grid_position)
	return grid.has_line_of_sight(from_pos, target.grid_position, blocking_tiles)


func apply_status(unit, status_id: String) -> bool:
	if unit == null or status_id.is_empty() or has_status(unit, status_id):
		return false
	unit.statuses[status_id] = true
	return true


func has_status(unit, status_id: String) -> bool:
	return unit != null and bool(unit.statuses.get(status_id, false))


func _clear_expired_statuses() -> void:
	for unit in units:
		unit.statuses.erase(PARALYZED_STATUS_ID)


func _dispatch_completed_hit(attacker, defender) -> void:
	if defender.rune_id != THORN_RUNE_ID or has_status(attacker, PARALYZED_STATUS_ID):
		return
	if rune_trigger_roll.call() >= THORN_TRIGGER_CHANCE:
		return
	if apply_status(attacker, PARALYZED_STATUS_ID):
		last_attack_result["thorn_triggered"] = true


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
		_set_inspected_unit(clicked_unit)
		return

	if try_move_selected_unit(tile_pos):
		_draw_units()
		_select_unit_after_action()


func _select_unit_after_action() -> void:
	if selected_unit == null or not selected_unit.is_alive():
		_select_unit(null)
		return
	if selected_unit.action_points_remaining <= 0:
		_select_unit(null)
		return
	_select_unit(selected_unit)


func _select_unit(unit) -> void:
	selected_unit = unit
	_set_inspected_unit(unit)
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
	# Mirrors _update_highlights()'s guard below: unit tests build a bare
	# BattleController via script (not the battlefield scene), so it never
	# enters the tree and its @onready containers are never resolved.
	if not is_inside_tree():
		return
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
