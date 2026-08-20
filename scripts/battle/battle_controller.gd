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
## Emitted whenever action_mode changes -- either via set_action_mode() (the
## Move/Attack action-bar buttons) or the automatic reset to CONTEXTUAL (see
## _select_unit()). Battlefield connects this to drive the action bar's
## toggle/highlight state.
signal action_mode_changed(mode)
## Battle exit signal for the Retreat action (see try_retreat()): fires
## exactly once per retreat, carrying one result Dictionary per living
## player unit at the moment of the retreat -- {"unit", "adventurer_id",
## "distance", "outcome", "hp_loss", "died"}. Battlefield connects this to
## log each outcome, persist aftermath, and hand routing off to
## GameManager.retreat_from_battle().
signal retreat_resolved(results: Array[Dictionary])
## Presentation-layer hook (Technical Design §2, docs/plans/2026-08-18-
## core-loop-and-engagement/07-visual-perspective-and-tactical-polish.md):
## fires once per floating-combat-text event with the Grid-local pixel
## position (see TILE_SIZE-scaled anchors below) it should appear over, the
## already-formatted display string, and one of FloatingTextScript's TYPE_*
## ids. Purely informational -- no gameplay state depends on it -- so tests
## can assert on it directly without needing a running scene tree, and
## _spawn_combat_text() still emits it even from a bare (non-tree)
## BattleController the way every other signal in this file does.
signal combat_text_spawned(pos: Vector2, text: String, type: String)

const GridScript := preload("res://scripts/battle/grid.gd")
const UnitScript := preload("res://scripts/battle/unit.gd")
const FloatingTextScript := preload("res://scripts/battle/floating_text.gd")
const FloatingTextScene := preload("res://scenes/battle/floating_text.tscn")

const GRID_WIDTH := 6
const GRID_HEIGHT := 6
const TILE_SIZE := 64

const SELECTION_RING_COLOR := Color(1, 1, 1, 0.6)
## Move-and-attack (green) tier: reachable tiles that still leave enough AP
## for a basic attack after moving there. Supersedes the old single-tier
## LEGAL_MOVE_COLOR fill (see get_move_and_attack_tiles()).
const LEGAL_MOVE_AND_ATTACK_COLOR := Color(0.3, 0.85, 0.35, 0.45)
## Dash (yellow) tier: reachable tiles that spend too much AP moving to
## leave enough for a basic attack (see get_dash_tiles()).
const DASH_MOVE_COLOR := Color(0.9, 0.85, 0.25, 0.45)
const ATTACK_RANGE_COLOR := Color(0.9, 0.25, 0.25, 0.35)
const TARGET_ATTACK_COLOR := Color(1.0, 0.2, 0.2, 0.65)
## Orange indirect-target overlay: an enemy not directly attackable from the
## selected unit's current position, but attackable after moving to a green
## move-and-attack tile first (see _update_highlights()).
const MOVE_AND_ATTACK_TARGET_COLOR := Color(1.0, 0.65, 0.1, 0.65)
## High-contrast marker for the per-unit facing indicator (see _draw_units()/
## _add_facing_indicator()) -- readable on top of every player and enemy
## unit color.
const FACING_INDICATOR_COLOR := Color(1, 1, 1, 0.85)
const FACING_INDICATOR_SIZE := 12.0
## Ground shadow placeholder (Technical Design §1: "ground shadows, baseline
## anchors, and depth ordering" stand in for a true isometric transform,
## which this step explicitly must not adopt) -- a flattened dark rect
## anchored to each tile's bottom edge so a unit reads as standing "on" the
## ground plane rather than floating centered in its cell.
const SHADOW_COLOR := Color(0, 0, 0, 0.35)
## Pooled floating-combat-text cap (Technical Design §2) -- this game's
## turn-based combat never lands more than a couple of hits in the same
## frame, so a small fixed pool comfortably covers every real burst without
## growing unbounded.
const FLOATING_TEXT_POOL_SIZE := 10

enum Side { PLAYER, ENEMY }
## CONTEXTUAL is the opening and reset mode (see _select_unit()): an empty
## legal tile moves, an enemy attempts auto move-and-attack, and a friendly
## unit selects -- the same click behavior this controller always had before
## the Move/Attack action-bar buttons existed. MOVE and ATTACK narrow
## _handle_tile_click() to just that one action; see the Action Mode State
## Machine section of docs/plans/2026-08-16-battle-screen-redesign/index.md.
## SPELL is Step 4's addition (docs/plans/2026-08-18-core-loop-and-engagement/
## 04-cleric-class-and-scout-reconnaissance.md): entered via begin_spell_
## targeting(), it narrows the next tile click to a single try_cast_spell()
## call for whichever spell pending_spell_id names, on an ally tile
## (including the caster's own, for a self-cast) rather than the ally-
## reselect behavior every other mode gives an ally click.
enum ActionMode { CONTEXTUAL, MOVE, ATTACK, SPELL }

const GROUP := "battle_controller"

const BASE_ACTION_POINTS := 6
const MOVE_ACTION_POINT_COST := 1
const BASIC_ATTACK_ACTION_POINT_COST := 3
const ITEM_ACTION_POINT_COST := 2
## Tactical spells (docs/plans/2026-08-18-core-loop-and-engagement/
## 04-cleric-class-and-scout-reconnaissance.md): both Heal and Bless cost the
## same 3 AP / 1 MP and share the same 0-3 tile occupied-endpoint line-of-
## sight range (0 so a caster can target itself -- has_line_of_sight() and
## get_manhattan_distance() both already resolve trivially true/0 for a
## same-tile target, so no self-cast special case is needed here).
const SPELL_ACTION_POINT_COST := 3
const SPELL_MP_COST := 1
const SPELL_RANGE := 3
const SPELL_HEAL_MIN := 2
const SPELL_HEAL_MAX := 8
## +10 percentage points to final hit chance (still respecting the hit cap)
## and +10% to final post-resistance damage -- see try_attack_selected_unit(),
## which applies both only when the attacker carries this status.
const BLESSED_STATUS_ID := "blessed"
const BLESS_HIT_CHANCE_BONUS := 0.10
const BLESS_DAMAGE_MULTIPLIER := 1.10
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

## Retreat outcome ids (see try_retreat()).
const RETREAT_OUTCOME_NO_LOSS := "no_loss"
const RETREAT_OUTCOME_TEN_PERCENT := "ten_percent"
const RETREAT_OUTCOME_FIFTY_PERCENT := "fifty_percent"
const RETREAT_OUTCOME_DEATH := "death"
## Locked roadmap distribution (docs/designs/campaign-loop.md's Retreat
## table), expressed as cumulative upper bounds on a [0.0, 1.0) roll: a roll
## below "no_loss" is a clean escape, below "ten_percent" a 10% HP loss,
## below "fifty_percent" a 50% HP loss, and anything else (up to 1.0) is a
## death. Each row's own four percentages already sum to 100%, so these
## three cumulative cuts alone fully define all four outcomes.
const RETREAT_OUTCOME_THRESHOLDS := {
	# 1-3 tiles: 10% / 30% / 30% / 30%.
	"near": {"no_loss": 0.10, "ten_percent": 0.40, "fifty_percent": 0.70},
	# 4-6 tiles: 20% / 50% / 10% / 10%.
	"mid": {"no_loss": 0.20, "ten_percent": 0.70, "fifty_percent": 0.80},
	# 7+ tiles: 50% / 30% / 10% / 10%.
	"far": {"no_loss": 0.50, "ten_percent": 0.80, "fifty_percent": 0.90},
}

