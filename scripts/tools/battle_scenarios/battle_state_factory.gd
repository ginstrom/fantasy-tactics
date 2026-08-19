class_name BattleStateFactory
extends RefCounted
## Builds battle state directly from one normalized, validated concrete
## scenario case (see scenario_contract.gd/scenario_expander.gd) -- never
## from a scene, F9, or GameSession.selected_encounter. See docs/plans/
## 2026-08-10-initial-campaign-and-automation/05-battle-scenario-contract.md
## and the governing design's "Architectural boundary" section.
##
## build() returns a bare BattleControllerScript instance -- constructed via
## `.new()` and never added to the scene tree, exactly the pattern
## test_battle_controller.gd's own _make_controller() and test_battle_bot.gd
## already use for script-only battle setup. Because it's a real
## BattleController, it comes with the full public action surface BattleBot
## and enemy turns already drive (try_move_selected_unit,
## try_attack_selected_unit, get_legal_moves, run_enemy_turn, end_turn,
## is_battle_won/is_battle_lost) for free -- this file only ever sets
## `grid`, `units`, `_player_adventurer_ids`, `active_side`, `selected_unit`,
## `hit_roll`, `crit_roll`, and `damage_roll`. `_player_adventurer_ids` (player unit ids in
## build order) is required for end_turn()'s own round-start reselection
## (BattleController._first_living_player_unit(), which end_turn() calls
## on the PLAYER side) to work correctly -- without it, end_turn() would
## silently leave selected_unit null every time control returns to the
## player, exactly the gap test_battle_controller.gd's own
## _make_controller()-based tests guard against by assigning it manually
## (see test_end_turn_selects_the_first_living_player_unit_when_a_new_round_
## starts). It never calls BattleController._ready() (which would itself
## read GameSession.selected_encounter/get_selected_party()), and it never
## touches GameConfig or GameSession's mutable campaign fields -- only
## GameSession's balance *constants* (WEAPONS, ARMORS, BASE_*, the enemy
## *_STATS consts) as the default baseline that a unit's explicit
## `modifiers` layer on top of.
##
## Board `blocked` tiles are carried in the scenario contract but not yet
## wired into pathing here: Grid's own get_tile_distances()/get_adjacent()
## only know about tile occupancy, not terrain, and extending Grid is out of
## this task's scope (see the task brief: "Do not modify battle_sim yet",
## and Grid itself is left untouched for the same reason). Blocked tiles are
## still validated for bounds/overlap by scenario_contract.gd so authoring
## one is not silently ignored -- only its runtime effect is deferred.

const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const GridScript := preload("res://scripts/battle/grid.gd")
const UnitScript := preload("res://scripts/battle/unit.gd")
const ScenarioContractScript := preload("res://scripts/tools/battle_scenarios/scenario_contract.gd")


## Constructs one battle's worth of state from `scenario` (a
## ScenarioContract.normalize()d, ScenarioContract.validate()d Dictionary --
## this function trusts that contract and does not re-validate) and
## `iteration_seed` (one entry of a case's derived iteration_seeds, see
## scenario_expander.gd). The caller owns the returned controller's
## lifetime (free it or autofree() it in tests, same as any other bare
## Node2D built via `.new()`).
static func build(scenario: Dictionary, iteration_seed: int) -> Node2D:
	var controller: Node2D = BattleControllerScript.new()

	var board: Dictionary = scenario.board
	controller.grid = GridScript.new(int(board.width), int(board.height))

	var rng := RandomNumberGenerator.new()
	rng.seed = iteration_seed
	controller.hit_roll = func() -> float: return rng.randf()
	controller.crit_roll = func() -> float: return rng.randf()
	controller.damage_roll = func(min_value: int, max_value: int) -> int: return rng.randi_range(min_value, max_value)

	var units: Array = []
	var player_adventurer_ids: Array[String] = []
	var player_units: Array = scenario.player.units
	for index in player_units.size():
		var unit_spec: Dictionary = player_units[index]
		units.append(_build_player_unit(unit_spec, index))
		player_adventurer_ids.append(String(unit_spec.id))
	var enemy_units: Array = scenario.enemy.units
	for index in enemy_units.size():
		units.append(_build_enemy_unit(enemy_units[index], index))
	controller.units = units
	controller._player_adventurer_ids = player_adventurer_ids

	controller.active_side = BattleControllerScript.Side.PLAYER
	# Reuses BattleController's own reselection method (rather than
	# reimplementing it here) now that _player_adventurer_ids is populated,
	# so round-one's initial selection and every later end_turn() round-start
	# reselection agree by construction instead of by two parallel
	# implementations staying in sync by hand.
	controller.selected_unit = controller._first_living_player_unit()

	return controller


