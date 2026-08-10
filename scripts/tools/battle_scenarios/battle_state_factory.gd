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
## `hit_roll`, and `damage_roll`. `_player_adventurer_ids` (player unit ids in
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
	match template_id:
		"warrior":
			return {
				"max_health": GameSession.BASE_MAX_HEALTH,
				"attack": GameSession.BASE_ATTACK,
				"move_range": GameSession.BASE_MOVE_RANGE,
			}
		_:
			return {}


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
		_:
			return {}


## Level-derived state is intentionally narrow: only max_health grows with
## level (mirroring the unconditional part of GameSession.award_party_xp()'s
## own level-up effect -- see LEVEL_UP_MAX_HEALTH_BONUS). Attack growth in
## the real game comes from skill points the player explicitly spends
## (spend_attack_points()), which is a player choice, not a level-derived
## constant; a scenario expresses that instead via an explicit `attack`
## modifier, keeping "explicit test inputs, never hidden mutations" honest
## for stats as well as for GameConfig.
static func _build_player_unit(spec: Dictionary, index: int):
	var base := _read_player_template_base_stats(spec.template_id)
	var weapon: Dictionary = GameSession.WEAPONS.get(spec.weapon_id, {})
	var armor: Dictionary = GameSession.ARMORS.get(spec.armor_id, {})
	var modifiers: Dictionary = spec.get("modifiers", {})
	var level: int = int(spec.get("level", 1))

	var max_health: int = (
		int(base.get("max_health", 0))
		+ GameSession.LEVEL_UP_MAX_HEALTH_BONUS * (level - 1)
		+ int(modifiers.get("max_health", 0))
	)
	var attack: int = int(base.get("attack", 0)) + int(modifiers.get("attack", 0))
	var action_points: int = BattleControllerScript.BASE_ACTION_POINTS + int(modifiers.get("action_points", 0))
	var damage_min: int = int(weapon.get("damage_min", 0)) + int(modifiers.get("damage_min", 0))
	var damage_max: int = int(weapon.get("damage_max", 0)) + int(modifiers.get("damage_max", 0))
	var defense: int = int(armor.get("defense", 0)) + int(modifiers.get("defense", 0))
	var resistance: int = int(armor.get("resistance", 0)) + int(modifiers.get("resistance", 0))
	var hit_chance: float = clampf(
		attack / GameSession.ATTACK_TO_HIT_CHANCE_DIVISOR, 0.0, GameSession.EFFECTIVE_HIT_CHANCE_CAP
	)

	var position := ScenarioContractScript.position_from_dict(spec.position)
	var color: Color = BattleControllerScript.PLAYER_COLORS[index % BattleControllerScript.PLAYER_COLORS.size()]
	var unit := UnitScript.new(
		position, color, BattleControllerScript.Side.PLAYER,
		action_points, max_health, damage_min, damage_max, hit_chance,
		TranslationServer.translate(weapon.get("name_key", "")), String(spec.id), defense, resistance
	)
	unit.display_name = String(spec.id)
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
	var attack_damage: int = int(base.get("attack_damage", 0))
	var damage_min: int = attack_damage + int(modifiers.get("damage_min", 0))
	var damage_max: int = attack_damage + int(modifiers.get("damage_max", 0))
	var hit_chance: float = clampf(float(base.get("hit_chance", 0.0)) + float(modifiers.get("hit_chance", 0.0)), 0.0, 1.0)
	var defense: int = int(modifiers.get("defense", 0))
	var resistance: int = int(modifiers.get("resistance", 0))
	var action_points: int = BattleControllerScript.BASE_ACTION_POINTS + int(modifiers.get("action_points", 0))
	var kill_xp: int = int(base.get("kill_xp", 0))

	var position := ScenarioContractScript.position_from_dict(spec.position)
	var unit := UnitScript.new(
		position, BattleControllerScript.ENEMY_COLOR, BattleControllerScript.Side.ENEMY,
		action_points, max_health, damage_min, damage_max, hit_chance,
		TranslationServer.translate(base.get("attack_name_key", "")), "", defense, resistance, kill_xp
	)
	unit.display_name = String(spec.id)
	unit.enemy_type_name = TranslationServer.translate(base.get("name_key", ""))
	return unit