var grid
var units: Array = []
var _player_adventurer_ids: Array[String] = []
var selected_unit = null
var hovered_unit = null
var inspected_unit = null
var active_side: int = Side.PLAYER
## The Move/Attack action-bar buttons' current mode; see ActionMode and
## set_action_mode(). Never set directly -- always go through
## set_action_mode() so action_mode_changed fires.
var action_mode: int = ActionMode.CONTEXTUAL
## Which spell the next tile click resolves to while action_mode == SPELL
## (see begin_spell_targeting()). Stale while any other mode is active --
## every reader only consults it under ActionMode.SPELL.
var pending_spell_id: String = ""
var input_locked: bool = false
var hit_roll: Callable = func() -> float: return randf()
var crit_roll: Callable = func() -> float: return randf()
var damage_roll: Callable = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
var healing_roll: Callable = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
var rune_trigger_roll: Callable = func() -> float: return randf()
## Injectable so tests can seed an exact Retreat outcome per unit instead of
## depending on real randomness (see hit_roll for the same pattern). Called
## once per living player unit in try_retreat(), in the same stable unit
## order every other per-unit sweep in this file uses.
var retreat_roll: Callable = func() -> float: return randf()
var last_attack_result: Dictionary = {}
var last_targeting_failure: Dictionary = {}
## A player-side unit defeated in real combat is erased from `units`
## immediately (see try_attack_selected_unit()) so its tile frees up and it
## stops rendering. Battlefield still needs its final (0) health at battle
## resolution to run permadeath, so every such defeat is also recorded here
## by adventurer id, independent of `units` -- see _persist_battle_
## aftermath(), which reads both.
var defeated_player_health_by_id: Dictionary = {}
## Pool of FloatingText instances reused across combat events (see
## _acquire_floating_text()) rather than instantiating/freeing a fresh node
## per hit -- populated lazily, capped at FLOATING_TEXT_POOL_SIZE.
var _floating_text_pool: Array = []

@onready var tile_container: Node2D = $Tiles
@onready var shadow_container: Node2D = $Shadows
@onready var unit_container: Node2D = $Units
@onready var highlight_container: Node2D = $Highlights
@onready var floating_text_container: Node2D = $FloatingTexts


func _ready() -> void:
	add_to_group(GROUP)
	grid = GridScript.new(GRID_WIDTH, GRID_HEIGHT)
	var expedition := _get_expedition_for_battle()
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
		player_unit.might = GameSession.get_effective_might(adventurer_id)
		player_unit.health = max(1, GameSession.get_current_health(adventurer_id))
		player_unit.display_name = GameSession.get_adventurer(adventurer_id).get("name", "")
		var armor_instance_id := str(GameSession.get_adventurer(adventurer_id).equipment.armor)
		if GameSession.owned_item_instances.has(armor_instance_id):
			player_unit.rune_id = str(GameSession.owned_item_instances[armor_instance_id].get("rune_id", ""))
		# Tactical spellcasting (see unit.gd's spells/mp_max/mp_remaining doc
		# comment): hydrated generically off whichever spells the class
		# definition lists (only Cleric today) rather than a hardcoded class
		# id check, so a future spellcasting class needs no change here.
		var class_id: String = str(GameSession.get_adventurer(adventurer_id).get("class", ""))
		# Placeholder sprites (docs/plans/2026-08-20-placeholder-sprites/
		# 02-battlefield-sprites.md): presentation-only SpriteCatalog lookup
		# key -- see Unit.visual_key's own doc comment.
		player_unit.visual_key = "player_%s" % class_id
		var class_def: Dictionary = GameSession.CLASS_DEFINITIONS.get(class_id, {})
		var spell_ids: Array = class_def.get("spells", [])
		if not spell_ids.is_empty():
			player_unit.spells = spell_ids.duplicate()
			player_unit.mp_max = int(class_def.get("mp_max", 0))
			player_unit.mp_remaining = player_unit.mp_max
		player_unit.facing = Vector2i.RIGHT
		units.append(player_unit)
	var enemy_specs: Array[Dictionary] = _build_enemy_specs(expedition)
	var enemy_type_counts: Dictionary = {}
	for index in mini(enemy_specs.size(), ENEMY_START_POSITIONS.size()):
		var enemy_stats: Dictionary = enemy_specs[index]
		var enemy_unit := UnitScript.new(
			ENEMY_START_POSITIONS[index], ENEMY_COLOR, Side.ENEMY, BASE_ACTION_POINTS,
			enemy_stats.max_health, enemy_stats.get("damage_min", int(enemy_stats.get("attack_damage", 1))),
			enemy_stats.get("damage_max", int(enemy_stats.get("attack_damage", 1))), enemy_stats.hit_chance,
			tr(enemy_stats.attack_name_key), "",
			int(enemy_stats.get("defense", 0)), int(enemy_stats.get("resistance", 0)), enemy_stats.get("kill_xp", 0)
		)
		enemy_unit.attack_min_range = int(enemy_stats.get("attack_min_range", 1))
		enemy_unit.attack_max_range = int(enemy_stats.get("attack_max_range", 1))
		# Placeholder sprites (docs/plans/2026-08-20-placeholder-sprites/
		# 02-battlefield-sprites.md): presentation-only SpriteCatalog lookup
		# key, derived from untranslated raw data only -- see
		# _visual_family_for_enemy() and Unit.visual_key's own doc comment.
		enemy_unit.visual_key = "enemy_%s" % _visual_family_for_enemy(enemy_stats)
		var enemy_type_name: String = tr(enemy_stats.name_key)
		enemy_type_counts[enemy_type_name] = int(enemy_type_counts.get(enemy_type_name, 0)) + 1
		enemy_unit.display_name = "%s %d" % [enemy_type_name, enemy_type_counts[enemy_type_name]]
		enemy_unit.enemy_type_name = enemy_type_name
		enemy_unit.facing = Vector2i.LEFT
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


func _get_expedition_for_battle() -> Dictionary:
	var expedition: Dictionary = GameSession.get_expedition(GameSession.selected_encounter)
	if expedition.is_empty():
		# Scene-isolated tests instantiate the battlefield with no selected encounter;
		# fall back to the Goblin Camp enemy so those scenarios keep working.
		expedition = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	return expedition