## The only player archetype defined today mirrors GameSession.
## get_default_warrior()'s authored base stats (see
## scenario_contract.gd's KNOWN_PLAYER_TEMPLATES). Read as GameSession's
## live BASE_* fields -- not a dictionary literal frozen at parse time --
## so a scenario always builds on GameConfig's current tuning, per the
## design's "the normal game configuration remains the default baseline."
static func _read_player_template_base_stats(template_id: String) -> Dictionary:
	var class_def: Dictionary = GameSession.CLASS_DEFINITIONS.get(template_id, {})
	return class_def.get("base_stats", {})


## Resolves a named enemy template to GameSession's own *_ENEMY_STATS const
## (see scenario_contract.gd's KNOWN_ENEMY_TEMPLATES) -- the same data
## BattleController._get_enemy_stats() ultimately reads through
## GameSession.EXPEDITIONS/STAR_ENEMY_COMPOSITIONS, resolved here directly
## by name instead of through GameSession.selected_encounter.
static func _read_enemy_template_stats(template_id: String) -> Dictionary:
	match template_id:
		"goblin":
			return GameSession.GOBLIN_ENEMY_STATS
		"orc":
			return GameSession.ORC_ENEMY_STATS
		"kobold":
			return GameSession.KOBOLD_ENEMY_STATS
		"hobgoblin":
			return GameSession.HOBGOBLIN_ENEMY_STATS
		# Authored-ladder additions (see docs/plans/2026-08-18-core-loop-and-
		# engagement/05-authored-encounters-and-final-boss.md).
		"goblin_archer":
			return GameSession.GOBLIN_ARCHER_ENEMY_STATS
		"goblin_shaman":
			return GameSession.GOBLIN_SHAMAN_ENEMY_STATS
		"kobold_slinger":
			return GameSession.KOBOLD_SLINGER_ENEMY_STATS
		"orc_bruiser":
			return GameSession.ORC_BRUISER_ENEMY_STATS
		"hobgoblin_elite":
			return GameSession.HOBGOBLIN_ELITE_ENEMY_STATS
		"hobgoblin_champion":
			return GameSession.HOBGOBLIN_CHAMPION_ENEMY_STATS
		"orc_warlord":
			return GameSession.ORC_WARLORD_ENEMY_STATS
		"ogre":
			return GameSession.OGRE_ENEMY_STATS
		_:
			return {}


static func _build_player_unit(spec: Dictionary, index: int):
	var template_id: String = String(spec.get("template_id", "warrior"))
	var class_def: Dictionary = GameSession.CLASS_DEFINITIONS.get(template_id, GameSession.CLASS_DEFINITIONS.warrior)
	var base: Dictionary = class_def.get("base_stats", {})
	var skills_def: Dictionary = class_def.get("skills", {})
	var weapon: Dictionary = GameSession.WEAPONS.get(spec.weapon_id, {})
	var armor: Dictionary = GameSession.ARMORS.get(spec.armor_id, {})
	var modifiers: Dictionary = spec.get("modifiers", {})
	var level: int = int(spec.get("level", 1))

	var vitality: int = int(base.get("vitality", 10))
	var max_health: int = vitality * level + int(modifiers.get("max_health", 0))

	var melee_min_gain: int = int(skills_def.get("melee", {}).get("min_gain", 1))
	var melee: int = int(base.get("melee", 60)) + (level - 1) * melee_min_gain + int(modifiers.get("melee", modifiers.get("attack", 0)))

	var missile_min_gain: int = int(skills_def.get("missile", {}).get("min_gain", 1))
	var missile: int = int(base.get("missile", 60)) + (level - 1) * missile_min_gain + int(modifiers.get("missile", modifiers.get("attack", 0)))

	var guard_min_gain: int = int(skills_def.get("guard", {}).get("min_gain", 1))
	var guard: int = int(base.get("guard", 0)) + (level - 1) * guard_min_gain + int(modifiers.get("guard", 0))

	var might_min_gain: int = int(skills_def.get("might", {}).get("min_gain", 1))
	var might: int = int(base.get("might", 0)) + (level - 1) * might_min_gain + int(modifiers.get("might", 0))

	var category := str(weapon.get("category", ""))
	var raw_hit_stat: float = float(missile) if category == "bow" else float(melee)
	var hit_chance: float = clampf(
		raw_hit_stat / GameSession.ATTACK_TO_HIT_CHANCE_DIVISOR, 0.0, GameSession.EFFECTIVE_HIT_CHANCE_CAP
	)

	var action_points: int = BattleControllerScript.BASE_ACTION_POINTS + int(modifiers.get("action_points", 0))
	var damage_min: int = int(weapon.get("damage_min", 0)) + int(modifiers.get("damage_min", 0))
	var damage_max: int = int(weapon.get("damage_max", 0)) + int(modifiers.get("damage_max", 0))
	var defense: int = int(armor.get("defense", 0)) + guard + int(modifiers.get("defense", 0))
	var resistance: int = int(armor.get("resistance", 0)) + int(modifiers.get("resistance", 0))

	var position := ScenarioContractScript.position_from_dict(spec.position)
	var color: Color = BattleControllerScript.PLAYER_COLORS[index % BattleControllerScript.PLAYER_COLORS.size()]
	var unit := UnitScript.new(
		position, color, BattleControllerScript.Side.PLAYER,
		action_points, max_health, damage_min, damage_max, hit_chance,
		TranslationServer.translate(weapon.get("name_key", "")), String(spec.id), defense, resistance, 0, might
	)
	unit.display_name = String(spec.id)
	unit.facing = ScenarioContractScript.facing_from_string(String(spec.get("facing", "right")))
	return unit


