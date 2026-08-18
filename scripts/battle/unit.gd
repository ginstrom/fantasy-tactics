extends RefCounted

var grid_position: Vector2i
var color: Color
var side: int
var max_action_points: int
var action_points_remaining: int
var max_health: int
var health: int
var damage_min: int
var damage_max: int
var hit_chance: float
var attack_name: String
# Kept on the battle-local unit so combat legality has no dependency on the
# campaign inventory shape. Step 2 populates these from weapon definitions;
# existing melee units retain the one-tile default.
var attack_min_range: int = 1
var attack_max_range: int = 1
# Empty for a unit with no backing adventurer record (e.g. every enemy).
# Lets Battlefield match a leveled-up adventurer id (from
# GameSession.award_party_xp()) back to the on-field unit whose health it
# must refresh immediately.
var adventurer_id: String
# Percent-point armor stats (see GameSession.get_effective_defense/
# get_effective_resistance). 0 for every unarmored unit — currently every
# enemy, since enemies are not migrated onto the weapon/armor system (see
# this plan's Phase A architecture note).
var defense: int
var resistance: int
# Flat damage added immediately after rolling the equipped weapon and before
# target resistance. It is battle-local derived state, never campaign state.
var raw_damage_bonus: int = 0
var might: int = 0
# XP awarded to the party when this unit is the one defeated (see
# GameSession.*_ENEMY_STATS.kill_xp). 0 and unused for player-side units.
var kill_xp: int = 0
# Human-readable label for logs/detail panels. "Warrior"/"Warrior 2" for a
# player unit (copied from the adventurer's own name — already unique per
# party member). "Kobold 1"/"Kobold 2" for an enemy unit: always indexed,
# even when only one of that type is fielded, because a battle only ever
# fields one enemy species (see GameSession.STAR_ENEMY_COMPOSITIONS) so the
# index alone already disambiguates. Empty until BattleController assigns
# it in _ready() — the constructor is intentionally not touched here (every
# existing call site constructs Unit.new() positionally; these two fields
# follow this file's existing pattern of being set directly on the
# instance instead, see e.g. defense/resistance in the tests).
var display_name: String = ""
# "Kobold" for an enemy unit (its species name, with no index) -- used to
# group kills by type. Empty for a player unit.
var enemy_type_name: String = ""
# Battle-local modifiers are copied from durable equipment when a battle
# starts. They never write back to GameSession during combat.
var rune_id: String = ""
# Status ids map to their remaining lifetime. Current statuses last through
# the active round and are cleared as the next player round begins.
var statuses: Dictionary = {}
# Cardinal facing (one of the four unit vectors below): which way this unit
# is oriented on the battlefield. BattleController assigns the side default
# in _ready() (see also BattleStateFactory, which hydrates the same default
# from ScenarioContract's normalized "facing" field), then keeps it current
# via set_facing() as the unit moves and attacks (see
# BattleController.try_step_selected_unit()/try_move_selected_unit()/
# try_attack_selected_unit()). Read by the board renderer's facing indicator
# and the unit info panel, and by Steps 2/3 of this plan (critical hits,
# flanking) for attack geometry.
var facing: Vector2i = Vector2i.RIGHT
# Tactical spellcasting (docs/plans/2026-08-18-core-loop-and-engagement/
# 04-cleric-class-and-scout-reconnaissance.md). Battle-local: BattleController
# hydrates spells/mp_max/mp_remaining from GameSession.CLASS_DEFINITIONS at
# battle start for units whose class defines any spells (Cleric today), and
# leaves every other unit at these defaults (no spells, 0 MP). Unlike
# action_points_remaining, mp_remaining is never reset by end_turn() -- MP is
# a whole-battle resource, not a per-round one, so it only ever goes down.
## Plain (not Array[String]) so callers -- production and test alike -- can
## assign an untyped array literal directly rather than fighting GDScript's
## typed-array coercion rules.
var spells: Array = []
var mp_max: int = 0
var mp_remaining: int = 0


func _init(
	p_grid_position: Vector2i,
	p_color: Color,
	p_side: int = 0,
	p_action_points: int = 6,
	p_max_health: int = 3,
	p_damage_min: int = 1,
	p_damage_max: int = 1,
	p_hit_chance: float = 1.0,
	p_attack_name: String = "Attack",
	p_adventurer_id: String = "",
	p_defense: int = 0,
	p_resistance: int = 0,
	p_kill_xp: int = 0,
	p_might: int = 0
) -> void:
	grid_position = p_grid_position
	color = p_color
	side = p_side
	max_action_points = p_action_points
	action_points_remaining = p_action_points
	max_health = p_max_health
	health = p_max_health
	damage_min = p_damage_min
	damage_max = p_damage_max
	hit_chance = p_hit_chance
	attack_name = p_attack_name
	adventurer_id = p_adventurer_id
	defense = p_defense
	resistance = p_resistance
	kill_xp = p_kill_xp
	might = p_might


## Normalizes any non-zero vector to its primary cardinal direction: whichever
## axis has the larger magnitude wins, ties resolving toward the x-axis --
## the same rule try_attack_selected_unit() uses to turn an attacker to face
## a diagonal or ranged target. A zero vector leaves facing unchanged.
func set_facing(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return
	if abs(direction.x) >= abs(direction.y):
		facing = Vector2i(sign(direction.x), 0)
	else:
		facing = Vector2i(0, sign(direction.y))


func is_alive() -> bool:
	return health > 0


func take_damage(amount: int) -> void:
	health = max(0, health - amount)