## Flattens an expedition's enemy composition into one ordered stat block per
## fielded unit, in formation order. Authored campaign nodes (see GameSession.
## EXPEDITIONS' "obj_*" entries) declare an ordered mixed-unit "enemies"
## array -- {"enemy": <*_ENEMY_STATS>, "count": n} groups, expanded here in
## declaration order. The three original sandbox expeditions (and any
## resolved STAR_ENEMY_COMPOSITIONS active instance) still declare the
## legacy single "enemy" + "count" template instead; both shapes coexist on
## EXPEDITIONS rather than the mixed-formation schema overloading the legacy
## one (see docs/plans/2026-08-18-core-loop-and-engagement/
## 05-authored-encounters-and-final-boss.md).
func _build_enemy_specs(expedition: Dictionary) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	if expedition.has("enemies"):
		for group in expedition.enemies:
			var stats: Dictionary = group.get("enemy", {})
			for _i in int(group.get("count", 1)):
				specs.append(stats)
	else:
		var enemy_stats: Dictionary = expedition.get("enemy", {})
		for _i in int(enemy_stats.get("count", 1)):
			specs.append(enemy_stats)
	return specs


## Presentation-only SpriteCatalog family for one enemy stat block (docs/
## plans/2026-08-20-placeholder-sprites/02-battlefield-sprites.md). "id" is
## preferred when present, since it is already the most specific raw
## identifier (e.g. "goblin_archer", "hobgoblin_elite"); "loot_id" is the
## fallback for every *_ENEMY_STATS const, which always carries one even when
## it has no "id" (see e.g. GOBLIN_ENEMY_STATS). The three original sandbox
## expeditions' inline "enemy" specs (EXPEDITIONS' "goblin_camp"/
## "orc_outpost"/"ruined_fortress" entries) carry neither, so "name_key" --
## an untranslated i18n key like "battle.enemy.kobold", never
## enemy_type_name, which is already tr()-translated -- is the final
## fallback, read from its last "." segment. Every one of these raw strings
## already has the shape "<family>" or "<family>_<variant>", so splitting on
## the first "_" recovers one of the catalog's five bare families
## ("goblin"/"kobold"/"orc"/"hobgoblin"/"ogre") from any of the three.
func _visual_family_for_enemy(enemy_stats: Dictionary) -> String:
	var raw_family: String = str(enemy_stats.get("id", ""))
	if raw_family == "":
		raw_family = str(enemy_stats.get("loot_id", ""))
	if raw_family == "":
		var name_key := str(enemy_stats.get("name_key", ""))
		var segments: PackedStringArray = name_key.split(".")
		raw_family = segments[-1] if not segments.is_empty() else ""
	return raw_family.split("_")[0]


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
	# get_viewport() requires tree membership; unit tests exercise this
	# against a bare BattleController built via script (see _make_controller()
	# in test_battle_controller.gd), which never enters the tree -- mirrors
	# the same is_inside_tree() guard in _handle_mouse_motion() above, and is
	# likewise never taken in real play, where the controller is always in
	# the tree by the time input reaches it.
	if MOVE_KEY_DIRECTIONS.has(event.keycode):
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		if try_step_selected_unit(MOVE_KEY_DIRECTIONS[event.keycode]):
			_draw_units()
			_select_unit_after_action()
		return
	if NUMBER_KEYS.has(event.keycode):
		if is_inside_tree():
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


## Green range: destinations reachable where enough AP remains afterward to
## still execute a basic attack (`remaining_ap - distance * MOVE_ACTION_POINT_COST
## >= BASIC_ATTACK_ACTION_POINT_COST`). The origin is never included -- it is
## represented by the selection ring, not a movement fill (see
## _move_distances(), which erases the start tile).
func get_move_and_attack_tiles(unit) -> Array[Vector2i]:
	if has_status(unit, PARALYZED_STATUS_ID) or unit.action_points_remaining < MOVE_ACTION_POINT_COST:
		return []
	var tiles: Array[Vector2i] = []
	var distances := _move_distances(unit)
	for tile in distances:
		var move_cost: int = int(distances[tile]) * MOVE_ACTION_POINT_COST
		if unit.action_points_remaining - move_cost >= BASIC_ATTACK_ACTION_POINT_COST:
			tiles.append(tile)
	return tiles


## Yellow range: destinations reachable with remaining AP, but that leave too
## little AP afterward to execute a basic attack. Complements
## get_move_and_attack_tiles() -- together they exactly partition
## get_legal_moves()'s reachable set, and neither includes the origin.
func get_dash_tiles(unit) -> Array[Vector2i]:
	if has_status(unit, PARALYZED_STATUS_ID) or unit.action_points_remaining < MOVE_ACTION_POINT_COST:
		return []
	var tiles: Array[Vector2i] = []
	var distances := _move_distances(unit)
	for tile in distances:
		var move_cost: int = int(distances[tile]) * MOVE_ACTION_POINT_COST
		if unit.action_points_remaining - move_cost < BASIC_ATTACK_ACTION_POINT_COST:
			tiles.append(tile)
	return tiles


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
			if not _in_attack_range(unit, unit.grid_position, target.grid_position):
				continue
			if grid.has_line_of_sight(unit.grid_position, target.grid_position, blocking_tiles):
				legal_targets.append(target)
	return legal_targets


## Weapons whose maximum range is one may target any of the eight
## neighboring tiles (see Grid.is_attack_adjacent()) -- melee attacks are
## diagonal-capable even though movement stays cardinal-only. Ranged weapons
## keep the existing Manhattan min/max range contract untouched.
func _in_attack_range(unit, from_pos: Vector2i, target_pos: Vector2i) -> bool:
	if unit.attack_max_range == 1:
		return grid.is_attack_adjacent(from_pos, target_pos)
	var distance: int = grid.get_manhattan_distance(from_pos, target_pos)
	return distance >= unit.attack_min_range and distance <= unit.attack_max_range


func get_attackable_tiles_for_unit(unit) -> Array[Vector2i]:
	if unit == null or not unit.is_alive():
		return []
	var blocking_tiles: Array[Vector2i] = []
	for candidate in units:
		if candidate != unit and candidate.is_alive():
			blocking_tiles.append(candidate.grid_position)
	if unit.attack_max_range == 1:
		return _melee_attackable_tiles(unit.grid_position, blocking_tiles)
	return grid.get_attackable_tiles(unit.grid_position, unit.attack_min_range, unit.attack_max_range, blocking_tiles)


## Eight-neighbor counterpart to Grid.get_attackable_tiles() for range-one
## weapons, so the attack-range highlight (_update_highlights()) always
## matches what get_legal_attack_targets()/_in_attack_range() actually allow.
func _melee_attackable_tiles(from_pos: Vector2i, blocking_tiles: Array[Vector2i]) -> Array[Vector2i]:
	var attackable: Array[Vector2i] = []
	for delta_x in range(-1, 2):
		for delta_y in range(-1, 2):
			if delta_x == 0 and delta_y == 0:
				continue
			var tile := from_pos + Vector2i(delta_x, delta_y)
			if grid.is_in_bounds(tile) and grid.has_line_of_sight(from_pos, tile, blocking_tiles):
				attackable.append(tile)
	return attackable


