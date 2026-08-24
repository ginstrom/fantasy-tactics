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
const ContentCatalogScript := preload("res://scripts/content/content_catalog.gd")
## Stage 6 Step 4 (docs/plans/2026-08-24-stage-6-content-and-domain-
## foundations/04-branching-perk-definitions.md): the bounded perk-effect
## rule evaluator -- see _unit_has_perk()'s replacement doc comment for why
## every "does this unit's perk grant this action" gate below now routes
## through PerkEffectResolverScript.has_granted_action() instead of a
## hardcoded GameSession.SOME_PERK_ID comparison.
const PerkEffectResolverScript := preload("res://scripts/battle/perk_effect_resolver.gd")

const GRID_WIDTH := 6
const GRID_HEIGHT := 6
const TILE_SIZE := 64

const SELECTION_RING_COLOR := Color(1, 1, 1, 0.6)
## On-tile cue for hovered_unit (see _set_hovered_unit()/_update_highlights()) --
## a cyan hue distinct from SELECTION_RING_COLOR's white so a unit that is
## simultaneously hovered and selected, or hovered while a *different* unit
## is selected, still reads as two separate cues (D9 presentation-standard
## gap fix, docs/designs/campaign-loop.md). Purely presentational: never read
## by selection, targeting, or click-geometry logic.
const HOVER_RING_COLOR := Color(0.2, 0.9, 1.0, 0.75)
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
## Cover terrain markers (Stage 5 D2) -- distinct hues per tier, always paired
## with an "L"/"H" text badge (see _draw_cover_markers()) so the difference
## never rests on colour alone.
const COVER_LOW_MARKER_COLOR := Color(0.45, 0.65, 0.35, 0.9)
const COVER_HIGH_MARKER_COLOR := Color(0.2, 0.45, 0.2, 0.9)
## Battlefield visibility (Stage 5 D2): a flat dark tint over any tile
## outside the player's current line of sight (see get_player_visible_tiles()/
## _update_visibility_overlay()). Deliberately translucent, not opaque -- a
## dimmed tile still reads (ground, cover, a stale marker), it is just marked
## as not currently observed.
const STALE_TILE_OVERLAY_COLOR := Color(0, 0, 0, 0.45)
## Last-known-enemy marker (Stage 5 D2): the ghost sprite's own alpha, plus a
## text badge (never colour-only) marking it as possibly outdated.
const STALE_UNIT_MODULATE := Color(1, 1, 1, 0.45)
const STALE_MARKER_BADGE_COLOR := Color(0.9, 0.9, 0.2, 0.9)
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
## SHIELD_BASH is Stage 5 D4's addition (Knight specialization): behaves
## exactly like ATTACK mode (enemy click only, no free move on an empty
## tile -- see _handle_tile_click()) except it dispatches to try_shield_
## bash_selected_unit() instead of try_attack_selected_unit(). CALLED_SHOT is
## Stage 5 D4's Archer addition: the same attack-only shape again, dispatching
## to try_called_shot_selected_unit() instead.
enum ActionMode { CONTEXTUAL, MOVE, ATTACK, SPELL, SHIELD_BASH, CALLED_SHOT }

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
const SPELL_HEAL_MIN := 2
const SPELL_HEAL_MAX := 8
## +10 percentage points to final hit chance (still respecting the hit cap)
## and +10% to final post-resistance damage -- see try_attack_selected_unit(),
## which applies both only when the attacker carries this status.
const BLESSED_STATUS_ID := "blessed"
const BLESS_HIT_CHANCE_BONUS := 0.10
const BLESS_DAMAGE_MULTIPLIER := 1.10
## Paladin's own doubled Bless variant (Stage 5 D4, decision-ledger.md's
## "Paladin's ability" row): a DISTINCT status id from BLESSED_STATUS_ID, not
## a variant field on the same status -- apply_status()/has_status()'s
## whole-codebase contract is a plain boolean flag (unit.statuses[id] = true),
## shared by every other status (Sleeping, Paralyzed, off-balance, Temporary
## Guard), so a caster-dependent magnitude needs its own id rather than
## breaking that generic contract. Mirrors is_incapacitated()'s own precedent
## for "two different sources, two distinct status ids, both read at the same
## consumption sites" (PARALYZED_STATUS_ID vs. SLEEPING_STATUS_ID). Applied
## instead of (never alongside) BLESSED_STATUS_ID by try_cast_spell()'s
## "bless" match arm, keyed purely to whether the CASTER (not the target) is
## a promoted Paladin -- see Unit.specialization. Both the damage-multiplier
## site (_resolve_attack_core()) and the hit-chance-bonus site (_compute_
## effective_attack_chances()) check this status id alongside BLESSED_STATUS_
## ID and pick the matching magnitude below; a doubled Bless still composes
## on top of -- and is still re-clamped by -- every other modifier exactly
## like a regular Bless, so it is never a strictly-dominant option (see the
## ledger's own "still subject to whatever cap/clamp already exists on
## effective_hit_chance" counterplay note).
const PALADIN_BLESSED_STATUS_ID := "paladin_blessed"
const PALADIN_BLESS_HIT_CHANCE_BONUS := 0.20
const PALADIN_BLESS_DAMAGE_MULTIPLIER := 1.20
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
## Sleep (Stage 5 D3, docs/plans/2026-08-23-stage-5-strategic-roster-
## expansion/decision-ledger.md): a distinct status id from PARALYZED_
## STATUS_ID -- Thorn's existing behavior must not change, and Sleep is its
## own source, not a repurposing of Paralyzed -- but both block a unit's
## move/attack/cast identically (see is_incapacitated()), so both are erased
## at the same round-boundary in _clear_expired_statuses().
const SLEEPING_STATUS_ID := "sleeping"
## Battle Mage's Temporary Guard perk (Stage 5 D4): +10 Guard (same magnitude
## as the existing Bulwark perk, GameSession.WARRIOR_BULWARK_GUARD -- see
## _compute_effective_attack_chances()'s own doc comment on how this is
## applied) for the caster itself, until the start of its next Round -- same
## round-boundary Sleep/Paralyzed already clear on, see _clear_expired_
## statuses(). A distinct status id from PARALYZED_STATUS_ID/SLEEPING_
## STATUS_ID: it never incapacitates (is_incapacitated() does not check it),
## it only ever modifies Guard.
const TEMPORARY_GUARD_STATUS_ID := "temporary_guard"

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
## Stage 5 D2 tactical primitives: Dodge is eligible for any incoming attack
## type, Parry only for a melee one -- both flat-chance, both injectable here
## exactly like hit_roll/crit_roll above so BattleStateFactory can seed them
## from the same per-iteration RNG (see that file's build()) and no new
## stochastic check ever falls back to global randf() in a deterministic
## scenario. See _resolve_attack_core().
var dodge_roll: Callable = func() -> float: return randf()
var parry_roll: Callable = func() -> float: return randf()
## Sleep's magic-resistance roll (Stage 5 D3): same injectable pattern as
## dodge_roll/parry_roll immediately above, seeded from BattleStateFactory's
## same per-iteration RNG (see that file's build()) so a deterministic
## scenario never falls back to global randf() for this new stochastic
## check either.
var sleep_resist_roll: Callable = func() -> float: return randf()
## Fire Bolt's damage/resistance rolls (Battle Mage specialization, Stage 5
## D4): the same injectable pattern as healing_roll/sleep_resist_roll above,
## kept as their own distinct Callables (not a literal reuse of either) so a
## deterministic scenario fielding both a Cleric's Heal and a Battle Mage's
## Fire Bolt can seed each roll independently -- see BattleStateFactory.
## build(), which seeds both from the same per-iteration RNG healing_roll/
## sleep_resist_roll already draw from. fire_bolt_damage_roll shares healing_
## roll's exact 2-8 magnitude (SPELL_HEAL_MIN/SPELL_HEAL_MAX) and fire_bolt_
## resist_roll shares sleep_resist_roll's exact resist-chance formula -- see
## try_cast_spell()'s "fire_bolt" match arm.
var fire_bolt_damage_roll: Callable = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
var fire_bolt_resist_roll: Callable = func() -> float: return randf()
## Injectable so tests can seed an exact Retreat outcome per unit instead of
## depending on real randomness (see hit_roll for the same pattern). Called
## once per living player unit in try_retreat(), in the same stable unit
## order every other per-unit sweep in this file uses.
var retreat_roll: Callable = func() -> float: return randf()
## Archer's Lock On perk (Stage 5 D4): the current Round number, starting at
## 1 (mirrors Battlefield's own presentation-layer round_number, which is NOT
## read here -- see this var's own doc comment on why the controller needed
## its own copy). Incremented exactly once per Round, in end_turn(), at the
## SAME PLAYER-side boundary _clear_expired_statuses() already fires at
## (never on the PLAYER -> ENEMY half of a Round). Unit.last_attacked_round
## is stamped from this value every time a unit attacks (see
## _execute_direct_attack()) and compared against it in _compute_effective_
## attack_chances() to grant Lock On's +10% only for a target attacked on
## the IMMEDIATELY PRECEDING Round (current_round - 1) -- a round counter,
## not the pending/active flag pattern off_balance/counter_bonus use,
## because Lock On's target can change (or repeat) every single Round this
## unit acts, not just on a sporadic Dodge/Parry event; a plain "was it my
## last turn" comparison has no promotion-collision edge case a counter
## doesn't already handle for free.
var current_round: int = 1
var last_attack_result: Dictionary = {}
var last_targeting_failure: Dictionary = {}
## Chain Blow's bonus second strike result (Stage 5 D4), populated only when
## it actually triggers this action -- {} otherwise. Kept separate from
## last_attack_result (the primary strike's own result) rather than
## overwritten by it, the same "a reaction is a side effect, not the
## action's own primary result" pattern last_reaction_results already uses
## for Attacks of Opportunity -- see Battlefield's own log line for this.
## Cleared at the start of every direct attack/Shield Bash action, same as
## last_attack_result/last_targeting_failure.
var last_chain_blow_result: Dictionary = {}
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
## Every Attack-of-Opportunity resolved by the most recent move action (see
## _trigger_opportunity_attacks_along_path()), in trigger order. Cleared at
## the start of every move action, exactly like last_attack_result/
## last_targeting_failure -- Battlefield drains and logs these separately
## (a reaction is a side effect of a move, not the move's own primary
## result) rather than overwriting last_attack_result with it.
var last_reaction_results: Array[Dictionary] = []
## Last-known-position memory for battlefield visibility/staleness (Stage 5
## D2's "Battlefield visibility" row): Unit (enemy) -> Vector2i, the last
## tile the player actually saw that enemy occupy. Maintained exclusively by
## _refresh_battlefield_memory(); see get_stale_enemy_markers() for the
## single authoritative read of it (rendering/UI must never keep an
## independent copy of this rule).
var _last_known_enemy_positions: Dictionary = {}

@onready var tile_container: Node2D = $Tiles
@onready var terrain_container: Node2D = $Terrain
@onready var shadow_container: Node2D = $Shadows
@onready var unit_container: Node2D = $Units
@onready var highlight_container: Node2D = $Highlights
@onready var floating_text_container: Node2D = $FloatingTexts


