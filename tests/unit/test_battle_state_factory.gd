extends GutTest
## Covers scripts/tools/battle_scenarios/battle_state_factory.gd: builds a
## bare, un-scened BattleController (grid, units, positions, sides, and
## seeded RNG callables) from one normalized, validated concrete scenario
## case -- the same "construct via script, never via the scene" pattern
## test_battle_controller.gd's _make_controller() and test_battle_bot.gd
## already use. See docs/plans/2026-08-10-initial-campaign-and-automation/
## 05-battle-scenario-contract.md.

const BattleStateFactory := preload("res://scripts/tools/battle_scenarios/battle_state_factory.gd")
const ScenarioContract := preload("res://scripts/tools/battle_scenarios/scenario_contract.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const BattleBot := preload("res://scripts/tools/battle_bot.gd")


func before_each() -> void:
	GameSession.reset()


func _normalized(raw: Dictionary) -> Dictionary:
	return ScenarioContract.normalize(raw)


func _one_v_one_scenario() -> Dictionary:
	return _normalized({
		"scenario_id": "one_v_one",
		"player": {"units": [{"id": "hero", "template_id": "warrior", "position": {"x": 0, "y": 0}}]},
		"enemy": {"units": [{"id": "grunt", "template_id": "goblin", "position": {"x": 5, "y": 5}}]},
	})


## --- Grid, units, positions, sides -------------------------------------------

func test_build_creates_a_grid_sized_to_the_scenarios_board() -> void:
	var scenario := _normalized({
		"scenario_id": "sized_board",
		"board": {"width": 4, "height": 8},
		"player": {"template_id": "warrior", "count": 1},
		"enemy": {"template_id": "goblin", "count": 1},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)

	assert_eq(controller.grid.width, 4)
	assert_eq(controller.grid.height, 8)


func test_build_fields_one_unit_per_declared_side_unit_at_its_declared_position() -> void:
	var controller: Node2D = BattleStateFactory.build(_one_v_one_scenario(), 1)
	autofree(controller)

	assert_eq(controller.units.size(), 2)
	var hero = controller.get_unit_at(Vector2i(0, 0))
	var grunt = controller.get_unit_at(Vector2i(5, 5))
	assert_not_null(hero)
	assert_not_null(grunt)
	assert_eq(hero.side, BattleControllerScript.Side.PLAYER)
	assert_eq(grunt.side, BattleControllerScript.Side.ENEMY)


func test_build_selects_the_first_living_player_unit_and_starts_on_the_player_side() -> void:
	var controller: Node2D = BattleStateFactory.build(_one_v_one_scenario(), 1)
	autofree(controller)

	assert_eq(controller.active_side, BattleControllerScript.Side.PLAYER)
	assert_not_null(controller.selected_unit)
	assert_eq(controller.selected_unit.side, BattleControllerScript.Side.PLAYER)


## --- end_turn() round-start reselection ---------------------------------------
## BattleController.end_turn() re-selects the first living player unit via
## its own _first_living_player_unit(), which walks _player_adventurer_ids
## rather than `units` directly (see battle_controller.gd). A factory-built
## controller must populate that field, or every end_turn() back to the
## player side would silently leave selected_unit null -- exactly the gap
## test_battle_controller.gd's own _make_controller()-based tests guard
## against by assigning _player_adventurer_ids by hand (see
## test_end_turn_selects_the_first_living_player_unit_when_a_new_round_starts
## there).

func _two_player_scenario() -> Dictionary:
	return _normalized({
		"scenario_id": "two_player",
		"player": {
			"units": [
				{"id": "hero_1", "template_id": "warrior", "position": {"x": 0, "y": 0}},
				{"id": "hero_2", "template_id": "warrior", "position": {"x": 1, "y": 0}},
			],
		},
		"enemy": {"units": [{"id": "grunt", "template_id": "goblin", "position": {"x": 5, "y": 5}}]},
	})


func test_end_turn_reselects_the_first_living_player_unit_when_control_returns_to_the_player() -> void:
	var controller: Node2D = BattleStateFactory.build(_two_player_scenario(), 1)
	autofree(controller)
	# Simulate the round-start selection having moved on, the way a real
	# turn would leave it once the second unit has acted.
	controller.selected_unit = controller.get_unit_at(Vector2i(1, 0))

	controller.end_turn()  # PLAYER -> ENEMY
	assert_null(controller.selected_unit, "Handing control to the enemy does not select one of its units")

	controller.end_turn()  # ENEMY -> PLAYER

	assert_eq(controller.active_side, BattleControllerScript.Side.PLAYER)
	assert_not_null(
		controller.selected_unit,
		"A factory-built controller must reselect a player unit at round start, not silently leave it null",
	)
	assert_eq(controller.selected_unit, controller.get_unit_at(Vector2i(0, 0)), "hero_1 was declared first")


func test_end_turn_skips_a_defeated_party_member_when_reselecting_at_round_start() -> void:
	var controller: Node2D = BattleStateFactory.build(_two_player_scenario(), 1)
	autofree(controller)
	controller.get_unit_at(Vector2i(0, 0)).health = 0

	controller.end_turn()  # PLAYER -> ENEMY
	controller.end_turn()  # ENEMY -> PLAYER

	assert_eq(
		controller.selected_unit,
		controller.get_unit_at(Vector2i(1, 0)),
		"A defeated party member cannot be the round-start selection",
	)


## --- Stats read from GameSession's read-only balance constants ---------------

func test_build_derives_the_player_units_stats_from_gamesessions_baseline_and_default_gear() -> void:
	var controller: Node2D = BattleStateFactory.build(_one_v_one_scenario(), 1)
	autofree(controller)

	var hero = controller.get_unit_at(Vector2i(0, 0))
	var weapon: Dictionary = GameSession.WEAPONS[GameSession.DEFAULT_WEAPON_ID]
	var armor: Dictionary = GameSession.ARMORS[GameSession.DEFAULT_ARMOR_ID]

	assert_eq(hero.max_health, GameSession.BASE_MAX_HEALTH)
	assert_eq(hero.move_range, GameSession.BASE_MOVE_RANGE)
	assert_eq(hero.damage_min, weapon.damage_min)
	assert_eq(hero.damage_max, weapon.damage_max)
	assert_eq(hero.defense, armor.defense)
	assert_eq(hero.resistance, armor.resistance)
	assert_eq(
		hero.hit_chance,
		minf(GameSession.BASE_ATTACK / GameSession.ATTACK_TO_HIT_CHANCE_DIVISOR, GameSession.EFFECTIVE_HIT_CHANCE_CAP),
	)


func test_build_derives_the_enemy_units_stats_from_gamesessions_named_template() -> void:
	var controller: Node2D = BattleStateFactory.build(_one_v_one_scenario(), 1)
	autofree(controller)

	var grunt = controller.get_unit_at(Vector2i(5, 5))

	assert_eq(grunt.max_health, GameSession.GOBLIN_ENEMY_STATS.max_health)
	assert_eq(grunt.damage_min, GameSession.GOBLIN_ENEMY_STATS.attack_damage)
	assert_eq(grunt.damage_max, GameSession.GOBLIN_ENEMY_STATS.attack_damage)
	assert_eq(grunt.hit_chance, GameSession.GOBLIN_ENEMY_STATS.hit_chance)
	assert_eq(grunt.kill_xp, GameSession.GOBLIN_ENEMY_STATS.kill_xp)


func test_build_applies_a_higher_level_players_max_health_bonus() -> void:
	var scenario := _normalized({
		"scenario_id": "leveled",
		"player": {"units": [{"id": "hero", "template_id": "warrior", "level": 3, "position": {"x": 0, "y": 0}}]},
		"enemy": {"template_id": "goblin", "count": 1},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)

	var hero = controller.get_unit_at(Vector2i(0, 0))
	assert_eq(hero.max_health, GameSession.BASE_MAX_HEALTH + GameSession.LEVEL_UP_MAX_HEALTH_BONUS * 2)


## --- Explicit modifiers affect only the constructed unit ---------------------

func test_build_applies_explicit_player_modifiers_on_top_of_the_baseline() -> void:
	var scenario := _normalized({
		"scenario_id": "modified",
		"player": {
			"units": [
				{
					"id": "hero", "template_id": "warrior", "position": {"x": 0, "y": 0},
					"modifiers": {"max_health": 5, "damage_min": 2, "damage_max": 3, "defense": 4, "resistance": 6},
				},
			],
		},
		"enemy": {"template_id": "goblin", "count": 1},
	})
	var weapon: Dictionary = GameSession.WEAPONS[GameSession.DEFAULT_WEAPON_ID]
	var armor: Dictionary = GameSession.ARMORS[GameSession.DEFAULT_ARMOR_ID]

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)
	var hero = controller.get_unit_at(Vector2i(0, 0))

	assert_eq(hero.max_health, GameSession.BASE_MAX_HEALTH + 5)
	assert_eq(hero.damage_min, weapon.damage_min + 2)
	assert_eq(hero.damage_max, weapon.damage_max + 3)
	assert_eq(hero.defense, armor.defense + 4)
	assert_eq(hero.resistance, armor.resistance + 6)


func test_build_applies_explicit_enemy_modifiers_on_top_of_the_baseline() -> void:
	var scenario := _normalized({
		"scenario_id": "modified_enemy",
		"player": {"template_id": "warrior", "count": 1},
		"enemy": {
			"units": [
				{
					"id": "grunt", "template_id": "goblin", "position": {"x": 5, "y": 5},
					"modifiers": {"max_health": 10, "damage_min": 1, "damage_max": 1},
				},
			],
		},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)
	var grunt = controller.get_unit_at(Vector2i(5, 5))

	assert_eq(grunt.max_health, GameSession.GOBLIN_ENEMY_STATS.max_health + 10)
	assert_eq(grunt.damage_min, GameSession.GOBLIN_ENEMY_STATS.attack_damage + 1)
	assert_eq(grunt.damage_max, GameSession.GOBLIN_ENEMY_STATS.attack_damage + 1)


func test_build_never_mutates_gamesession_or_gameconfig_state() -> void:
	var scenario := _normalized({
		"scenario_id": "no_side_effects",
		"player": {
			"units": [
				{
					"id": "hero", "template_id": "warrior", "position": {"x": 0, "y": 0},
					"modifiers": {"max_health": 999, "damage_min": 999},
				},
			],
		},
		"enemy": {"template_id": "goblin", "count": 1},
	})
	var adventurers_before: Array = GameSession.adventurers.duplicate(true)
	var base_max_health_before: int = GameSession.BASE_MAX_HEALTH
	var weapons_before: Dictionary = GameSession.WEAPONS.duplicate(true)

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)

	assert_eq(GameSession.adventurers, adventurers_before)
	assert_eq(GameSession.BASE_MAX_HEALTH, base_max_health_before)
	assert_eq(GameSession.WEAPONS, weapons_before)
	assert_eq(GameSession.selected_encounter, "")
	assert_false(controller.is_inside_tree(), "BattleStateFactory must never add the controller to the scene tree")


## --- Injected, seeded RNG callables -------------------------------------------

func test_build_seeds_hit_roll_and_damage_roll_deterministically_from_the_iteration_seed() -> void:
	var scenario := _one_v_one_scenario()

	var controller_a: Node2D = BattleStateFactory.build(scenario, 12345)
	var controller_b: Node2D = BattleStateFactory.build(scenario, 12345)
	autofree(controller_a)
	autofree(controller_b)

	for _i in 5:
		assert_eq(controller_a.hit_roll.call(), controller_b.hit_roll.call())
	for _i in 5:
		assert_eq(controller_a.damage_roll.call(1, 100), controller_b.damage_roll.call(1, 100))


func test_build_seeds_hit_roll_differently_for_different_iteration_seeds() -> void:
	var scenario := _one_v_one_scenario()

	var controller_a: Node2D = BattleStateFactory.build(scenario, 1)
	var controller_b: Node2D = BattleStateFactory.build(scenario, 2)
	autofree(controller_a)
	autofree(controller_b)

	var rolls_a: Array = []
	var rolls_b: Array = []
	for _i in 10:
		rolls_a.append(controller_a.hit_roll.call())
		rolls_b.append(controller_b.hit_roll.call())
	assert_ne(rolls_a, rolls_b, "Different iteration seeds should (overwhelmingly likely) diverge over 10 rolls")


## --- Exposes the public action surface used by BattleBot/enemy turns --------

func test_battle_bot_can_drive_a_factory_built_controllers_player_turn() -> void:
	var controller: Node2D = BattleStateFactory.build(_one_v_one_scenario(), 1)
	autofree(controller)

	var steps: Array = BattleBot.take_player_turn(controller)

	assert_eq(steps.size(), 1)
	assert_eq(steps[0].type, "move", "The hero starts 10 tiles from the goblin, so its only legal action is to move closer")


func test_run_enemy_turn_drives_a_factory_built_controllers_enemy_side() -> void:
	var controller: Node2D = BattleStateFactory.build(_one_v_one_scenario(), 1)
	autofree(controller)
	controller.active_side = BattleControllerScript.Side.ENEMY

	var steps: Array = controller.run_enemy_turn()

	assert_eq(steps.size(), 1)
	assert_eq(steps[0].type, "move")


func test_try_move_and_try_attack_work_directly_on_a_factory_built_controller() -> void:
	var scenario := _normalized({
		"scenario_id": "adjacent",
		"player": {"units": [{"id": "hero", "template_id": "warrior", "position": {"x": 1, "y": 1}}]},
		"enemy": {"units": [{"id": "grunt", "template_id": "goblin", "position": {"x": 1, "y": 2}}]},
	})
	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)
	var hero = controller.get_unit_at(Vector2i(1, 1))
	controller.selected_unit = hero
	controller.hit_roll = func() -> float: return 0.0

	var attacked: bool = controller.try_attack_selected_unit(Vector2i(1, 2))

	assert_true(attacked)