## Classifies an attack's angle against the defender's own facing --
## "front"/"side"/"rear" -- per the design doc's 3x3 directional diagrams (see
## docs/plans/2026-08-18-critical-hits-and-flanking/
## 03-flanking-tactics-and-combat-resolution.md's truth table). Pure
## geometry: takes plain positions/facing rather than Unit instances, has no
## adjacency or range requirement of its own, and never mutates state --
## try_attack_selected_unit() is what actually restricts which of these
## angles a given weapon can reach. `u` is the forward/backward component of
## the attacker's offset along the defender's facing axis (positive means
## the attacker stands ahead of the defender, i.e. within its front arc);
## `v` is the sideways component perpendicular to that axis (zero only on
## the facing axis itself, i.e. directly ahead or directly behind).
func get_flank_type(attacker_pos: Vector2i, defender_pos: Vector2i, defender_facing: Vector2i) -> String:
	var offset: Vector2i = attacker_pos - defender_pos
	var u: int = offset.x * defender_facing.x + offset.y * defender_facing.y
	var v: int = absi(offset.x * defender_facing.y - offset.y * defender_facing.x)
	if u > 0:
		return "front"
	if u < 0 and v == 0:
		return "rear"
	return "side"


## Automated move-and-attack targeting: the cheapest green-range tile (see
## get_move_and_attack_tiles()) from which attacker can legally hit target,
## tie-broken by reading order (mirrors _best_enemy_move()'s own tie-break).
## Returns null when no such tile exists. The origin is never a candidate
## here -- try_attack_selected_unit() checks a direct attack from the current
## position separately (via get_legal_attack_targets()) before falling back
## to this helper.
func find_best_move_and_attack_tile(attacker, target):
	if attacker == null or not attacker.is_alive() or target == null or not target.is_alive():
		return null
	var distances := _move_distances(attacker)
	var best = null
	var best_cost := -1
	for candidate in distances:
		var move_cost: int = int(distances[candidate]) * MOVE_ACTION_POINT_COST
		if attacker.action_points_remaining - move_cost < BASIC_ATTACK_ACTION_POINT_COST:
			continue
		if not _can_attack_target_from(attacker, candidate, target):
			continue
		if best_cost == -1 or move_cost < best_cost or (move_cost == best_cost and _reading_order_is_earlier(candidate, best)):
			best = candidate
			best_cost = move_cost
	return best


## Deterministic reason for a rejected move-and-attack, per the design
## contract's precedence (docs/plans/2026-08-16-battle-screen-redesign/
## index.md, "Auto Move-and-Attack Mechanics"): insufficient_ap when a legal
## tile exists (in weapon range AND clear line-of-sight) whose move-plus-
## attack cost exceeds the attacker's remaining AP -- this wins even when a
## different, affordable tile also exists whose line is blocked, since a
## cheaper LOS fix (repositioning further) does not help a unit that simply
## cannot afford to reach any legal tile at all; line_of_sight_blocked only
## when no such legal-but-unaffordable tile exists anywhere on the board but
## an affordable in-range tile does (which must be LOS-blocked, since an
## affordable *and* legal tile would already have been returned by
## find_best_move_and_attack_tile()); out_of_range otherwise. Only called
## after both the direct attack and find_best_move_and_attack_tile() have
## already failed, so the origin is folded back in here (unlike
## find_best_move_and_attack_tile()) purely to classify the already-failed
## direct attack correctly.
func _classify_move_and_attack_failure(attacker, target) -> String:
	var reachable := _move_distances(attacker)
	reachable[attacker.grid_position] = 0
	var legal_unaffordable_found := false
	var affordable_in_range_found := false
	for tile in reachable:
		if not _in_attack_range(attacker, tile, target.grid_position):
			continue
		var move_cost: int = int(reachable[tile]) * MOVE_ACTION_POINT_COST
		if move_cost + BASIC_ATTACK_ACTION_POINT_COST <= attacker.action_points_remaining:
			affordable_in_range_found = true
		elif _can_attack_target_from(attacker, tile, target):
			legal_unaffordable_found = true
	if legal_unaffordable_found:
		return "insufficient_ap"
	if affordable_in_range_found:
		return "line_of_sight_blocked"
	return "out_of_range"


## Route (not just destination legality) comes from grid.get_shortest_path():
## its inclusive start-to-target path both proves the destination reachable
## within the unit's remaining AP and supplies the route's final edge, which
## sets the mover's facing (see Unit.set_facing()) -- deliberately not
## inferred from sign(target - origin), which would disagree with
## get_shortest_path()'s own get_adjacent()-ordered tie-break on an ambiguous
## multi-tile route.
func try_move_selected_unit(target: Vector2i) -> bool:
	if input_locked or selected_unit == null:
		return false
	if has_status(selected_unit, PARALYZED_STATUS_ID):
		return false
	if selected_unit.side != active_side:
		return false

	var is_blocked := func(pos: Vector2i) -> bool: return get_unit_at(pos) != null
	var move_range: int = selected_unit.action_points_remaining / MOVE_ACTION_POINT_COST
	var path: Array[Vector2i] = grid.get_shortest_path(selected_unit.grid_position, target, move_range, is_blocked)
	if path.size() < 2:
		return false

	selected_unit.grid_position = target
	selected_unit.action_points_remaining -= (path.size() - 1) * MOVE_ACTION_POINT_COST
	selected_unit.set_facing(path[-1] - path[-2])
	last_attack_result = {}
	last_targeting_failure = {}
	return true