func _ready() -> void:
	add_to_group(GROUP)
	# Stage 6 Step 3 (docs/plans/2026-08-24-stage-6-content-and-domain-
	# foundations/03-authored-content-catalog.md): when the current encounter
	# id has a ContentCatalog definition, board dimensions, cover, and unit
	# spawn tiles all come from it -- see _board_dimensions()/
	# _player_spawn_positions()/_enemy_spawn_positions() below, which fall
	# back to this file's own GRID_WIDTH/GRID_HEIGHT/PLAYER_START_POSITIONS/
	# ENEMY_START_POSITIONS constants (and empty cover) for every encounter
	# still outside the catalog, exactly as before this step existed.
	var catalog_definition: Dictionary = ContentCatalogScript.get_encounter_definition(_current_encounter_id())
	var board_size := _board_dimensions(catalog_definition)
	grid = GridScript.new(board_size.x, board_size.y)
	grid.cover_tiles = (catalog_definition.cover_tiles as Dictionary).duplicate() if not catalog_definition.is_empty() else {}
	var expedition := _get_expedition_for_battle()
	_player_adventurer_ids = _get_player_adventurer_ids()
	units = []
	var player_spawn_positions := _player_spawn_positions(catalog_definition)
	for index in mini(_player_adventurer_ids.size(), player_spawn_positions.size()):
		var adventurer_id: String = _player_adventurer_ids[index]
		var damage_range: Vector2i = GameSession.get_effective_weapon_damage_range(adventurer_id)
		var attack_range: Vector2i = GameSession.get_effective_weapon_attack_range(adventurer_id)
		var player_unit := UnitScript.new(
			player_spawn_positions[index], PLAYER_COLORS[index % PLAYER_COLORS.size()], Side.PLAYER,
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
		# Explicit shared tactical profile (docs/designs/class-system.md's
		# "Shared tactical attributes" section; see unit.gd's melee/missile/
		# guard/spellcasting/magic_resistance doc comment). guard/hit_chance
		# above both already derive from the exact same GameSession getters,
		# so these can never disagree with the combat math this unit actually
		# resolves against.
		player_unit.melee = GameSession.get_effective_melee(adventurer_id)
		player_unit.missile = GameSession.get_effective_missile(adventurer_id)
		player_unit.guard = player_unit.defense
		player_unit.spellcasting = GameSession.get_effective_spellcasting(adventurer_id)
		player_unit.magic_resistance = GameSession.get_effective_magic_resistance(adventurer_id)
		# Stage 5 D4: hydrated so Shield Bash/Chain Blow gate correctly for a
		# promoted Knight (see Unit.perks' own doc comment/_unit_grants_action()) --
		# the same adventurer.progression.perks list get_effective_defense()/
		# get_effective_max_health() already read for Bulwark/Juggernaut, just
		# copied onto the battle-local unit directly rather than pre-folded
		# into a stat, since these two perks are active abilities, not stat
		# bonuses.
		player_unit.perks = (GameSession.get_adventurer(adventurer_id).progression.get("perks", []) as Array).duplicate()
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
		# Stage 5 D4: a promoted specialization's own SPECIALIZATION_SPELLS
		# entries (Battle Mage's "fire_bolt") are appended onto the root
		# class_def's own "spells" list before hydration -- mirrors get_
		# available_perks()' identical "root catalog, then specialization
		# catalog" append pattern, just for spells instead of perks. An
		# unpromoted adventurer's specialization_id is empty, so this is a
		# no-op for every existing class exactly as before.
		var spell_ids: Array = (class_def.get("spells", []) as Array).duplicate()
		var specialization_id := GameSession.get_adventurer_specialization(adventurer_id)
		# Paladin (Stage 5 D4): hydrated unconditionally (even "" for an
		# unpromoted/non-Paladin adventurer) so try_cast_spell()'s "bless"
		# match arm can read caster identity directly off the battle-local
		# unit -- see Unit.specialization's own doc comment.
		player_unit.specialization = specialization_id
		if not specialization_id.is_empty():
			spell_ids.append_array(GameSession.SPECIALIZATION_SPELLS.get(specialization_id, []))
		if not spell_ids.is_empty():
			player_unit.spells = spell_ids.duplicate()
			player_unit.mp_max = int(class_def.get("mp_max", 0))
			# Durable MP (docs/designs/campaign-loop.md's "Cleric current MP is
			# durable adventurer state" paragraph): battle start hydrates from
			# the adventurer's own stored current MP -- NOT always full -- so a
			# Cleric who entered this battle already spent, or naturally
			# recovering, MP carries that value in. Mirrors player_unit.health
			# a few lines above, which reads GameSession.get_current_health()
			# the same way rather than always starting at max.
			player_unit.mp_remaining = GameSession.get_current_mp(adventurer_id)
		player_unit.facing = Vector2i.RIGHT
		units.append(player_unit)
	var enemy_specs: Array[Dictionary] = _build_enemy_specs(expedition)
	var enemy_type_counts: Dictionary = {}
	var enemy_spawn_positions := _enemy_spawn_positions(catalog_definition)
	for index in mini(enemy_specs.size(), enemy_spawn_positions.size()):
		var enemy_stats: Dictionary = enemy_specs[index]
		# Enemy hit chance/Guard are normalized once through GameSession's
		# shared adapter (see get_enemy_profile_hit_chance()/get_enemy_
		# profile_guard()'s own doc comments) so a migrated, explicit-profile
		# template (melee/missile/guard -- Step 5's locked "Initial roster")
		# and a still-legacy template (flat hit_chance/defense -- every other
		# enemy const in this file) hydrate through the exact same formula
		# BattleStateFactory._build_enemy_unit() uses for a scenario battle.
		var enemy_hit_chance: float = GameSession.get_enemy_profile_hit_chance(enemy_stats)
		var enemy_guard: int = GameSession.get_enemy_profile_guard(enemy_stats)
		var enemy_unit := UnitScript.new(
			enemy_spawn_positions[index], ENEMY_COLOR, Side.ENEMY,
			int(enemy_stats.get("action_points", BASE_ACTION_POINTS)),
			enemy_stats.max_health, enemy_stats.get("damage_min", int(enemy_stats.get("attack_damage", 1))),
			enemy_stats.get("damage_max", int(enemy_stats.get("attack_damage", 1))), enemy_hit_chance,
			tr(enemy_stats.attack_name_key), "",
			enemy_guard, int(enemy_stats.get("resistance", 0)), enemy_stats.get("kill_xp", 0),
			int(enemy_stats.get("might", 0))
		)
		enemy_unit.attack_min_range = int(enemy_stats.get("attack_min_range", 1))
		enemy_unit.attack_max_range = int(enemy_stats.get("attack_max_range", 1))
		# Explicit shared tactical profile -- see the player_unit block above's
		# identical doc comment. melee/missile hydrate through the same
		# adapter as hit_chance (see get_enemy_profile_melee()/
		# get_enemy_profile_missile()'s own doc comment) so a still-legacy
		# enemy template's melee/missile display fields show its real
		# accuracy (derived from hit_chance) rather than a misleading 0 --
		# this is display normalization only and never changes enemy_
		# hit_chance itself, which is computed above straight from
		# enemy_stats. spellcasting/magic_resistance stay 0 for every
		# still-legacy template (no such key authored), same as unit.gd's
		# own field defaults.
		enemy_unit.melee = GameSession.get_enemy_profile_melee(enemy_stats)
		enemy_unit.missile = GameSession.get_enemy_profile_missile(enemy_stats)
		enemy_unit.guard = enemy_guard
		enemy_unit.spellcasting = int(enemy_stats.get("spellcasting", 0))
		enemy_unit.magic_resistance = int(enemy_stats.get("magic_resistance", 0))
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
	_refresh_battlefield_memory()
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


## Raw expedition id this battle is being fought over, with the same empty-
## selection fallback _get_expedition_for_battle() applies (mirrored here,
## not derived from that function's return value, since a resolved
## expedition Dictionary carries no "id" field of its own -- see
## Battlefield._current_expedition()'s identical fallback for the same
## reason).
func _current_encounter_id() -> String:
	var encounter_id: String = GameSession.selected_encounter
	if encounter_id == "":
		encounter_id = GameSession.GOBLIN_CAMP_ID
	return encounter_id


## Board dimensions for this battle (Stage 6 Step 3, docs/plans/2026-08-24-
## stage-6-content-and-domain-foundations/03-authored-content-catalog.md):
## `catalog_definition`'s own grid_size when the current encounter has a
## ContentCatalog entry, else this file's own GRID_WIDTH/GRID_HEIGHT
## constants -- the same fallback every still-legacy (non-cataloged)
## encounter always used before this step existed.
func _board_dimensions(catalog_definition: Dictionary) -> Vector2i:
	if catalog_definition.is_empty():
		return Vector2i(GRID_WIDTH, GRID_HEIGHT)
	var grid_size: Dictionary = catalog_definition.grid_size
	return Vector2i(int(grid_size.get("width", GRID_WIDTH)), int(grid_size.get("height", GRID_HEIGHT)))


## Player spawn tiles for this battle: `catalog_definition`'s own
## player_spawns when present, else this file's own PLAYER_START_POSITIONS
## constant -- see _board_dimensions()'s identical fallback rule.
func _player_spawn_positions(catalog_definition: Dictionary) -> Array[Vector2i]:
	if catalog_definition.is_empty() or (catalog_definition.player_spawns as Array).is_empty():
		return PLAYER_START_POSITIONS
	return catalog_definition.player_spawns


## Enemy spawn tiles for this battle -- see _player_spawn_positions()'s
## identical doc comment, mirrored for ENEMY_START_POSITIONS.
func _enemy_spawn_positions(catalog_definition: Dictionary) -> Array[Vector2i]:
	if catalog_definition.is_empty() or (catalog_definition.enemy_spawns as Array).is_empty():
		return ENEMY_START_POSITIONS
	return catalog_definition.enemy_spawns


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
	_update_highlights()
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
	if is_incapacitated(unit) or unit.action_points_remaining < MOVE_ACTION_POINT_COST:
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
	if is_incapacitated(unit) or unit.action_points_remaining < MOVE_ACTION_POINT_COST:
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
	if is_incapacitated(unit) or unit.action_points_remaining < MOVE_ACTION_POINT_COST:
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


## --- Battlefield visibility (Stage 5 D2) ------------------------------------
##
## Single authoritative visibility query for the whole battle domain --
## rendering (Battlefield/_draw_units()/_update_highlights()) and UI consume
## this and get_stale_enemy_markers() below rather than keeping any
## independent fog rule of their own. This never gates move/attack legality;
## it is purely what the player currently sees vs. remembers.

## Every tile with unobstructed line of sight from at least one living player
## unit's current position, using the same occupied-tile blocking every
## other LOS check in this file already uses (see get_legal_attack_targets()'s
## identical blocking_tiles construction).
func get_player_visible_tiles() -> Dictionary:
	var viewers: Array[Vector2i] = []
	var blocking_tiles: Array[Vector2i] = []
	for unit in units:
		if not unit.is_alive():
			continue
		blocking_tiles.append(unit.grid_position)
		if unit.side == Side.PLAYER:
			viewers.append(unit.grid_position)
	return grid.get_visible_tiles(viewers, blocking_tiles)


## Refreshes _last_known_enemy_positions from the current board state -- call
## after any action that can change what's on the board or where (see
## _ready(), _apply_move_along_path(), try_attack_selected_unit()). For every
## living enemy currently in sight, records its true position as the
## freshest "last known" one. An enemy that just left sight keeps its
## existing memory entry untouched -- it goes on showing at the old,
## possibly-stale tile -- UNLESS the player is now looking straight at that
## remembered tile and the enemy genuinely isn't there ("proven wrong" per
## the decision ledger), in which case the stale entry is cleared outright.
## A memory entry for a unit no longer fielded at all (defeated) is dropped
## too, so a dead enemy never keeps showing a ghost marker forever.
func _refresh_battlefield_memory() -> void:
	var visible := get_player_visible_tiles()
	for unit in units:
		if unit.side != Side.ENEMY or not unit.is_alive():
			continue
		if visible.has(unit.grid_position):
			_last_known_enemy_positions[unit] = unit.grid_position
			continue
		var remembered = _last_known_enemy_positions.get(unit, null)
		if remembered != null and visible.has(remembered):
			_last_known_enemy_positions.erase(unit)
	for remembered_unit in _last_known_enemy_positions.keys():
		if not units.has(remembered_unit):
			_last_known_enemy_positions.erase(remembered_unit)


## Every currently-stale enemy (alive, remembered, but not in the player's
## current sight) paired with the last-known position rendering should draw
## it at instead of its real (unknown-to-the-player) current tile.
func get_stale_enemy_markers() -> Array[Dictionary]:
	var visible := get_player_visible_tiles()
	var markers: Array[Dictionary] = []
	for unit in _last_known_enemy_positions:
		if not units.has(unit) or visible.has(unit.grid_position):
			continue
		markers.append({"unit": unit, "position": _last_known_enemy_positions[unit]})
	return markers


## Cover's missile-only Guard bonus (Stage 5 D2's Approved values table) for
## whichever tile `tile` is. Callers gate this to a missile attack landing on
## the defender's front arc themselves (see try_attack_selected_unit()) --
## flanking bypasses Cover's Guard bonus entirely per the decision ledger's
## own Counterplay note.
func _cover_missile_guard_bonus(tile: Vector2i) -> int:
	match grid.get_cover(tile):
		GridScript.COVER_LOW:
			return GameConfig.get_int("combat", "cover_low_missile_guard_bonus", 25)
		GridScript.COVER_HIGH:
			return GameConfig.get_int("combat", "cover_high_missile_guard_bonus", 50)
		_:
			return 0


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


## --- Shared attack resolution core (Stage 5 D2) ------------------------------

## Shared hit -> Dodge -> Parry -> critical -> damage roll sequence for both
## an ordinary attack (try_attack_selected_unit()) and a free Attack of
## Opportunity (_resolve_opportunity_attack()) -- the only two ways a unit
## ever damages another in this file. Both callers compute their own
## effective_hit_chance (flank/off-balance/counter-bonus/Cover/opportunity-
## penalty already folded in, per each caller's own rules) and
## effective_crit_chance, and pass whether this specific attack is melee
## (Dodge is eligible for any attack type per the decision ledger's Approved
## values table; Parry only for melee). Owning only the roll sequence and its
## Bless/critical damage math here means the two callers can never diverge on
## either. crit_roll/damage_roll stay never-consumed on a miss, a dodge, or a
## parry, extending this file's existing "no roll on a miss" contract.
func _resolve_attack_core(attacker, defender, effective_hit_chance: float, effective_crit_chance: float, is_melee: bool) -> Dictionary:
	var hit: bool = hit_roll.call() < effective_hit_chance
	var dodged := false
	var parried := false
	if hit:
		var dodge_chance: float = GameConfig.get_float("combat", "dodge_chance", 0.10)
		if dodge_roll.call() < dodge_chance:
			dodged = true
		elif is_melee:
			var parry_chance: float = GameConfig.get_float("combat", "parry_chance", 0.10)
			if parry_roll.call() < parry_chance:
				parried = true
		if dodged or parried:
			hit = false

	var damage := 0
	var is_critical := false
	if hit:
		is_critical = crit_roll.call() < effective_crit_chance
		var raw_damage: int = damage_roll.call(attacker.damage_min, attacker.damage_max) + attacker.raw_damage_bonus + attacker.might
		var effective_resistance: int = defender.resistance
		if is_critical:
			var critical_damage_multiplier: float = GameConfig.get_float("combat", "critical_damage_multiplier", 1.5)
			raw_damage = int(round(raw_damage * critical_damage_multiplier))
			var critical_resistance_reduction: int = GameConfig.get_int("combat", "critical_resistance_reduction", 20)
			effective_resistance = maxi(0, defender.resistance - critical_resistance_reduction)
		damage = int(maxi(1, round(raw_damage * (1.0 - effective_resistance / 100.0))))
		# Bless / Paladin's doubled Bless (see PALADIN_BLESSED_STATUS_ID's own
		# doc comment): mutually exclusive statuses -- try_cast_spell()'s
		# "bless" match arm only ever applies one or the other per cast, never
		# both -- so this is effectively if/elif, just written as two
		# independent checks for symmetry with the hit-chance site below.
		if has_status(attacker, BLESSED_STATUS_ID):
			damage = int(maxi(1, round(damage * BLESS_DAMAGE_MULTIPLIER)))
		elif has_status(attacker, PALADIN_BLESSED_STATUS_ID):
			damage = int(maxi(1, round(damage * PALADIN_BLESS_DAMAGE_MULTIPLIER)))
		defender.take_damage(damage)
		# Sleep's own interruption rule (Stage 5 D3, explicit user
		# requirement): any LANDED attack against a sleeping unit, from
		# either side, wakes it immediately -- before its natural round-
		# boundary expiry. A dodge/parry (hit == false, handled above this
		# block) or a plain miss never wakes it; only a hit that actually
		# reaches here does. Shared by both callers of this function
		# (try_attack_selected_unit()/_resolve_opportunity_attack()), so
		# neither path can forget to wake a sleeping defender.
		defender.statuses.erase(SLEEPING_STATUS_ID)

	return {"hit": hit, "critical": is_critical, "damage": damage, "dodged": dodged, "parried": parried}


## Bookkeeping a successful Dodge or Parry sets up (Stage 5 D2's Counterplay
## note): the attacker becomes off-balance for the whole of their own next
## turn either way; a Parry additionally grants the defender a melee
## counter-bonus against that SAME attacker on the defender's own next turn.
## Both are *_pending fields -- see Unit.gd's own doc comment and end_turn()'s
## _advance_reaction_timers(), which is what actually activates and later
## expires them at the documented time.
func _apply_evasion_reactions(attacker, defender, dodged: bool, parried: bool) -> void:
	if not dodged and not parried:
		return
	attacker.off_balance_pending = true
	if parried:
		defender.counter_bonus_pending_against = attacker


## Shared per-defender modifier computation for a direct melee/ranged attack
## (flank, Cover, off-balance, Bless, Parry's counter-bonus, Lock On, Called
## Shot, and the resulting effective_defense/effective_hit_chance/effective_
## crit_chance) -- factored out of try_attack_selected_unit()'s original
## inline body so Chain Blow's second strike (Stage 5 D4, _resolve_chain_
## blow_strike()) can compute the exact same formula fresh against a
## DIFFERENT defender, rather than reusing the primary target's own numeric
## chances (each defender's own Guard/flank/off-balance status must apply to
## it, not to whichever defender happened to be attacked first). `attacker`'s
## facing/position are read as they stand at call time -- callers that also
## move/reposition the attacker must do so before calling this, same as the
## original inline code required. is_called_shot (Stage 5 D4, Archer's
## Called Shot perk) defaults false for every existing caller (Chain Blow
## never called-shots) -- see _execute_direct_attack()'s own doc comment for
## what setting it true changes.
func _compute_effective_attack_chances(attacker, defender, is_melee_attack: bool, is_called_shot: bool = false) -> Dictionary:
	# Flanking geometry (docs/plans/2026-08-18-critical-hits-and-flanking/
	# 03-flanking-tactics-and-combat-resolution.md): a side or rear flank
	# reduces the defender's effective Guard (raising hit chance) and adds to
	# the base critical chance Step 2 introduced.
	var flank_type: String = get_flank_type(attacker.grid_position, defender.grid_position, defender.facing)
	var guard_penalty: int = 0
	var crit_bonus: float = 0.0
	if flank_type == "side":
		guard_penalty = GameConfig.get_int("combat", "side_flank_guard_penalty", 20)
		crit_bonus = GameConfig.get_float("combat", "side_flank_crit_bonus", 0.20)
	elif flank_type == "rear":
		guard_penalty = GameConfig.get_int("combat", "rear_flank_guard_penalty", 50)
		crit_bonus = GameConfig.get_float("combat", "rear_flank_crit_bonus", 0.50)

	# Cover (Stage 5 D2's Approved values table): a missile-only Guard bonus
	# for the defender's tile, applied only against a front-facing attack --
	# flanking (side/rear) bypasses it entirely per the decision ledger's own
	# Counterplay note, so it is never added alongside a flank guard_penalty.
	var cover_tile: String = grid.get_cover(defender.grid_position)
	var cover_applied: bool = not is_melee_attack and flank_type == "front" and cover_tile != GridScript.COVER_NONE
	var cover_bonus: int = _cover_missile_guard_bonus(defender.grid_position) if cover_applied else 0
	# Off-balance (Stage 5 D2, extended by Stage 5 D4's Shield Bash): a
	# defender who whiffed against a Dodge/Parry on their own last attack, OR
	# who was Shield-Bashed, loses Guard for the whole of their current
	# marked turn -- see Unit.gd's own doc comment and end_turn()'s
	# _advance_reaction_timers(), which is the sole place off_balance_active
	# is ever set or cleared.
	var off_balance_penalty: int = (
		GameConfig.get_int("combat", "off_balance_guard_penalty", 10) if defender.off_balance_active else 0
	)

	# Temporary Guard (Stage 5 D4, Battle Mage specialization): the exact
	# opposite of off-balance above -- a defender who self-cast Temporary
	# Guard gains WARRIOR_BULWARK_GUARD's own +10 Guard magnitude (decision-
	# ledger.md's "same magnitude as the existing Bulwark perk" row) for the
	# whole of its own current marked Round, applied dynamically here rather
	# than baked into defender.defense the way Bulwark's PERMANENT bonus is
	# (see GameSession.get_effective_defense()) -- Temporary Guard is a
	# battle-local, round-boundary-cleared buff (see TEMPORARY_GUARD_STATUS_
	# ID's own doc comment/_clear_expired_statuses()), not a stat baked in at
	# battle start.
	var temporary_guard_bonus: int = (
		GameSession.WARRIOR_BULWARK_GUARD if has_status(defender, TEMPORARY_GUARD_STATUS_ID) else 0
	)

	# Called Shot (Stage 5 D4, Archer specialization): "ignores the defender's
	# Guard entirely for that one attack" (decision-ledger.md's exact wording)
	# -- effective_defense drops to 0 outright rather than subtracting flank/
	# cover/off-balance's individual pieces, since all of them are themselves
	# just modifiers to the SAME Guard number this bypasses. Mirrors the
	# existing opportunity-attack accuracy/power trade-off exactly: a flat
	# to-hit penalty (below) is the only cost, applied on top of the
	# attacker's raw hit_chance with no Guard subtraction at all.
	var effective_defense: int = (
		0 if is_called_shot
		else maxi(0, defender.defense - guard_penalty - off_balance_penalty + cover_bonus + temporary_guard_bonus)
	)
	var called_shot_penalty: float = (
		GameConfig.get_float("combat", "called_shot_to_hit_penalty", 0.10) if is_called_shot else 0.0
	)
	var effective_hit_chance: float = clampf(
		attacker.hit_chance - effective_defense / 100.0 - called_shot_penalty, MIN_HIT_CHANCE, GameSession.EFFECTIVE_HIT_CHANCE_CAP
	)
	# Bless / Paladin's doubled Bless (see try_cast_spell() and PALADIN_
	# BLESSED_STATUS_ID's own doc comment): +10 (or, for a Paladin's own cast,
	# +20) percentage points to the attacker's already-computed final hit
	# chance, composed on top of every other modifier above and still
	# re-clamped to the same cap/floor rather than bypassing them -- so a
	# doubled Bless is never a strictly-dominant option once effective_hit_
	# chance is already near GameSession.EFFECTIVE_HIT_CHANCE_CAP. Mutually
	# exclusive statuses, same as the damage-multiplier site above.
	if has_status(attacker, BLESSED_STATUS_ID):
		effective_hit_chance = clampf(
			effective_hit_chance + BLESS_HIT_CHANCE_BONUS, MIN_HIT_CHANCE, GameSession.EFFECTIVE_HIT_CHANCE_CAP
		)
	elif has_status(attacker, PALADIN_BLESSED_STATUS_ID):
		effective_hit_chance = clampf(
			effective_hit_chance + PALADIN_BLESS_HIT_CHANCE_BONUS, MIN_HIT_CHANCE, GameSession.EFFECTIVE_HIT_CHANCE_CAP
		)
	# Parry's counter-bonus (Stage 5 D2): +10% melee to-hit for the attacker
	# ONLY against the same defender who parried them last time, only during
	# the attacker's own marked turn -- see Unit.gd's counter_bonus_active_
	# against doc comment.
	if attacker.counter_bonus_active_against == defender:
		effective_hit_chance = clampf(
			effective_hit_chance + GameConfig.get_float("combat", "parry_counter_melee_hit_bonus", 0.10),
			MIN_HIT_CHANCE, GameSession.EFFECTIVE_HIT_CHANCE_CAP
		)
	# Lock On (Stage 5 D4, Archer specialization): +10% to-hit against the
	# SAME defender this attacker also attacked on the IMMEDIATELY PRECEDING
	# Round (current_round - 1 -- see current_round's own doc comment on why
	# a round-number comparison, not the off-balance-style pending/active
	# flag pair, is what this needs). Gated on the perk so an un-promoted
	# Warrior (or a Knight) never benefits from the tracking every attacker
	# already carries (Unit.last_attacked_target/last_attacked_round are
	# populated unconditionally -- see _execute_direct_attack()).
	var lock_on_applied: bool = (
		_unit_grants_action(attacker, "lock_on")
		and attacker.last_attacked_target == defender
		and attacker.last_attacked_round == current_round - 1
	)
	if lock_on_applied:
		effective_hit_chance = clampf(
			effective_hit_chance + GameConfig.get_float("combat", "lock_on_hit_chance_bonus", 0.10),
			MIN_HIT_CHANCE, GameSession.EFFECTIVE_HIT_CHANCE_CAP
		)
	var base_critical_chance: float = GameConfig.get_float("combat", "base_critical_chance", 0.05)
	var effective_crit_chance: float = clampf(base_critical_chance + crit_bonus, 0.0, 0.95)

	return {
		"flank_type": flank_type,
		"cover_tile": cover_tile,
		"cover_applied": cover_applied,
		"effective_defense": effective_defense,
		"effective_hit_chance": effective_hit_chance,
		"effective_crit_chance": effective_crit_chance,
		"called_shot": is_called_shot,
		"lock_on_applied": lock_on_applied,
	}


## Deterministic outcome label for logs/UI (Stage 5 D2 task 5's accessibility
## requirement: outcomes must be distinguishable by text/icon, not colour
## alone). Mutually exclusive: "critical"/"hit" on a landed blow, "dodged"/
## "parried" on an evaded one, "blocked" for an ordinary Guard-driven miss.
func _outcome_for(core: Dictionary) -> String:
	if core.hit:
		return "critical" if core.critical else "hit"
	if core.dodged:
		return "dodged"
	if core.parried:
		return "parried"
	return "blocked"


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
	if is_incapacitated(selected_unit):
		return false
	if selected_unit.side != active_side:
		return false

	var is_blocked := func(pos: Vector2i) -> bool: return get_unit_at(pos) != null
	var move_range: int = selected_unit.action_points_remaining / MOVE_ACTION_POINT_COST
	var path: Array[Vector2i] = grid.get_shortest_path(selected_unit.grid_position, target, move_range, is_blocked)
	if path.size() < 2:
		return false

	last_reaction_results = []
	var mover = selected_unit
	_apply_move_along_path(mover, path)
	mover.set_facing(path[-1] - path[-2])
	last_attack_result = {}
	last_targeting_failure = {}
	last_chain_blow_result = {}
	_refresh_battlefield_memory()
	return true


## Direct attacks execute immediately. A target out of immediate range/LoS is
## instead resolved via find_best_move_and_attack_tile(): all candidate and
## failure classification happens before any mutation below, so a rejected
## attack (any return false past the early guards) leaves the attacker's
## position, AP, last_attack_result, and the target's health untouched.
func try_attack_selected_unit(target_pos: Vector2i) -> bool:
	return _execute_direct_attack(target_pos, false)


## Battle Mage's Temporary Guard perk (Stage 5 D4): a SELF-CAST-ONLY perk
## action, unlike Bless (an ally-targeted spell whose ally-only gate happens
## to also permit self-targeting) -- there is no target parameter and no
## targeting UI at all; a successful call always applies TEMPORARY_GUARD_
## STATUS_ID to selected_unit itself (see _compute_effective_attack_chances()/
## _resolve_opportunity_attack()'s own doc comments for where the +10 Guard
## actually applies). Costs Sleep's exact 3 AP / 1 MP economy (SPELL_ACTION_
## POINT_COST/SPELL_MP_COST, decision-ledger.md's approved value) even though
## it is a perk (Unit.perks), not a spell (Unit.spells) -- mirrors try_cast_
## spell()'s AP/MP gate exactly, just read selected_unit.mp_remaining the same
## way. Rejects outright (no AP/MP spent, no state touched) for a unit that
## does not own the battle_mage_temporary_guard perk, is incapacitated, or is
## already carrying the status (re-casting would waste AP/MP for no further
## effect) -- mirrors try_shield_bash_selected_unit()'s perk gate.
func try_temporary_guard_selected_unit() -> bool:
	if input_locked or selected_unit == null or not selected_unit.is_alive():
		return false
	if selected_unit.side != Side.PLAYER or active_side != Side.PLAYER:
		return false
	if is_incapacitated(selected_unit):
		last_targeting_failure = {"reason": "paralyzed", "attacker": selected_unit}
		return false
	if not _unit_grants_action(selected_unit, "temporary_guard"):
		return false
	if has_status(selected_unit, TEMPORARY_GUARD_STATUS_ID):
		return false
	if selected_unit.action_points_remaining < SPELL_ACTION_POINT_COST or selected_unit.mp_remaining < SPELL_MP_COST:
		last_targeting_failure = {"reason": "insufficient_ap"}
		return false

	apply_status(selected_unit, TEMPORARY_GUARD_STATUS_ID)
	selected_unit.action_points_remaining -= SPELL_ACTION_POINT_COST
	selected_unit.mp_remaining -= SPELL_MP_COST
	last_targeting_failure = {}
	last_attack_result = {
		"type": "perk", "perk_id": GameSession.BATTLE_MAGE_TEMPORARY_GUARD_PERK_ID, "caster": selected_unit,
	}
	_spawn_combat_text(
		_floating_text_anchor(selected_unit), tr("battle.floating.temporary_guard"), FloatingTextScript.TYPE_TEMPORARY_GUARD
	)
	return true


## Stage 5 D4's Shield Bash perk: identical action to a plain attack (same AP
## cost, same to-hit/damage resolution, same move-and-attack fallback --
## reuses _execute_direct_attack() with is_shield_bash=true) except a landed
## hit ALSO applies the exact same off-balance status Dodge/Parry already
## apply (see _execute_direct_attack()'s own doc comment on the reuse).
## Rejects outright (no AP spent, no state touched) for a unit that does not
## own the knight_shield_bash perk -- mirrors try_cast_spell()'s own
## adventurer_knows_spell()-style gate, just read from Unit.perks instead.
func try_shield_bash_selected_unit(target_pos: Vector2i) -> bool:
	if selected_unit == null or not _unit_grants_action(selected_unit, "shield_bash"):
		return false
	return _execute_direct_attack(target_pos, true)


## Stage 5 D4's Called Shot perk (Archer specialization): identical action to
## a plain attack (same AP cost, same targeting/move-and-attack fallback --
## reuses _execute_direct_attack() with is_called_shot=true) except the
## to-hit formula ignores the defender's Guard entirely and applies a flat
## -10% to-hit penalty instead (see _compute_effective_attack_chances()'s own
## doc comment). Rejects outright (no AP spent, no state touched) for a unit
## that does not own the archer_called_shot perk -- mirrors try_shield_bash_
## selected_unit()'s identical gate.
func try_called_shot_selected_unit(target_pos: Vector2i) -> bool:
	if selected_unit == null or not _unit_grants_action(selected_unit, "called_shot"):
		return false
	return _execute_direct_attack(target_pos, false, true)


## Shared body for try_attack_selected_unit()/try_shield_bash_selected_unit()/
## try_called_shot_selected_unit() (Stage 5 D4): is_shield_bash gates whether
## a landed hit also off-balances the defender; is_called_shot gates the
## Guard-bypass/flat-penalty to-hit formula (see _compute_effective_attack_
## chances()). Neither flag changes AP cost, targeting, or the move-and-
## attack fallback -- both Shield Bash and Called Shot are normal attacks
## with a bonus rule, not a separate action economy. Chain Blow (also Stage
## 5 D4) is independent of both flags: it triggers off ANY landed melee
## attack from any entry point, at most once per Round per attacker (see
## Unit.chain_blow_used_this_round, cleared in _clear_expired_statuses()).
## Lock On's own tracking (Unit.last_attacked_target/last_attacked_round) is
## likewise stamped unconditionally near the end of this function for every
## attacker, regardless of is_shield_bash/is_called_shot or which perks the
## attacker owns -- see current_round's own doc comment.
func _execute_direct_attack(target_pos: Vector2i, is_shield_bash: bool, is_called_shot: bool = false) -> bool:
	if input_locked or selected_unit == null or not selected_unit.is_alive():
		return false
	var target = get_unit_at(target_pos)
	if target == null or target.side == selected_unit.side or not target.is_alive():
		return false
	if selected_unit.side != active_side:
		return false
	if is_incapacitated(selected_unit):
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
	last_reaction_results = []
	last_chain_blow_result = {}
	if move_tile != null:
		var move_range: int = selected_unit.action_points_remaining / MOVE_ACTION_POINT_COST
		var is_blocked := func(pos: Vector2i) -> bool: return get_unit_at(pos) != null
		var path: Array[Vector2i] = grid.get_shortest_path(selected_unit.grid_position, move_tile, move_range, is_blocked)
		if not path.is_empty():
			_apply_move_along_path(selected_unit, path)
		# A departure Attack of Opportunity can defeat the mover before it
		# ever reaches melee range of its own intended target -- the move
		# itself still completed (path/AP already applied above), but a dead
		# unit cannot go on to attack. Recorded as its own outcome rather
		# than silently returning false, since the move DID succeed.
		if not selected_unit.is_alive():
			last_attack_result = {
				"type": "attack", "attacker": selected_unit, "defender": target,
				"hit": false, "damage": 0, "critical": false, "defeated": false,
				"dodged": false, "parried": false, "cover_tile": "", "cover_applied": false,
				"outcome": "aborted_by_reaction", "is_reaction": false,
			}
			_refresh_battlefield_memory()
			return true

	# The attacker turns to face the defender from its (possibly just-moved-to)
	# position, whether the strike lands or not -- see Unit.set_facing()'s
	# same wider-axis-wins tie rule, used here for a diagonal or ranged shot.
	selected_unit.set_facing(target.grid_position - selected_unit.grid_position)

	selected_unit.action_points_remaining -= BASIC_ATTACK_ACTION_POINT_COST

	var is_melee_attack: bool = selected_unit.attack_max_range == 1
	var chances := _compute_effective_attack_chances(selected_unit, target, is_melee_attack, is_called_shot)
	var flank_type: String = chances.flank_type
	var cover_tile: String = chances.cover_tile
	var cover_applied: bool = chances.cover_applied
	var effective_defense: int = chances.effective_defense
	var effective_hit_chance: float = chances.effective_hit_chance
	var effective_crit_chance: float = chances.effective_crit_chance
	var lock_on_applied: bool = chances.lock_on_applied

	# Lock On tracking (Stage 5 D4): stamped for EVERY attacker unconditionally
	# (any direct attack, hit or miss -- see Unit.last_attacked_target's own
	# doc comment), using the chances dict's own already-read PRE-attack state
	# above -- so this attack's own chance computation reads last round's
	# target, never this same attack's target. Must run after _compute_
	# effective_attack_chances() (which is the sole reader of the OLD value)
	# and before any early return past this point, so every completed attack
	# -- including one from a unit with no Lock On perk at all -- keeps this
	# state current for whichever unit next queries it.
	selected_unit.last_attacked_target = target
	selected_unit.last_attacked_round = current_round

	var core := _resolve_attack_core(selected_unit, target, effective_hit_chance, effective_crit_chance, is_melee_attack)
	_apply_evasion_reactions(selected_unit, target, core.dodged, core.parried)
	var hit: bool = core.hit
	var is_critical: bool = core.critical
	var damage: int = core.damage

	# Shield Bash (Stage 5 D4): on a landed hit ONLY (never a miss/dodge/
	# parry), also off-balances the defender for the whole of ITS own next
	# turn -- the exact same off_balance_pending/off_balance_active state
	# machine Dodge/Parry already drive (see _apply_evasion_reactions()'s own
	# doc comment), just set on the DEFENDER here instead of the attacker.
	# Reuses the mechanism byte-for-byte: no new status id, no new magnitude.
	var off_balance_applied: bool = false
	if hit and is_shield_bash:
		target.off_balance_pending = true
		off_balance_applied = true

	if hit:
		if is_critical:
			_spawn_combat_text(
				_floating_text_anchor(target), tr("battle.floating.critical") % damage, FloatingTextScript.TYPE_CRITICAL
			)
		else:
			_spawn_combat_text(
				_floating_text_anchor(target), tr("battle.floating.damage") % damage, FloatingTextScript.TYPE_DAMAGE
			)
	elif core.dodged:
		_spawn_combat_text(_floating_text_anchor(target), tr("battle.floating.dodge"), FloatingTextScript.TYPE_DODGE)
	elif core.parried:
		_spawn_combat_text(_floating_text_anchor(target), tr("battle.floating.parry"), FloatingTextScript.TYPE_PARRY)
	else:
		_spawn_combat_text(_floating_text_anchor(target), tr("battle.floating.miss"), FloatingTextScript.TYPE_MISS)
	if off_balance_applied:
		_spawn_combat_text(
			_floating_text_anchor(target), tr("battle.floating.off_balance"), FloatingTextScript.TYPE_OFF_BALANCE
		)
	# Called Shot (Stage 5 D4): shown regardless of hit/miss -- unlike off-
	# balance (a landed-hit EFFECT), the Guard-bypass/flat-penalty already
	# happened inside this attack's own chance computation the instant Called
	# Shot was chosen, so it is a fact about the ATTEMPT, not about whether it
	# succeeded (see _compute_effective_attack_chances()'s own doc comment).
	if is_called_shot:
		_spawn_combat_text(
			_floating_text_anchor(target), tr("battle.floating.called_shot"), FloatingTextScript.TYPE_CALLED_SHOT
		)
	# Lock On (Stage 5 D4): same "fact about the attempt, not the outcome"
	# reasoning as Called Shot immediately above -- the +10% bonus already
	# factored into effective_hit_chance regardless of whether this roll
	# lands.
	if lock_on_applied:
		_spawn_combat_text(
			_floating_text_anchor(target), tr("battle.floating.locked_on"), FloatingTextScript.TYPE_LOCKED_ON
		)
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
		"dodged": core.dodged,
		"parried": core.parried,
		"cover_tile": cover_tile,
		"cover_applied": cover_applied,
		"outcome": _outcome_for(core),
		"is_reaction": false,
		"shield_bash": is_shield_bash,
		"off_balance_applied": off_balance_applied,
		"called_shot": is_called_shot,
		"lock_on_applied": lock_on_applied,
	}
	if hit:
		if _dispatch_completed_hit(selected_unit, target):
			last_attack_result["thorn_triggered"] = true
		completed_hit.emit(last_attack_result)
	if defeated and target.side == Side.ENEMY:
		enemy_defeated.emit(target)

	# Chain Blow (Stage 5 D4): triggers off ANY landed melee attack from this
	# same action (a plain Attack or a Shield Bash both count -- is_shield_
	# bash plays no role here), at most once per Round per attacker. Must run
	# after the primary strike's own bookkeeping above so a defeated primary
	# target is already erased from `units` before the second-target search
	# below (which reads `units`) runs.
	if hit and is_melee_attack and _unit_grants_action(selected_unit, "chain_blow"):
		if not selected_unit.chain_blow_used_this_round:
			var second_target = _find_chain_blow_second_target(selected_unit, target)
			if second_target != null:
				selected_unit.chain_blow_used_this_round = true
				last_chain_blow_result = _resolve_chain_blow_strike(selected_unit, second_target, is_melee_attack)

	_refresh_battlefield_memory()
	return true


