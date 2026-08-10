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
	p_kill_xp: int = 0
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


func is_alive() -> bool:
	return health > 0


func take_damage(amount: int) -> void:
	health = max(0, health - amount)