## Direct attacks execute immediately. A target out of immediate range/LoS is
## instead resolved via find_best_move_and_attack_tile(): all candidate and
## failure classification happens before any mutation below, so a rejected
## attack (any return false past the early guards) leaves the attacker's
## position, AP, last_attack_result, and the target's health untouched.
func try_attack_selected_unit(target_pos: Vector2i) -> bool:
	if input_locked or selected_unit == null or not selected_unit.is_alive():
		return false
	var target = get_unit_at(target_pos)
	if target == null or target.side == selected_unit.side or not target.is_alive():
		return false
	if selected_unit.side != active_side:
		return false
	if has_status(selected_unit, PARALYZED_STATUS_ID):
		last_targeting_failure = {"reason": "paralyzed", "attacker": selected_unit, "target": target}
		return false
	if selected_unit.action_points_remaining < BASIC_ATTACK_ACTION_POINT_COST:
		last_targeting_failure = {"reason": "insufficient_ap", "attacker": selected_unit, "target": target}
		return false

	var move_tile = null
	if not get_legal_attack_targets(selected_unit).has(target):
		move_tile = find_best_move_and_attack_tile(selected_unit, target)
		if move_tile == null:
			last_targeting_failure = {
				"reason": _classify_move_and_attack_failure(selected_unit, target),
				"attacker": selected_unit,
				"target": target,
			}
			return false

	last_targeting_failure = {}
	if move_tile != null:
		var distances := _move_distances(selected_unit)
		selected_unit.grid_position = move_tile
		selected_unit.action_points_remaining -= int(distances[move_tile]) * MOVE_ACTION_POINT_COST

	# The attacker turns to face the defender from its (possibly just-moved-to)
	# position, whether the strike lands or not -- see Unit.set_facing()'s
	# same wider-axis-wins tie rule, used here for a diagonal or ranged shot.
	selected_unit.set_facing(target.grid_position - selected_unit.grid_position)

	selected_unit.action_points_remaining -= BASIC_ATTACK_ACTION_POINT_COST

	# Flanking geometry (docs/plans/2026-08-18-critical-hits-and-flanking/
	# 03-flanking-tactics-and-combat-resolution.md): a side or rear flank
	# reduces the defender's effective Guard (raising hit chance) and adds to
	# the base critical chance Step 2 introduced. Read against the defender's
	# facing and both units' now-final positions, so a move-and-attack that
	# repositioned the attacker above is already reflected here.
	var flank_type: String = get_flank_type(selected_unit.grid_position, target.grid_position, target.facing)
	var guard_penalty: int = 0
	var crit_bonus: float = 0.0
	if flank_type == "side":
		guard_penalty = GameConfig.get_int("combat", "side_flank_guard_penalty", 20)
		crit_bonus = GameConfig.get_float("combat", "side_flank_crit_bonus", 0.20)
	elif flank_type == "rear":
		guard_penalty = GameConfig.get_int("combat", "rear_flank_guard_penalty", 50)
		crit_bonus = GameConfig.get_float("combat", "rear_flank_crit_bonus", 0.50)

	var effective_defense: int = maxi(0, target.defense - guard_penalty)
	var effective_hit_chance: float = clampf(
		selected_unit.hit_chance - effective_defense / 100.0, MIN_HIT_CHANCE, GameSession.EFFECTIVE_HIT_CHANCE_CAP
	)
	# Bless (see try_cast_spell()): +10 percentage points to the attacker's
	# already-computed final hit chance, composed on top of every other
	# modifier above and still re-clamped to the same cap/floor rather than
	# bypassing them.
	if has_status(selected_unit, BLESSED_STATUS_ID):
		effective_hit_chance = clampf(
			effective_hit_chance + BLESS_HIT_CHANCE_BONUS, MIN_HIT_CHANCE, GameSession.EFFECTIVE_HIT_CHANCE_CAP
		)
	var base_critical_chance: float = GameConfig.get_float("combat", "base_critical_chance", 0.05)
	var effective_crit_chance: float = clampf(base_critical_chance + crit_bonus, 0.0, 0.95)

	var hit: bool = hit_roll.call() < effective_hit_chance
	var damage: int = 0
	# Critical hits only exist on a landed hit -- crit_roll is never consumed
	# on a miss, keeping the roll sequence identical to hit_roll/damage_roll's
	# own "no call on a miss" contract (see the Config & Defaults / Critical
	# Hit Roll Determinism sections of docs/plans/2026-08-18-critical-hits-
	# and-flanking/02-critical-hit-mechanics.md).
	var is_critical := false
	if hit:
		is_critical = crit_roll.call() < effective_crit_chance
		var raw_damage: int = damage_roll.call(selected_unit.damage_min, selected_unit.damage_max) + selected_unit.raw_damage_bonus + selected_unit.might
		var effective_resistance: int = target.resistance
		if is_critical:
			var critical_damage_multiplier: float = GameConfig.get_float("combat", "critical_damage_multiplier", 1.5)
			raw_damage = int(round(raw_damage * critical_damage_multiplier))
			var critical_resistance_reduction: int = GameConfig.get_int("combat", "critical_resistance_reduction", 20)
			effective_resistance = maxi(0, target.resistance - critical_resistance_reduction)
		damage = int(maxi(1, round(raw_damage * (1.0 - effective_resistance / 100.0))))
		# Bless: +10% to the already-resolved final post-resistance damage
		# (composed after crit's own raw-damage/resistance adjustments above,
		# not folded into raw_damage before resistance is applied).
		if has_status(selected_unit, BLESSED_STATUS_ID):
			damage = int(maxi(1, round(damage * BLESS_DAMAGE_MULTIPLIER)))
		target.take_damage(damage)
		if is_critical:
			_spawn_combat_text(
				_floating_text_anchor(target), tr("battle.floating.critical") % damage, FloatingTextScript.TYPE_CRITICAL
			)
		else:
			_spawn_combat_text(
				_floating_text_anchor(target), tr("battle.floating.damage") % damage, FloatingTextScript.TYPE_DAMAGE
			)
	else:
		_spawn_combat_text(_floating_text_anchor(target), tr("battle.floating.miss"), FloatingTextScript.TYPE_MISS)
	var defeated: bool = hit and not target.is_alive()
	if defeated:
		AudioManager.play_sfx("sfx_unit_death")
		units.erase(target)
		# A defeated unit is erased from `units` immediately (freeing its tile
		# for movement/pathing -- see get_unit_at()'s blocking check, and
		# _draw_units(), which would otherwise keep rendering a corpse) -- but
		# battle resolution (Battlefield._persist_battle_aftermath()) still
		# needs to learn a defeated player unit's final (0) health to run
		# permadeath, and by then this unit is long gone from `units`.
		# Recorded here, separately, so it survives the erasure above.
		if target.side == Side.PLAYER and target.adventurer_id != "":
			defeated_player_health_by_id[target.adventurer_id] = target.health

	last_attack_result = {
		"type": "attack",
		"attacker": selected_unit,
		"defender": target,
		"hit": hit,
		"damage": damage,
		"critical": is_critical,
		"defeated": defeated,
		"flank": flank_type,
		"effective_defense": effective_defense,
		"effective_hit_chance": effective_hit_chance,
		"effective_crit_chance": effective_crit_chance,
	}
	if hit:
		_dispatch_completed_hit(selected_unit, target)
		completed_hit.emit(last_attack_result)
	if defeated and target.side == Side.ENEMY:
		enemy_defeated.emit(target)
	return true


## Tactical Retreat (docs/plans/2026-08-18-core-loop-and-engagement/
## 02-permadeath-retreat-and-economy-floor.md): only callable during the
## player's active turn, matching every other player action in this file.
## Ends the battle immediately -- every living player unit rolls its own
## distance-based consequence against the nearest living enemy (see
## RETREAT_OUTCOME_THRESHOLDS), this battle's own unbanked loot is
## discarded outright (a retreat never banks battle_reward/battle_gear/
## battle_mana_crystals -- see GameSession.discard_battle_loot()), and
## retreat_resolved fires once with every unit's result so Battlefield can
## log the outcome and hand off routing to GameManager.retreat_from_battle().
func try_retreat() -> Array[Dictionary]:
	if input_locked or active_side != Side.PLAYER:
		return []

	AudioManager.play_sfx("sfx_retreat_horn")
	var results: Array[Dictionary] = []
	for unit in units.duplicate():
		if unit.side != Side.PLAYER or not unit.is_alive():
			continue
		var distance := _nearest_enemy_distance(unit.grid_position)
		var roll: float = retreat_roll.call()
		var outcome := _resolve_retreat_outcome(distance, roll)
		var hp_loss := _retreat_hp_loss(unit, outcome)
		if hp_loss > 0:
			unit.take_damage(hp_loss)
		results.append({
			"unit": unit,
			"adventurer_id": unit.adventurer_id,
			"distance": distance,
			"outcome": outcome,
			"hp_loss": hp_loss,
			"died": not unit.is_alive(),
		})

	GameSession.discard_battle_loot()
	retreat_resolved.emit(results)
	return results