## Stage 5 D4's Chain Blow perk: the second, bonus target -- the first living
## enemy of `attacker` (any unit not on attacker's own side, per this file's
## existing two-side model) other than `primary_target` itself that is melee-
## adjacent (Grid.is_attack_adjacent(), the same 8-directional check Attacks
## of Opportunity use) to attacker's OWN position, scanned in `units`' own
## stable build order for deterministic, byte-identical replay under a fixed
## seed. Adjacent to the ATTACKER (a cleave at the swing's origin), not to
## primary_target -- the design doc's "also strikes one additional adjacent
## enemy" reads naturally as "another enemy your swing can also reach", not
## an enemy standing next to the enemy you just hit. Returns null if none
## qualifies (e.g. a solitary enemy, or every other enemy already dead).
func _find_chain_blow_second_target(attacker, primary_target):
	for candidate in units:
		if candidate == primary_target or candidate.side == attacker.side or not candidate.is_alive():
			continue
		if grid.is_attack_adjacent(attacker.grid_position, candidate.grid_position):
			return candidate
	return null


## Resolves Chain Blow's bonus second strike (Stage 5 D4): reuses the exact
## same to-hit/damage formula the primary attack just used --
## _compute_effective_attack_chances() then _resolve_attack_core(), called a
## second time against `second_target` (its own Guard/flank/cover/off-balance
## read fresh, since it is a different defender than the primary target) --
## rather than reusing the primary target's own numeric chances. No AP cost
## (Chain Blow is free), no move (the second target must already be
## attacker-adjacent to have been found at all). Feeds the same downstream
## bookkeeping (Thorn rune dispatch, kill XP, defeat cleanup, floating text)
## as a primary strike so a Chain Blow kill is never XP- or rune-invisible.
func _resolve_chain_blow_strike(attacker, second_target, is_melee_attack: bool) -> Dictionary:
	var chances := _compute_effective_attack_chances(attacker, second_target, is_melee_attack)
	var core := _resolve_attack_core(
		attacker, second_target, chances.effective_hit_chance, chances.effective_crit_chance, is_melee_attack
	)
	_apply_evasion_reactions(attacker, second_target, core.dodged, core.parried)

	# Marked distinctly from an ordinary attack's own hit/miss/dodge/parry
	# text (spawned unconditionally, whatever this strike's own outcome is)
	# so this second strike never reads as an unexplained duplicate hit --
	# never colour-only feedback (Stage 4's accessibility carryover).
	_spawn_combat_text(_floating_text_anchor(second_target), tr("battle.floating.chain_blow"), FloatingTextScript.TYPE_CHAIN_BLOW)

	if core.hit:
		if core.critical:
			_spawn_combat_text(
				_floating_text_anchor(second_target), tr("battle.floating.critical") % core.damage, FloatingTextScript.TYPE_CRITICAL
			)
		else:
			_spawn_combat_text(
				_floating_text_anchor(second_target), tr("battle.floating.damage") % core.damage, FloatingTextScript.TYPE_DAMAGE
			)
	elif core.dodged:
		_spawn_combat_text(_floating_text_anchor(second_target), tr("battle.floating.dodge"), FloatingTextScript.TYPE_DODGE)
	elif core.parried:
		_spawn_combat_text(_floating_text_anchor(second_target), tr("battle.floating.parry"), FloatingTextScript.TYPE_PARRY)
	else:
		_spawn_combat_text(_floating_text_anchor(second_target), tr("battle.floating.miss"), FloatingTextScript.TYPE_MISS)

	var defeated: bool = core.hit and not second_target.is_alive()
	if defeated:
		AudioManager.play_sfx("sfx_unit_death")
		units.erase(second_target)
		if second_target.side == Side.PLAYER and second_target.adventurer_id != "":
			defeated_player_health_by_id[second_target.adventurer_id] = second_target.health

	var result := {
		"type": "attack",
		"attacker": attacker,
		"defender": second_target,
		"hit": core.hit,
		"damage": core.damage,
		"critical": core.critical,
		"defeated": defeated,
		"flank": chances.flank_type,
		"effective_defense": chances.effective_defense,
		"effective_hit_chance": chances.effective_hit_chance,
		"effective_crit_chance": chances.effective_crit_chance,
		"dodged": core.dodged,
		"parried": core.parried,
		"cover_tile": chances.cover_tile,
		"cover_applied": chances.cover_applied,
		"outcome": _outcome_for(core),
		"is_reaction": false,
		"is_chain_blow": true,
	}
	if core.hit:
		if _dispatch_completed_hit(attacker, second_target):
			result["thorn_triggered"] = true
		completed_hit.emit(result)
	if defeated and second_target.side == Side.ENEMY:
		enemy_defeated.emit(second_target)
	return result


