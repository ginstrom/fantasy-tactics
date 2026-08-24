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
# Explicit shared tactical profile (docs/designs/class-system.md's "Shared
# tactical attributes" section; see also docs/plans/2026-08-21-stage-2-
# party-readiness/05-shared-tactical-profile-migration.md). melee/missile are
# the same raw accuracy stat `hit_chance` above is already derived from
# (whichever the attacker's weapon category/range picks -- see GameSession.
# get_effective_hit_chance()/get_enemy_profile_hit_chance()) -- this holds for
# EVERY unit, including a still-legacy monster template (one authored with a
# flat `hit_chance` instead of explicit melee/missile): GameSession.
# get_enemy_profile_melee()/get_enemy_profile_missile() derive an equivalent
# value from that same `hit_chance` for exactly this reason, the same
# convention a player Unit already uses (a Warrior's `missile` is populated
# to its raw missile skill even though it's equipped with a sword). `guard`
# is the same percentage-point subtraction `defense` above already applies in
# BattleController.try_attack_selected_unit(). All three pairs are
# intentionally kept in sync by construction (BattleController/
# BattleStateFactory set both fields of each pair from the same source
# value/adapter call) rather than merged into one field yet -- see this
# step's own design note about removing the duplication only once parity
# tests exist. spellcasting/magic_resistance are 0 for every unit with no
# spellcasting source yet (every monster, and every adventurer class except
# Cleric's spellcasting -- see GameSession.get_effective_spellcasting()).
var melee: int = 0
var missile: int = 0
var guard: int = 0
var spellcasting: int = 0
var magic_resistance: int = 0
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
# Placeholder sprites (docs/plans/2026-08-20-placeholder-sprites/
# 02-battlefield-sprites.md): the SpriteCatalog lookup key BattleController
# hydrates in _ready() -- "player_<class-id>" for a player unit,
# "enemy_<family>" for an enemy unit -- and _draw_units() reads to pick the
# unit's Sprite2D texture. Presentation-only, exactly like `color` above it:
# never derive action legality, saved state, simulation output, or RNG from
# it, and never serialize it.
var visual_key := ""
# Stage 5 D2 tactical primitives (docs/plans/2026-08-23-stage-5-strategic-
# roster-expansion/decision-ledger.md's "Approved values" table): off-balance
# is a defensive Guard penalty this unit suffers for the whole of its own
# NEXT turn, incurred by whiffing an attack against a Dodge or Parry (see
# BattleController.try_attack_selected_unit()/_resolve_opportunity_attack()).
# *_pending is set the instant the evasion happens; BattleController.end_turn()'s
# _advance_reaction_timers() promotes *_pending to *_active exactly once, at
# the start of THIS unit's own next turn, and clears *_active at the start of
# the turn after that -- giving exactly one full "their next round" window,
# never longer. Never read directly for display -- BattleController is the
# only reader (see its effective_defense computation).
var off_balance_pending: bool = false
var off_balance_active: bool = false
# Parry's counter-bonus (+10% melee to-hit) applies only against the SAME
# attacker who was parried, only during the parrying unit's own next turn --
# same pending/active timing as off_balance above, but tracks which attacker
# it applies against (null means "no counter-bonus") rather than a bare bool.
var counter_bonus_pending_against = null
var counter_bonus_active_against = null
# Stage 5 D4 (Knight specialization): the exact perk ids this unit's owning
# adventurer has chosen (root CLASS_PERKS entries plus, once promoted, its
# specialization's own SPECIALIZATION_PERKS entries) -- BattleController
# reads this to gate Shield Bash/Chain Blow (see try_shield_bash_selected_
# unit()/_resolve_chain_blow_strike()) the same way unit.spells already
# gates spell casting. Empty for every unit with no perks (every enemy, and
# any player unit built before this list is hydrated -- see BattleController.
## _ready() and BattleStateFactory._build_player_unit()).
var perks: Array = []
# Paladin specialization (Stage 5 D4): the owning adventurer's own promoted
# specialization id (e.g. "paladin"), or "" for every unrecognized/unpromoted
# unit -- mirrors perks' own hydration exactly (BattleController._ready()/
# BattleStateFactory._build_player_unit() both set this from GameSession.get_
# adventurer_specialization()/a scenario's own "specialization" field). Unlike
# perks, Paladin's own ability is keyed purely to CASTER IDENTITY, not to a
# chosen perk id (Paladin has no SPECIALIZATION_PERKS entry at all) -- see
# BattleController.try_cast_spell()'s "bless" match arm, which reads this
# field directly to decide between BLESSED_STATUS_ID and PALADIN_BLESSED_
# STATUS_ID.
var specialization: String = ""
# Once-per-round bookkeeping for the Chain Blow perk (Stage 5 D4): true once
# this unit's Chain Blow has already triggered a bonus second strike this
# Round, so a second landed melee attack the same Round cannot trigger it
# again. Cleared alongside PARALYZED_STATUS_ID/SLEEPING_STATUS_ID at the same
# round boundary -- see BattleController._clear_expired_statuses().
var chain_blow_used_this_round: bool = false
# Archer's Lock On perk (Stage 5 D4): which enemy this unit last attacked
# (any direct attack, hit or miss -- see BattleController._execute_direct_
# attack()), and on which Round number that attack happened (Battle
# Controller.current_round at the time). Compared against the CURRENT round
# number in _compute_effective_attack_chances(): a match on both the target
# AND "current_round - 1" means this unit also attacked the same target on
# the immediately preceding Round, granting Lock On's +10% to-hit. Tracked
# for every attacker unconditionally (cheap, and mirrors chain_blow_used_
# this_round/off_balance_pending's own "track universally, gate at the
# formula" convention) -- only a unit that actually owns archer_lock_on ever
# sees it change the to-hit formula. null/-1 defaults mean "no attack yet",
# never a real Round number or a valid target.
var last_attacked_target = null
var last_attacked_round: int = -1


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