## The step doc's own TDD list is explicit -- "10% max HP loss" / "50% max
## HP loss" -- so the percentage is of the unit's max_health, not its
## current/remaining health, even though the roadmap table's column header
## ("No remaining-HP loss") could be misread as applying to every column.
## Death always empties whatever health remains, regardless of max.
func _retreat_hp_loss(unit, outcome: String) -> int:
	match outcome:
		RETREAT_OUTCOME_TEN_PERCENT:
			return mini(unit.health, int(ceil(unit.max_health * 0.10)))
		RETREAT_OUTCOME_FIFTY_PERCENT:
			return mini(unit.health, int(ceil(unit.max_health * 0.50)))
		RETREAT_OUTCOME_DEATH:
			return unit.health
		_:
			return 0


## Chebyshev (grid/king-move) distance to the nearest living enemy, per the
## Retreat table's own "Nearest Enemy Distance" column -- deliberately not
## _grid_distance()'s Manhattan measure, which the rest of this file (attack
## range, enemy AI pathing) uses instead. No living enemy (should not arise
## in practice -- is_battle_won() would already have ended the battle first)
## reads as the farthest ("7+") bucket rather than crashing.
func _nearest_enemy_distance(from_pos: Vector2i) -> int:
	var nearest_distance := -1
	for unit in units:
		if unit.side != Side.ENEMY or not unit.is_alive():
			continue
		var distance := _chebyshev_distance(from_pos, unit.grid_position)
		if nearest_distance == -1 or distance < nearest_distance:
			nearest_distance = distance
	return nearest_distance if nearest_distance != -1 else 999


func _chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _retreat_distance_bucket(distance: int) -> String:
	if distance <= 3:
		return "near"
	if distance <= 6:
		return "mid"
	return "far"


func _resolve_retreat_outcome(distance: int, roll: float) -> String:
	var thresholds: Dictionary = RETREAT_OUTCOME_THRESHOLDS[_retreat_distance_bucket(distance)]
	if roll < float(thresholds.no_loss):
		return RETREAT_OUTCOME_NO_LOSS
	if roll < float(thresholds.ten_percent):
		return RETREAT_OUTCOME_TEN_PERCENT
	if roll < float(thresholds.fifty_percent):
		return RETREAT_OUTCOME_FIFTY_PERCENT
	return RETREAT_OUTCOME_DEATH


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
	_spawn_combat_text(
		_floating_text_anchor(selected_unit), tr("battle.floating.heal") % healed, FloatingTextScript.TYPE_HEAL
	)
	return true


## Tactical spells (docs/plans/2026-08-18-core-loop-and-engagement/
## 04-cleric-class-and-scout-reconnaissance.md): the only two spells today are
## "heal" (restore an injectable 2-8 HP, capped at max, on a living ally
## that isn't already at full health) and "bless" (apply the battle-local
## BLESSED_STATUS_ID status -- see try_attack_selected_unit() -- to a living
## ally not already blessed). Both share the same 3 AP / 1 MP cost and the
## same 0-3 tile occupied-endpoint line-of-sight range (see grid.
## has_line_of_sight()/get_manhattan_distance(), the same primitives ranged
## attacks already use via get_legal_attack_targets()). Every validation runs
## before any mutation, matching every other try_* action in this file, so a
## rejected cast leaves AP/MP/target state untouched.
func try_cast_spell(spell_id: String, target_pos: Vector2i) -> bool:
	if input_locked or selected_unit == null or not selected_unit.is_alive():
		return false
	if selected_unit.side != Side.PLAYER or active_side != Side.PLAYER:
		return false
	if has_status(selected_unit, PARALYZED_STATUS_ID):
		last_targeting_failure = {"reason": "paralyzed", "attacker": selected_unit}
		return false
	if not selected_unit.spells.has(spell_id):
		return false
	if selected_unit.action_points_remaining < SPELL_ACTION_POINT_COST or selected_unit.mp_remaining < SPELL_MP_COST:
		last_targeting_failure = {"reason": "insufficient_ap"}
		return false

	var target = get_unit_at(target_pos)
	if target == null or target.side != selected_unit.side or not target.is_alive():
		return false

	var distance: int = grid.get_manhattan_distance(selected_unit.grid_position, target_pos)
	if distance > SPELL_RANGE:
		last_targeting_failure = {"reason": "out_of_range"}
		return false
	var blocking_tiles: Array[Vector2i] = []
	for candidate in units:
		if candidate != selected_unit and candidate.is_alive():
			blocking_tiles.append(candidate.grid_position)
	if not grid.has_line_of_sight(selected_unit.grid_position, target_pos, blocking_tiles):
		last_targeting_failure = {"reason": "line_of_sight_blocked"}
		return false

	match spell_id:
		"heal":
			if target.health >= target.max_health:
				return false
			var healed: int = healing_roll.call(SPELL_HEAL_MIN, SPELL_HEAL_MAX)
			target.health = mini(target.max_health, target.health + healed)
			selected_unit.action_points_remaining -= SPELL_ACTION_POINT_COST
			selected_unit.mp_remaining -= SPELL_MP_COST
			last_targeting_failure = {}
			last_attack_result = {
				"type": "spell", "spell_id": spell_id, "caster": selected_unit, "target": target, "healing": healed,
			}
			_spawn_combat_text(
				_floating_text_anchor(target), tr("battle.floating.heal") % healed, FloatingTextScript.TYPE_HEAL
			)
			return true
		"bless":
			if has_status(target, BLESSED_STATUS_ID):
				return false
			apply_status(target, BLESSED_STATUS_ID)
			selected_unit.action_points_remaining -= SPELL_ACTION_POINT_COST
			selected_unit.mp_remaining -= SPELL_MP_COST
			last_targeting_failure = {}
			last_attack_result = {"type": "spell", "spell_id": spell_id, "caster": selected_unit, "target": target}
			AudioManager.play_sfx("sfx_spell_bless")
			return true
		_:
			return false


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
	selected_unit.set_facing(direction)
	selected_unit.grid_position = target
	selected_unit.action_points_remaining -= MOVE_ACTION_POINT_COST
	last_attack_result = {}
	last_targeting_failure = {}
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
	if not _in_attack_range(unit, from_pos, target.grid_position):
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


## The Move/Attack action-bar buttons' only effect on gameplay: narrowing
## which of the two branches below _handle_tile_click() takes. No keyboard
## shortcut ever calls this -- see _handle_key_input()'s MOVE_KEY_DIRECTIONS/
## NUMBER_KEYS tables, which cover every bound key and neither table (nor any
## other key handling) references ActionMode.
func set_action_mode(mode: int) -> void:
	if action_mode == mode:
		return
	action_mode = mode
	action_mode_changed.emit(action_mode)


## Enters spell-targeting mode (see ActionMode.SPELL's own doc comment): the
## next tile click resolves to exactly one try_cast_spell() call for
## spell_id. Called by Battlefield's Heal/Bless action-bar buttons, the same
## way set_action_mode() itself is called by the Move/Attack buttons.
## pending_spell_id is set before set_action_mode() so it's already current
## even on the no-op path (re-pressing a spell button while already in SPELL
## mode) -- callers resync their own button state unconditionally afterward,
## the same way _on_move_button_pressed()/_on_attack_button_pressed() do.
func begin_spell_targeting(spell_id: String) -> void:
	pending_spell_id = spell_id
	set_action_mode(ActionMode.SPELL)