## --- Attacks of Opportunity (Stage 5 D2) -------------------------------------

## Executes a computed multi-tile route: resolves any Attack-of-Opportunity
## departures along the way (see _trigger_opportunity_attacks_along_path()),
## then moves the unit to the route's final tile and spends its AP. The move
## always completes at its full intended destination and cost, whether or
## not any triggered reaction lands (the approved design's own "the move
## completes regardless of whether the attack hits") -- even when the mover
## is defeated mid-route, since a dead unit's position/AP no longer matter to
## anything that reads them afterward (see try_attack_selected_unit()'s own
## is_alive() guard right after its move-and-attack branch calls this).
func _apply_move_along_path(unit, path: Array[Vector2i]) -> void:
	_trigger_opportunity_attacks_along_path(unit, path)
	unit.grid_position = path[-1]
	unit.action_points_remaining -= (path.size() - 1) * MOVE_ACTION_POINT_COST


## Attacks of Opportunity (Stage 5 D2's "Opportunity-attack trigger scope"
## row, decision-ledger.md's Approved values table): for every step of `path`
## where `unit` departs a living enemy's melee-attack adjacency
## (Grid.is_attack_adjacent(), the same 8-directional adjacency ordinary
## melee attacks use) without still being adjacent on the very next tile,
## that enemy gets exactly one free melee attack against `unit` for this
## whole move action -- however many times `unit` departs/re-enters that
## SAME enemy's adjacency within this one path, `already_reacted` below
## ensures only the first departure fires. Only a melee-capable unit
## (attack_max_range == 1) can make an opportunity attack: the design doc's
## "-10% melee hit penalty" wording assumes the reactor's own melee stat,
## which a ranged unit has no occasion to use this way. An is_incapacitated()
## reactor (Paralyzed or Sleeping) also can't react -- an incapacitated unit
## cannot act on its own turn, and a free attack is still the reactor acting
## on its own initiative. Populates
## last_reaction_results (cleared by every caller before it calls this) so
## Battlefield can log every reaction from one move action, and stops
## issuing further reactions the moment `unit` is defeated, since a dead
## unit cannot keep moving through anyone's threatened tiles.
func _trigger_opportunity_attacks_along_path(unit, path: Array[Vector2i]) -> void:
	if path.size() < 2:
		return
	var already_reacted: Array = []
	for step_index in path.size() - 1:
		var from_tile: Vector2i = path[step_index]
		var to_tile: Vector2i = path[step_index + 1]
		for reactor in units:
			if reactor.side == unit.side or not reactor.is_alive():
				continue
			if reactor.attack_max_range != 1 or already_reacted.has(reactor):
				continue
			if is_incapacitated(reactor):
				continue
			if not grid.is_attack_adjacent(reactor.grid_position, from_tile):
				continue
			if grid.is_attack_adjacent(reactor.grid_position, to_tile):
				continue
			already_reacted.append(reactor)
			last_reaction_results.append(_resolve_opportunity_attack(reactor, unit))
			if not unit.is_alive():
				return


