extends RefCounted

var grid_position: Vector2i
var color: Color
var side: int
var move_range: int
var moves_remaining: int
var has_acted: bool = false
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
# XP awarded to the party when this unit is the one defeated (see
# GameSession.*_ENEMY_STATS.kill_xp). 0 and unused for player-side units.
var kill_xp: int = 0


func _init(
	p_grid_position: Vector2i,
	p_color: Color,
	p_side: int = 0,
	p_move_range: int = 1,
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
	move_range = p_move_range
	moves_remaining = p_move_range
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