func _handle_tile_click(tile_pos: Vector2i) -> void:
	if input_locked:
		return

	last_targeting_failure = {}

	if action_mode == ActionMode.SPELL:
		# SPELL mode intercepts every click, including one on an ally tile
		# (which every other mode treats as a reselect) -- a spell always
		# targets an ally, so try_cast_spell() itself decides legality; this
		# mode never falls through to the move/attack dispatch below.
		if selected_unit != null and try_cast_spell(pending_spell_id, tile_pos):
			_draw_units()
			_select_unit_after_action()
		else:
			if last_targeting_failure.is_empty():
				last_targeting_failure = {"reason": "spell_invalid_target"}
			board_changed.emit()
		return

	var clicked_unit = get_unit_at(tile_pos)
	if clicked_unit != null:
		if clicked_unit.side == active_side:
			_select_unit(clicked_unit)
			return

		if action_mode == ActionMode.MOVE:
			# MOVE mode never attacks -- an enemy click only inspects it and
			# reports move-mode feedback (Action Mode State Machine, index.md).
			last_targeting_failure = {"reason": "move_mode_no_attack"}
			_set_inspected_unit(clicked_unit)
			board_changed.emit()
			return

		# CONTEXTUAL and ATTACK modes both attempt direct/auto move-and-attack
		# on an enemy click.
		if selected_unit != null and try_attack_selected_unit(tile_pos):
			_draw_units()
			_select_unit_after_action()
			return
		# try_attack_selected_unit() already populated last_targeting_failure
		# with the deterministic reason (including move-and-attack rejections)
		# when a legitimate attempt was rejected; nothing further to compute here.
		_set_inspected_unit(clicked_unit)
		board_changed.emit()
		return

	if action_mode == ActionMode.ATTACK:
		# ATTACK mode never moves -- an empty-tile click is a no-op that
		# reports attack-mode feedback (Action Mode State Machine, index.md).
		last_targeting_failure = {"reason": "attack_mode_no_target"}
		board_changed.emit()
		return

	# CONTEXTUAL and MOVE modes both attempt a move on an empty-tile click.
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


## Every call site is one of the three reset triggers in the Action Mode
## State Machine (index.md): selecting a player unit (_handle_tile_click()),
## returning control to the player or handing it to the enemy (end_turn()),
## and resolving a move/attack (_select_unit_after_action()) -- so resetting
## here covers all three without duplicating the reset at each call site.
func _select_unit(unit) -> void:
	selected_unit = unit
	last_targeting_failure = {}
	set_action_mode(ActionMode.CONTEXTUAL)
	_set_inspected_unit(unit)
	_update_highlights()
	board_changed.emit()


func _to_grid_position(local_pos: Vector2) -> Vector2i:
	return Vector2i(floori(local_pos.x / TILE_SIZE), floori(local_pos.y / TILE_SIZE))


## Placeholder sprites (docs/plans/2026-08-20-placeholder-sprites/
## 02-battlefield-sprites.md): each ground tile is a catalog-backed Sprite2D
## at an unchanged Vector2(x, y) * TILE_SIZE position -- `centered = false`
## keeps that position meaning the tile's top-left corner, exactly like the
## ColorRect it replaces, rather than requiring every position here to be
## recomputed to a tile-center anchor. Kenney's 16px ground art at the
## required integral 4x scale exactly fills one 64px TILE_SIZE cell.
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


func _draw_units() -> void:
	# Mirrors _update_highlights()'s guard below: unit tests build a bare
	# BattleController via script (not the battlefield scene), so it never
	# enters the tree and its @onready containers are never resolved.
	if not is_inside_tree():
		return
	for child in unit_container.get_children():
		child.queue_free()
	for child in shadow_container.get_children():
		child.queue_free()

	# Depth ordering (Technical Design §1): painter's-algorithm sort by row
	# so a unit nearer the "camera" (larger grid_position.y) draws over one
	# farther away, the cheapest way to make overlapping/adjacent sprites
	# read as occupying a 3/4 top-down space -- test_draw_units_attaches_a_
	# facing_indicator_positioned_toward_each_units_facing only asserts on
	# the unordered *set* of sprites/indicators (matched back to a unit by
	# grid position), never on child index, so reordering the draw list here
	# is safe.
	var sorted_units: Array = units.duplicate()
	sorted_units.sort_custom(func(a, b): return a.grid_position.y < b.grid_position.y)
	for unit in sorted_units:
		var tile_origin: Vector2 = Vector2(unit.grid_position) * TILE_SIZE
		var shadow_size := Vector2(TILE_SIZE * 0.6, TILE_SIZE * 0.22)
		var shadow := ColorRect.new()
		shadow.size = shadow_size
		shadow.position = (
			tile_origin + Vector2(TILE_SIZE / 2.0 - shadow_size.x / 2.0, TILE_SIZE - shadow_size.y - TILE_SIZE * 0.05)
		)
		shadow.color = SHADOW_COLOR
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shadow_container.add_child(shadow)

		# Placeholder sprites (docs/plans/2026-08-20-placeholder-sprites/
		# 02-battlefield-sprites.md): a catalog-backed Sprite2D at the
		# required integral 4x nearest-neighbor scale, horizontally centered
		# on the tile and bottom-anchored so its feet meet the shadow's own
		# bottom edge (the shadow's existing baseline, computed the same way
		# above) regardless of each source sprite's actual pixel height.
		var sprite := Sprite2D.new()
		sprite.name = "UnitSprite"
		sprite.texture = SpriteCatalog.get_unit_texture(unit.visual_key)
		sprite.scale = Vector2(4, 4)
		var shadow_baseline: float = shadow.position.y + shadow_size.y
		# Integral nearest-neighbor placement (this plan's own invariant --
		# see docs/plans/2026-08-20-placeholder-sprites/index.md's "no
		# filtering or fractional placement" line): shadow_size.y is
		# TILE_SIZE * 0.22, a non-integer, so shadow_baseline itself always
		# lands on a fractional pixel (tile_origin.y + 60.8) -- round() only
		# the sprite's own Y here (never the shadow, which this plan does not
		# ask to change) so every unit sprite still lands on a whole pixel.
		# round() rather than floor()/ceil() keeps the sprite as close as
		# possible to the true baseline in either direction, so the
		# sub-pixel "feet in shadow" read stays the closest achievable match
		# rather than being biased consistently up or down.
		sprite.position = Vector2(
			tile_origin.x + TILE_SIZE / 2.0,
			round(shadow_baseline - (sprite.texture.get_height() * sprite.scale.y) / 2.0)
		)
		unit_container.add_child(sprite)
		_add_facing_indicator(tile_origin, unit)