## Free melee attack an adjacent enemy gets when `mover` departs its
## adjacency mid-move (see _trigger_opportunity_attacks_along_path()). Costs
## `reactor` no AP and never touches selected_unit/active_side, and uses the
## exact same _resolve_attack_core() roll sequence every other attack in this
## file uses, so a reaction can never diverge from ordinary combat math
## beyond its own documented -10% melee penalty (no flanking bonus -- the
## design doc's Attacks-of-Opportunity section names only the flat penalty).
func _resolve_opportunity_attack(reactor, mover) -> Dictionary:
	var off_balance_penalty: int = (
		GameConfig.get_int("combat", "off_balance_guard_penalty", 10) if mover.off_balance_active else 0
	)
	# Temporary Guard (Stage 5 D4, Battle Mage specialization): mirrors off_
	# balance_penalty's own precedent immediately above -- a dynamic, per-
	# defender status must apply here too, not only in _compute_effective_
	# attack_chances(), or a Temporary-Guarded mover would be inconsistently
	# easier to hit via an Attack of Opportunity than via a direct attack.
	# See that function's own doc comment on this bonus.
	var temporary_guard_bonus: int = (
		GameSession.WARRIOR_BULWARK_GUARD if has_status(mover, TEMPORARY_GUARD_STATUS_ID) else 0
	)
	var effective_defense: int = maxi(0, mover.defense - off_balance_penalty + temporary_guard_bonus)
	var opportunity_penalty: float = GameConfig.get_float("combat", "opportunity_attack_melee_hit_penalty", 0.10)
	var effective_hit_chance: float = clampf(
		reactor.hit_chance - effective_defense / 100.0 - opportunity_penalty, MIN_HIT_CHANCE, GameSession.EFFECTIVE_HIT_CHANCE_CAP
	)
	if reactor.counter_bonus_active_against == mover:
		effective_hit_chance = clampf(
			effective_hit_chance + GameConfig.get_float("combat", "parry_counter_melee_hit_bonus", 0.10),
			MIN_HIT_CHANCE, GameSession.EFFECTIVE_HIT_CHANCE_CAP
		)
	var effective_crit_chance: float = GameConfig.get_float("combat", "base_critical_chance", 0.05)

	var core := _resolve_attack_core(reactor, mover, effective_hit_chance, effective_crit_chance, true)
	_apply_evasion_reactions(reactor, mover, core.dodged, core.parried)

	var defeated: bool = core.hit and not mover.is_alive()
	if defeated:
		AudioManager.play_sfx("sfx_unit_death")
		units.erase(mover)
		if mover.side == Side.PLAYER and mover.adventurer_id != "":
			defeated_player_health_by_id[mover.adventurer_id] = mover.health

	var result := {
		"type": "reaction",
		"reactor": reactor,
		"mover": mover,
		"hit": core.hit,
		"damage": core.damage,
		"critical": core.critical,
		"defeated": defeated,
		"dodged": core.dodged,
		"parried": core.parried,
		"effective_defense": effective_defense,
		"effective_hit_chance": effective_hit_chance,
		"effective_crit_chance": effective_crit_chance,
		"is_reaction": true,
		"outcome": _outcome_for(core),
	}
	if core.hit:
		if _dispatch_completed_hit(reactor, mover):
			result["thorn_triggered"] = true
		completed_hit.emit(result)
	if defeated and mover.side == Side.ENEMY:
		enemy_defeated.emit(mover)
	_spawn_reaction_combat_text(mover, result)
	return result