## Enemy hit chance is authored directly on the template (see
## GameSession.*_ENEMY_STATS) rather than derived from an Attack stat --
## enemies are not migrated onto the weapon/armor/attack system (see
## unit.gd's own defense/resistance doc comment) -- so an enemy `hit_chance`
## modifier is a direct delta, unlike a player's `attack` modifier.
static func _build_enemy_unit(spec: Dictionary, index: int):
	var base := _read_enemy_template_stats(spec.template_id)
	var modifiers: Dictionary = spec.get("modifiers", {})

	var max_health: int = int(base.get("max_health", 0)) + int(modifiers.get("max_health", 0))
	# A ranged template (see GOBLIN_ARCHER_ENEMY_STATS/KOBOLD_SLINGER_ENEMY_
	# STATS/GOBLIN_SHAMAN_ENEMY_STATS/OGRE_ENEMY_STATS) authors its own
	# damage_min/damage_max range directly; a fixed-damage melee template
	# only authors "attack_damage", falling back to it for both ends of the
	# range -- the same fallback BattleController._ready() applies for a
	# live battle (see its own damage_min/damage_max reads).
	var base_damage_min: int = int(base.get("damage_min", int(base.get("attack_damage", 0))))
	var base_damage_max: int = int(base.get("damage_max", int(base.get("attack_damage", 0))))
	var damage_min: int = base_damage_min + int(modifiers.get("damage_min", 0))
	var damage_max: int = base_damage_max + int(modifiers.get("damage_max", 0))
	var hit_chance: float = clampf(float(base.get("hit_chance", 0.0)) + float(modifiers.get("hit_chance", 0.0)), 0.0, 1.0)
	# An armored/elite template (see ORC_BRUISER_ENEMY_STATS/HOBGOBLIN_ELITE_
	# ENEMY_STATS/HOBGOBLIN_CHAMPION_ENEMY_STATS/ORC_WARLORD_ENEMY_STATS/
	# OGRE_ENEMY_STATS) authors its own defense/resistance directly, same
	# additive-modifier-on-top-of-base pattern as max_health/hit_chance
	# above -- an enemy with none (every original species) keeps the prior
	# modifiers-only behavior since base.get(...) then defaults to 0.
	var defense: int = int(base.get("defense", 0)) + int(modifiers.get("defense", 0))
	var resistance: int = int(base.get("resistance", 0)) + int(modifiers.get("resistance", 0))
	var action_points: int = BattleControllerScript.BASE_ACTION_POINTS + int(modifiers.get("action_points", 0))
	var kill_xp: int = int(base.get("kill_xp", 0))

	var position := ScenarioContractScript.position_from_dict(spec.position)
	var unit := UnitScript.new(
		position, BattleControllerScript.ENEMY_COLOR, BattleControllerScript.Side.ENEMY,
		action_points, max_health, damage_min, damage_max, hit_chance,
		TranslationServer.translate(base.get("attack_name_key", "")), "", defense, resistance, kill_xp
	)
	unit.attack_min_range = int(base.get("attack_min_range", 1))
	unit.attack_max_range = int(base.get("attack_max_range", 1))
	unit.display_name = String(spec.id)
	unit.enemy_type_name = TranslationServer.translate(base.get("name_key", ""))
	unit.facing = ScenarioContractScript.facing_from_string(String(spec.get("facing", "left")))
	return unit