## A small high-contrast square offset from the unit's own tile center toward
## the edge unit.facing points at -- the board's only visible cue for a
## unit's orientation, which Steps 2/3 of this plan (critical hits, flanking)
## reason about for attack geometry. A unit_container sibling of the sprite
## above (added after it, so it always draws on top) rather than a child of
## it: a Sprite2D's own `scale` (see above) would otherwise multiply this
## indicator's fixed 12x12 size and position right along with it, the same
## way it would any other child, which is not what a fixed-size overlay cue
## wants. tile_origin + TILE_SIZE / 2.0 (i.e. the tile's own center) is
## algebraically identical to this indicator's previous body-relative anchor
## (tile_origin + margin + body_size / 2.0, and margin + body_size / 2.0 ==
## TILE_SIZE / 2.0 for the fixed 0.15 * TILE_SIZE margin the old ColorRect
## body used), so this keeps the exact same on-screen placement.
func _add_facing_indicator(tile_origin: Vector2, unit) -> void:
	var indicator := ColorRect.new()
	indicator.name = "FacingIndicator"
	indicator.size = Vector2(FACING_INDICATOR_SIZE, FACING_INDICATOR_SIZE)
	indicator.color = FACING_INDICATOR_COLOR
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile_center: Vector2 = tile_origin + Vector2(TILE_SIZE, TILE_SIZE) / 2.0
	var body_half_size: float = TILE_SIZE / 2.0 - TILE_SIZE * 0.15
	var edge_offset: float = body_half_size - FACING_INDICATOR_SIZE
	indicator.position = tile_center - indicator.size / 2.0 + Vector2(unit.facing) * edge_offset
	# force_readable_name=true: every unit's indicator shares the literal
	# name "FacingIndicator" (kept as a stable, greppable identity for tests
	# and debugging), so Godot's default uniqueness handling would otherwise
	# silently rewrite every collision to an opaque "@ColorRect@123" engine
	# id instead of a readable "FacingIndicator2" suffix.
	unit_container.add_child(indicator, true)


## Grid-local pixel anchor for a unit's floating combat text -- centered
## horizontally over its tile, near the top edge so the text rises up and
## away from the unit body rather than starting on top of it.
func _floating_text_anchor(unit) -> Vector2:
	return Vector2(unit.grid_position) * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE * 0.1)


## Combat-feedback type (FloatingTextScript.TYPE_*) -> matching SFX catalog
## id (docs/plans/2026-08-18-core-loop-and-engagement/
## 08-audio-system-and-soundscape.md's Sound Effects Catalog). Keyed here
## rather than duplicated at every _spawn_combat_text() call site, since
## every combat-feedback event already funnels through that one function.
const COMBAT_TEXT_SFX_IDS := {
	FloatingTextScript.TYPE_DAMAGE: "sfx_hit_impact",
	FloatingTextScript.TYPE_CRITICAL: "sfx_crit_impact",
	FloatingTextScript.TYPE_MISS: "sfx_miss",
	FloatingTextScript.TYPE_HEAL: "sfx_spell_heal",
	FloatingTextScript.TYPE_BLOCKED: "sfx_guard_block",
}


## Presentation-layer entry point for every combat-feedback event (Technical
## Design §2). Always emits combat_text_spawned -- tests build a bare
## BattleController via .new() and assert on the signal alone -- and, only
## when actually running inside a scene tree (mirrors _draw_units()'s own
## is_inside_tree() guard), also drives a pooled FloatingText instance so the
## real battlefield shows the animation.
##
## The matching SFX (see COMBAT_TEXT_SFX_IDS) plays unconditionally right
## alongside combat_text_spawned.emit() -- both statements run every time,
## regardless of tree state or AudioManager's own mute state (muting only
## silences AudioServer's bus output; it never skips the play_sfx() call
## itself). That is what keeps the audio and visual/log feedback paths
## structurally independent: muting one can never suppress the other, since
## neither is conditioned on the other (see tests/unit/test_battlefield.gd's
## mute-parity coverage).
func _spawn_combat_text(pos: Vector2, text: String, type: String) -> void:
	combat_text_spawned.emit(pos, text, type)
	var sfx_id: String = COMBAT_TEXT_SFX_IDS.get(type, "")
	if sfx_id != "":
		AudioManager.play_sfx(sfx_id)
	if not is_inside_tree():
		return
	_acquire_floating_text().play(pos, text, type)


## Reuses the first inactive pooled instance; grows the pool up to
## FLOATING_TEXT_POOL_SIZE when every existing instance is still animating;
## beyond that cap, steals the oldest entry rather than growing unbounded --
## this game's turn-based combat never lands enough simultaneous hits to
## exhaust a pool of this size in practice.
func _acquire_floating_text():
	for candidate in _floating_text_pool:
		if not candidate.is_active:
			return candidate
	if _floating_text_pool.size() < FLOATING_TEXT_POOL_SIZE:
		var instance = FloatingTextScene.instantiate()
		floating_text_container.add_child(instance)
		_floating_text_pool.append(instance)
		return instance
	return _floating_text_pool[0]


## Full-tile overlay used for every highlight_container fill (movement tiers,
## attack range, and direct/indirect targets). Children are added in the
## order _update_highlights() calls this, so later calls render on top.
func _add_highlight(tile: Vector2i, color: Color) -> void:
	var highlight := ColorRect.new()
	highlight.size = Vector2(TILE_SIZE, TILE_SIZE)
	highlight.position = Vector2(tile) * TILE_SIZE
	highlight.color = color
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight_container.add_child(highlight)


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

	# Two-tier movement fill: green (move-and-attack) and yellow (dash) partition
	# get_legal_moves() exactly, and neither ever contains the origin (see
	# get_move_and_attack_tiles()/get_dash_tiles()).
	var move_and_attack_tiles := get_move_and_attack_tiles(selected_unit)
	for move in move_and_attack_tiles:
		_add_highlight(move, LEGAL_MOVE_AND_ATTACK_COLOR)

	var dash_tiles := get_dash_tiles(selected_unit)
	for move in dash_tiles:
		_add_highlight(move, DASH_MOVE_COLOR)

	var legal_moves := get_legal_moves(selected_unit)

	if selected_unit.action_points_remaining >= BASIC_ATTACK_ACTION_POINT_COST and not has_status(selected_unit, PARALYZED_STATUS_ID):
		var attackable_tiles := get_attackable_tiles_for_unit(selected_unit)
		var legal_targets := get_legal_attack_targets(selected_unit)
		var target_positions: Array[Vector2i] = []
		for target in legal_targets:
			target_positions.append(target.grid_position)

		# Red direct targets and the attack-range fill render after the
		# movement fills so they stay visible on top of them.
		for tile in attackable_tiles:
			if tile == selected_unit.grid_position:
				continue
			var occupant = get_unit_at(tile)
			if occupant != null and occupant.side == selected_unit.side:
				continue
			if target_positions.has(tile):
				_add_highlight(tile, TARGET_ATTACK_COLOR)
			elif not legal_moves.has(tile):
				_add_highlight(tile, ATTACK_RANGE_COLOR)

		# Orange indirect targets: enemies not directly attackable from the
		# current position, but attackable after moving to a green
		# move-and-attack tile first. Rendered last so it stays visible on
		# top of the movement fills and the plain attack-range fill.
		for target in units:
			if target.side == selected_unit.side or not target.is_alive():
				continue
			if target_positions.has(target.grid_position):
				continue
			for candidate in move_and_attack_tiles:
				if _can_attack_target_from(selected_unit, candidate, target):
					_add_highlight(target.grid_position, MOVE_AND_ATTACK_TARGET_COLOR)
					break