## Presentation feedback for one reaction, mirroring try_attack_selected_
## unit()'s own hit/critical/dodge/parry/miss floating-text branch so a
## reaction reads with the same distinct text/icon per outcome (Stage 4's
## "never colour-only" accessibility carryover) rather than a bespoke look.
func _spawn_reaction_combat_text(mover, result: Dictionary) -> void:
	var anchor := _floating_text_anchor(mover)
	if result.hit:
		if result.critical:
			_spawn_combat_text(anchor, tr("battle.floating.critical") % result.damage, FloatingTextScript.TYPE_CRITICAL)
		else:
			_spawn_combat_text(anchor, tr("battle.floating.damage") % result.damage, FloatingTextScript.TYPE_DAMAGE)
	elif result.dodged:
		_spawn_combat_text(anchor, tr("battle.floating.dodge"), FloatingTextScript.TYPE_DODGE)
	elif result.parried:
		_spawn_combat_text(anchor, tr("battle.floating.parry"), FloatingTextScript.TYPE_PARRY)
	else:
		_spawn_combat_text(anchor, tr("battle.floating.miss"), FloatingTextScript.TYPE_MISS)


## Tactical Retreat (docs/plans/2026-08-18-core-loop-and-engagement/
## 02-permadeath-retreat-and-economy-floor.md): only callable during the
## player's active turn, matching every other player action in this file.
## Ends the battle immediately -- every living player unit rolls its own
## distance-based consequence against the nearest living enemy (see
## RETREAT_OUTCOME_THRESHOLDS), this battle's own unbanked loot is
## discarded outright (a retreat never banks the active battle context's own
## reward into the owning party's carry -- see GameSession.
## resolve_battle_retreat()), and retreat_resolved fires once with every
## unit's result so Battlefield can log the outcome and hand off routing to
## GameManager.retreat_from_battle().
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

	GameSession.resolve_battle_retreat(GameSession.get_active_battle_context().get("battle_id", ""))
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
	if is_incapacitated(selected_unit):
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
	if is_incapacitated(selected_unit):
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
## 04-cleric-class-and-scout-reconnaissance.md): "heal" (restore an
## injectable 2-8 HP, capped at max, on a living ally that isn't already at
## full health) and "bless" (apply the battle-local BLESSED_STATUS_ID status
## -- see try_attack_selected_unit() -- to a living ally not already blessed
## by either Bless variant; Stage 5 D4's Paladin specialization applies the
## stronger PALADIN_BLESSED_STATUS_ID variant instead, keyed purely to
## whether the CASTER is a promoted Paladin -- see _unit_is_paladin() and
## PALADIN_BLESSED_STATUS_ID's own doc comment) both target an ALLY. Stage 5
## D3 adds "sleep" (apply the battle-local SLEEPING_STATUS_ID status -- see
## is_incapacitated() -- to a living
## ENEMY, gated by a magic-resistance roll that can fully negate the effect
## without refunding the cast; see the "sleep" match arm below) -- an
## ENEMY-only targeting branch rather than sharing Heal/Bless's ally-only one.
## Stage 5 D4 adds "fire_bolt" (Battle Mage specialization): also ENEMY-only,
## dealing an injectable 2-8 damage (SPELL_HEAL_MIN/SPELL_HEAL_MAX's own
## magnitude), HALVED (not negated) by the same magic-resistance roll --
## unlike Sleep's binary negate, matching combat-system.md's literal "Fire
## Bolt damage reduced by half" wording. All four share the same 3 AP / 1 MP cost and
## the same occupied-endpoint line-of-sight range (see grid.has_line_of_
## sight()/get_manhattan_distance(), the same primitives ranged attacks
## already use via get_legal_attack_targets()) -- 0-3 tiles by default, 0-4
## once the caster has chosen the Meditation perk (see GameSession.get_
## effective_spell_range(), consulted per-caster below rather than a flat
## constant, per docs/plans/2026-08-21-stage-2-party-readiness/
## 02-class-progression-and-perks.md's "effects belong in explicit
## GameSession.get_effective_* readers" rule). Every validation runs before
## any mutation, matching every other try_* action in this file, so a
## rejected cast leaves AP/MP/target state untouched.
func try_cast_spell(spell_id: String, target_pos: Vector2i) -> bool:
	if input_locked or selected_unit == null or not selected_unit.is_alive():
		return false
	if selected_unit.side != Side.PLAYER or active_side != Side.PLAYER:
		return false
	if is_incapacitated(selected_unit):
		last_targeting_failure = {"reason": "paralyzed", "attacker": selected_unit}
		return false
	if not selected_unit.spells.has(spell_id):
		return false
	if selected_unit.action_points_remaining < SPELL_ACTION_POINT_COST or selected_unit.mp_remaining < SPELL_MP_COST:
		last_targeting_failure = {"reason": "insufficient_ap"}
		return false

	var target = get_unit_at(target_pos)
	if target == null or not target.is_alive():
		return false
	# Sleep/Fire Bolt target a living ENEMY; Heal/Bless target a living ALLY --
	# see this function's own doc comment above. Deliberately its own branch,
	# not a shared ally-only gate, so a future enemy-targeted spell has an
	# obvious place to join without touching Heal/Bless's existing rule.
	if spell_id == "sleep" or spell_id == "fire_bolt":
		if target.side == selected_unit.side:
			return false
	elif target.side != selected_unit.side:
		return false

	var distance: int = grid.get_manhattan_distance(selected_unit.grid_position, target_pos)
	if distance > GameSession.get_effective_spell_range(selected_unit.adventurer_id):
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
			# The "already blessed" guard must reject a mixed cast either way --
			# a target already carrying the REGULAR Bless can't also receive
			# the Paladin variant, and vice versa -- so it checks both status
			# ids, never just BLESSED_STATUS_ID alone.
			if has_status(target, BLESSED_STATUS_ID) or has_status(target, PALADIN_BLESSED_STATUS_ID):
				return false
			# Stage 5 D4 (Paladin specialization): keyed purely to CASTER
			# identity (see _unit_is_paladin()'s own doc comment), not to the
			# target -- a promoted Paladin's own cast always applies the
			# doubled variant, on any ally including itself, exactly like a
			# plain Cleric's cast always applies the regular one.
			var is_paladin_caster: bool = _unit_is_paladin(selected_unit)
			var bless_status_id: String = PALADIN_BLESSED_STATUS_ID if is_paladin_caster else BLESSED_STATUS_ID
			apply_status(target, bless_status_id)
			selected_unit.action_points_remaining -= SPELL_ACTION_POINT_COST
			selected_unit.mp_remaining -= SPELL_MP_COST
			last_targeting_failure = {}
			last_attack_result = {
				"type": "spell", "spell_id": spell_id, "caster": selected_unit, "target": target,
				"doubled": is_paladin_caster,
			}
			AudioManager.play_sfx("sfx_spell_bless")
			# Distinct floating text so a player can tell the promotion
			# mattered -- a regular Bless spawns none (see the "battle.status.
			# spell_bless"/"battle.log.spell.bless" log/status lines instead,
			# and Battlefield._describe_step()/_log_spell()'s own "doubled"
			# branch for the matching log/status distinction).
			if is_paladin_caster:
				_spawn_combat_text(
					_floating_text_anchor(target), tr("battle.floating.bless_paladin"), FloatingTextScript.TYPE_PALADIN_BLESS
				)
			return true
		"sleep":
			if has_status(target, SLEEPING_STATUS_ID):
				return false
			selected_unit.action_points_remaining -= SPELL_ACTION_POINT_COST
			selected_unit.mp_remaining -= SPELL_MP_COST
			# Magic-resistance roll (Stage 5 D3's approved formula): a roll
			# below (magic_resistance - spellcasting) / 100 fully negates the
			# cast -- binary, no partial effect -- but the AP/MP cost above is
			# already spent either way, matching combat-system.md's "negates
			# ... the effect" wording (the cast still happens; only the
			# effect doesn't land). Clamped to [0, 1] defensively: a caster
			# whose spellcasting exceeds the target's magic_resistance
			# already naturally never resists (a negative chance), and this
			# keeps a pathological over-100 magic_resistance from ever
			# exceeding a real probability.
			var resist_chance: float = clampf(
				(float(target.magic_resistance) - float(selected_unit.spellcasting)) / 100.0, 0.0, 1.0
			)
			var resisted: bool = sleep_resist_roll.call() < resist_chance
			if not resisted:
				apply_status(target, SLEEPING_STATUS_ID)
			last_targeting_failure = {}
			last_attack_result = {
				"type": "spell", "spell_id": spell_id, "caster": selected_unit, "target": target,
				"resisted": resisted, "outcome": "resisted" if resisted else "applied",
			}
			_spawn_combat_text(
				_floating_text_anchor(target),
				tr("battle.floating.sleep_resisted") if resisted else tr("battle.floating.sleep"),
				FloatingTextScript.TYPE_RESISTED if resisted else FloatingTextScript.TYPE_SLEEP
			)
			return true
		"fire_bolt":
			selected_unit.action_points_remaining -= SPELL_ACTION_POINT_COST
			selected_unit.mp_remaining -= SPELL_MP_COST
			# Same magic-resistance formula as Sleep (Stage 5 D4's approved
			# reuse), but HALVES the roll rather than negating it outright --
			# see this function's own doc comment above. maxi(1, ...) mirrors
			# every other damage source in this file (_resolve_attack_core())
			# never landing a zero-damage hit.
			var resist_chance: float = clampf(
				(float(target.magic_resistance) - float(selected_unit.spellcasting)) / 100.0, 0.0, 1.0
			)
			var resisted: bool = fire_bolt_resist_roll.call() < resist_chance
			var raw_damage: int = fire_bolt_damage_roll.call(SPELL_HEAL_MIN, SPELL_HEAL_MAX)
			var damage: int = maxi(1, int(round(raw_damage / 2.0))) if resisted else raw_damage
			target.take_damage(damage)
			# Fire Bolt can kill (unlike Heal/Bless/Sleep, which never deal
			# damage) -- mirrors _execute_direct_attack()'s own defeated
			# handling exactly: erase from `units` (frees the tile, stops
			# rendering a corpse) and emit enemy_defeated so kill XP still
			# fires (Battlefield._award_kill_xp() is wired to this signal, not
			# to last_attack_result). Fire Bolt is enemy-only (see this
			# function's own targeting gate above), so there is no player-side
			# permadeath bookkeeping to mirror here.
			var defeated: bool = not target.is_alive()
			if defeated:
				AudioManager.play_sfx("sfx_unit_death")
				units.erase(target)
			last_targeting_failure = {}
			last_attack_result = {
				"type": "spell", "spell_id": spell_id, "caster": selected_unit, "target": target,
				"damage": damage, "resisted": resisted, "outcome": "resisted" if resisted else "hit",
				"defeated": defeated,
			}
			_spawn_combat_text(
				_floating_text_anchor(target),
				tr("battle.floating.fire_bolt_resisted") % damage if resisted else tr("battle.floating.damage") % damage,
				FloatingTextScript.TYPE_RESISTED if resisted else FloatingTextScript.TYPE_DAMAGE
			)
			if defeated:
				enemy_defeated.emit(target)
			return true
		_:
			return false


func try_step_selected_unit(direction: Vector2i) -> bool:
	if input_locked:
		return false
	if selected_unit == null or not selected_unit.is_alive():
		return false
	if is_incapacitated(selected_unit):
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
	last_reaction_results = []
	_apply_move_along_path(selected_unit, [selected_unit.grid_position, target])
	last_attack_result = {}
	last_targeting_failure = {}
	last_chain_blow_result = {}
	_refresh_battlefield_memory()
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
		current_round += 1
	for unit in units:
		if unit.side == active_side:
			unit.action_points_remaining = unit.max_action_points
			_advance_reaction_timers(unit)
	# A new round starts once control returns to the player; open it with the
	# first party member already selected rather than forcing a manual pick.
	_select_unit(_first_living_player_unit() if active_side == Side.PLAYER else null)


## Off-balance/counter-bonus timing (Stage 5 D2's "off-balance/counter
## bonuses expire at the documented time" requirement): called once per unit
## exactly when their OWN side's turn starts. A *_pending flag set during the
## unit's previous turn (from whiffing against a Dodge/Parry, or from a
## successful Parry -- see _apply_evasion_reactions()) is promoted to
## *_active here, giving it effect for the ENTIRETY of this turn; an
## already-*_active flag (active during the unit's last turn) expires here
## instead. This gives exactly one full "their next turn" window per
## trigger, never longer and never starting early.
func _advance_reaction_timers(unit) -> void:
	if unit.off_balance_active:
		unit.off_balance_active = false
	elif unit.off_balance_pending:
		unit.off_balance_active = true
		unit.off_balance_pending = false
	if unit.counter_bonus_active_against != null:
		unit.counter_bonus_active_against = null
	elif unit.counter_bonus_pending_against != null:
		unit.counter_bonus_active_against = unit.counter_bonus_pending_against
		unit.counter_bonus_pending_against = null


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
	if is_incapacitated(unit):
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
				steps.append_array(last_reaction_results)
				continue
			break
		var destination := _best_enemy_move(unit, target)
		var from: Vector2i = unit.grid_position
		if destination != from and try_move_selected_unit(destination):
			steps.append({"type": ENEMY_STEP_MOVE, "unit": unit, "from": from, "to": destination})
			steps.append_array(last_reaction_results)
			# An Attack of Opportunity triggered by this very move can defeat
			# `unit` before it ever gets another action -- stop here rather
			# than letting the loop drive a dead unit's phantom next move (see
			# _resolve_opportunity_attack()'s own doc comment on this file's
			# is_alive() action guards).
			if not unit.is_alive():
				break
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


## Stage 5 D4 (Knight specialization): true iff `unit` (never null-checked by
## itself -- every caller below already guards selected_unit/attacker first)
## carries a perk among its own hydrated perks (see Unit.perks' own doc
## comment -- populated from GameSession.get_adventurer(...).progression.
## perks in _ready(), or from a scenario's explicit "perks" field in
## BattleStateFactory._build_player_unit()) that GRANTS action_id.
##
## Stage 6 Step 4: replaces the old per-perk-id `_unit_has_perk(unit,
## GameSession.KNIGHT_SHIELD_BASH_PERK_ID)`-shaped ad-hoc boolean branch at
## every one of this function's 5 call sites with a single PerkEffectResolver
## lookup keyed by the ACTION the caller needs ("shield_bash"/"chain_blow"/
## "called_shot"/"temporary_guard"/"lock_on") -- which specific perk id
## currently grants that action is now PerkCatalog's own data, not a fact
## repeated at every gate. Gates Shield Bash/Chain Blow/Called Shot/Temporary
## Guard/Lock On the same way is_caster/knows_* already gate spellcasting in
## Battlefield._update_action_bar(), just read here instead since these are
## melee/self actions, not spells.
func _unit_grants_action(unit, action_id: String) -> bool:
	return unit != null and PerkEffectResolverScript.has_granted_action(unit.perks, action_id)


## Stage 5 D4 (Paladin specialization): true iff `unit` is itself a promoted
## Paladin (see Unit.specialization's own doc comment -- hydrated from
## GameSession.get_adventurer_specialization() in _ready(), or from a
## scenario's explicit "specialization" field in BattleStateFactory._build_
## player_unit()). Unlike _unit_grants_action() above, Paladin owns no perk id at
## all -- its ability is keyed purely to caster identity -- so try_cast_
## spell()'s "bless" match arm reads this directly instead.
func _unit_is_paladin(unit) -> bool:
	return unit != null and unit.specialization == "paladin"


func apply_status(unit, status_id: String) -> bool:
	if unit == null or status_id.is_empty() or has_status(unit, status_id):
		return false
	unit.statuses[status_id] = true
	return true


func has_status(unit, status_id: String) -> bool:
	return unit != null and bool(unit.statuses.get(status_id, false))


## Single source of truth for "this unit cannot act" (Stage 5 D3): true while
## `unit` carries PARALYZED_STATUS_ID (Thorn rune) or SLEEPING_STATUS_ID
## (Sleep spell) -- every move/attack/cast/item action gate in this file
## (try_move_selected_unit, try_step_selected_unit, try_attack_selected_unit,
## try_cast_spell, try_use_selected_potion, try_transfer_selected_item, the
## read-only move/attack-tile highlight helpers, the enemy AI action-taking
## path, and the attack-range highlight affordance) calls this instead of
## checking either status id directly, so a future third incapacitating
## status only ever needs to change this one place -- never a second,
## possibly-diverging copy of "cannot act."
func is_incapacitated(unit) -> bool:
	return has_status(unit, PARALYZED_STATUS_ID) or has_status(unit, SLEEPING_STATUS_ID)


func _clear_expired_statuses() -> void:
	for unit in units:
		unit.statuses.erase(PARALYZED_STATUS_ID)
		unit.statuses.erase(SLEEPING_STATUS_ID)
		# Temporary Guard (Stage 5 D4): round-boundary cleared at the exact
		# same point as Sleep/Paralyzed, per decision-ledger.md's "same round-
		# boundary Sleep/Paralyzed already clear on" row.
		unit.statuses.erase(TEMPORARY_GUARD_STATUS_ID)
		# Chain Blow (Stage 5 D4): resets at the exact same Round boundary as
		# every other round-scoped state cleared in this loop, so it triggers
		# at most once per Round per Knight, however many attacks they make.
		unit.chain_blow_used_this_round = false


## Returns true iff the Thorn rune actually triggered (and paralyzed
## `attacker`) so each caller can record "thorn_triggered" on its OWN result
## dict -- this function used to write directly into the module-level
## last_attack_result, which would have silently corrupted a reaction's
## separate result dict (see _resolve_opportunity_attack()) had it kept doing
## that, since a reaction never touches last_attack_result at all. Guards on
## is_incapacitated(attacker), not a raw PARALYZED_STATUS_ID check, so an
## already-Sleeping attacker can't also be Thorn-paralyzed on top of it --
## the same "one source of truth for cannot-act" rule is_incapacitated()
## exists to enforce everywhere else in this file.
func _dispatch_completed_hit(attacker, defender) -> bool:
	if defender.rune_id != THORN_RUNE_ID or is_incapacitated(attacker):
		return false
	if rune_trigger_roll.call() >= THORN_TRIGGER_CHANCE:
		return false
	return apply_status(attacker, PARALYZED_STATUS_ID)


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
		# (which every other mode treats as a reselect) or an enemy tile
		# (which every other mode treats as an attack) -- try_cast_spell()
		# itself decides legality per spell_id (Heal/Bless want an ally,
		# Sleep wants an enemy -- see its own doc comment), so this mode
		# never falls through to the move/attack dispatch below regardless
		# of which side was clicked.
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

		# Stage 5 D4: SHIELD_BASH mode is attack-only, exactly like ATTACK mode
		# below, but dispatches to try_shield_bash_selected_unit() instead.
		if action_mode == ActionMode.SHIELD_BASH:
			if selected_unit != null and try_shield_bash_selected_unit(tile_pos):
				_draw_units()
				_select_unit_after_action()
				return
			_set_inspected_unit(clicked_unit)
			board_changed.emit()
			return

		# Stage 5 D4: CALLED_SHOT mode is the same attack-only shape again
		# (Archer's Called Shot perk), dispatching to try_called_shot_selected_
		# unit() instead.
		if action_mode == ActionMode.CALLED_SHOT:
			if selected_unit != null and try_called_shot_selected_unit(tile_pos):
				_draw_units()
				_select_unit_after_action()
				return
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

	if action_mode == ActionMode.ATTACK or action_mode == ActionMode.SHIELD_BASH or action_mode == ActionMode.CALLED_SHOT:
		# ATTACK/SHIELD_BASH/CALLED_SHOT mode never moves -- an empty-tile
		# click is a no-op that reports attack-mode feedback (Action Mode
		# State Machine, index.md), same reason as ATTACK's own case above.
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

	_draw_cover_markers()


## Cover terrain (Stage 5 D2): hand-authored per encounter (see grid.gd's
## cover_tiles doc comment) and static for the whole battle, so this draws
## once alongside the ground tiles rather than being rebuilt every
## _update_highlights() call. A separate sibling container from tile_container
## (Terrain, not Tiles) so tile_container stays a pure ground-tile Sprite2D
## collection for anything that scans it (see test_battle_sprite_rendering.gd).
## A small badge in the tile's corner, distinct text per tier ("L"/"H") on
## top of a distinct color -- never colour-only (Stage 4's accessibility
## carryover) -- rather than a bespoke sprite this project has no art asset
## for yet.
func _draw_cover_markers() -> void:
	for child in terrain_container.get_children():
		child.queue_free()
	for tile in grid.cover_tiles:
		var tier: String = grid.get_cover(tile)
		if tier == GridScript.COVER_NONE:
			continue
		var badge := ColorRect.new()
		badge.name = "CoverMarker"
		var badge_size := Vector2(TILE_SIZE * 0.3, TILE_SIZE * 0.3)
		badge.size = badge_size
		badge.position = Vector2(tile) * TILE_SIZE + Vector2(TILE_SIZE * 0.05, TILE_SIZE * 0.05)
		badge.color = COVER_HIGH_MARKER_COLOR if tier == GridScript.COVER_HIGH else COVER_LOW_MARKER_COLOR
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		terrain_container.add_child(badge)
		var label := Label.new()
		label.text = "H" if tier == GridScript.COVER_HIGH else "L"
		label.position = badge.position
		label.size = badge_size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 14)
		terrain_container.add_child(label)


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
	# Battlefield visibility (Stage 5 D2): a stale enemy (see
	# get_stale_enemy_markers(), the single authoritative query -- this loop
	# never maintains an independent copy of that rule) is never drawn at its
	# real, unknown-to-the-player current tile; _draw_stale_enemy_marker()
	# below draws it at its last-known position instead.
	var stale_markers: Array[Dictionary] = get_stale_enemy_markers()
	var stale_units: Array = []
	for marker in stale_markers:
		stale_units.append(marker.unit)

	var sorted_units: Array = units.duplicate()
	sorted_units.sort_custom(func(a, b): return a.grid_position.y < b.grid_position.y)
	for unit in sorted_units:
		if stale_units.has(unit):
			continue
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
		# shadow_size.y (TILE_SIZE * 0.22 = 14.08) is a fixed non-integer and
		# the subtracted half-extent above is always an integer, so
		# shadow_baseline's fractional remainder is always exactly .8 --
		# round() always rounds this same .8 up, every tile, every unit; it
		# is not choosing between "up" or "down" case by case. It exists so
		# the sprite still lands on a whole pixel instead of a sub-pixel
		# offset, per this plan's "no fractional placement" invariant.
		sprite.position = Vector2(
			tile_origin.x + TILE_SIZE / 2.0,
			round(shadow_baseline - (sprite.texture.get_height() * sprite.scale.y) / 2.0)
		)
		unit_container.add_child(sprite, true)
		_add_facing_indicator(tile_origin, unit)

	for marker in stale_markers:
		_draw_stale_enemy_marker(marker.position, marker.unit)


## Last-known-position ghost (Stage 5 D2): the same catalog sprite as a real
## unit but dimmed (STALE_UNIT_MODULATE) and paired with a "?" text badge --
## never colour-only -- so it reads as "an enemy was last seen here, this may
## be outdated" rather than as a fresh, trustworthy sighting. No shadow/
## facing indicator: those are current-state cues this marker deliberately
## does not claim to have.
func _draw_stale_enemy_marker(tile_pos: Vector2i, unit) -> void:
	var tile_origin: Vector2 = Vector2(tile_pos) * TILE_SIZE
	var sprite := Sprite2D.new()
	sprite.name = "StaleMarker"
	sprite.texture = SpriteCatalog.get_unit_texture(unit.visual_key)
	sprite.scale = Vector2(4, 4)
	sprite.modulate = STALE_UNIT_MODULATE
	sprite.position = Vector2(
		tile_origin.x + TILE_SIZE / 2.0, tile_origin.y + TILE_SIZE - (sprite.texture.get_height() * sprite.scale.y) / 2.0
	)
	unit_container.add_child(sprite, true)

	var badge := Label.new()
	badge.name = "StaleMarkerBadge"
	badge.text = "?"
	badge.add_theme_color_override("font_color", STALE_MARKER_BADGE_COLOR)
	badge.add_theme_font_size_override("font_size", 20)
	badge.position = tile_origin + Vector2(TILE_SIZE * 0.7, TILE_SIZE * 0.02)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit_container.add_child(badge, true)


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


## Battlefield visibility (Stage 5 D2): a translucent dark tint over every
## tile outside get_player_visible_tiles() -- the single authoritative
## visibility query (see its own doc comment); this function never maintains
## an independent fog rule. Drawn first among highlight_container's children
## (see _update_highlights()) so selection/movement/attack highlights still
## render clearly on top of it.
func _draw_stale_tile_overlay() -> void:
	var visible_tiles := get_player_visible_tiles()
	for y in grid.height:
		for x in grid.width:
			var tile := Vector2i(x, y)
			if visible_tiles.has(tile):
				continue
			_add_highlight(tile, STALE_TILE_OVERLAY_COLOR)


func _update_highlights() -> void:
	if not is_inside_tree():
		return

	for child in highlight_container.get_children():
		child.queue_free()

	_draw_stale_tile_overlay()

	if selected_unit != null:
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

		if selected_unit.action_points_remaining >= BASIC_ATTACK_ACTION_POINT_COST and not is_incapacitated(selected_unit):
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

	# Hover ring: rendered independently of selected_unit (so it still shows,
	# e.g., between the enemy turn clearing selected_unit and the player's
	# next selection) and last, so it stays visible on top of every other
	# highlight_container fill even when the hovered tile is also a legal-move
	# or attack-target tile.
	if hovered_unit != null and hovered_unit.is_alive():
		var hover_margin := TILE_SIZE * 0.05
		var hover_ring := ColorRect.new()
		hover_ring.size = Vector2(TILE_SIZE, TILE_SIZE) - Vector2(hover_margin, hover_margin) * 2
		hover_ring.position = Vector2(hovered_unit.grid_position) * TILE_SIZE + Vector2(hover_margin, hover_margin)
		hover_ring.color = HOVER_RING_COLOR
		hover_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		highlight_container.add_child(hover_ring)
