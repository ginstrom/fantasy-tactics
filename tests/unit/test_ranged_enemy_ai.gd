extends GutTest

const GridScript := preload("res://scripts/battle/grid.gd")
const UnitScript := preload("res://scripts/battle/unit.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const BattleBot := preload("res://scripts/tools/battle_bot.gd")
const ScenarioContract := preload("res://scripts/tools/battle_scenarios/scenario_contract.gd")
const BattleStateFactory := preload("res://scripts/tools/battle_scenarios/battle_state_factory.gd")


func _make_controller(width: int = 6, height: int = 6) -> Node2D:
	var controller: Node2D = BattleControllerScript.new()
	controller.grid = GridScript.new(width, height)
	autofree(controller)
	return controller


func _archer(position: Vector2i, action_points: int = 6):
	var archer := UnitScript.new(
		position, Color.INDIAN_RED, BattleControllerScript.Side.ENEMY,
		action_points, 10, 1, 4, 0.4, "Bow"
	)
	archer.attack_min_range = 1
	archer.attack_max_range = 3
	return archer


func test_goblin_archer_template_has_its_ranged_skirmisher_stats() -> void:
	var stats: Dictionary = GameSession.GOBLIN_ARCHER_ENEMY_STATS

	assert_eq(stats.id, "goblin_archer")
	assert_eq(stats.tier, 2)
	assert_eq(stats.max_health, 10)
	assert_eq(stats.hit_chance, 0.4)
	assert_eq(stats.move_range, 3)
	assert_eq(stats.attack_min_range, 1)
	assert_eq(stats.attack_max_range, 3)
	assert_eq(stats.damage_min, 1)
	assert_eq(stats.damage_max, 4)
	assert_eq(stats.kill_xp, 6)
	assert_eq(stats.role, "ranged_skirmisher")


func test_ranged_enemy_attacks_stationary_player_at_three_tiles_without_moving() -> void:
	var controller := _make_controller()
	var archer = _archer(Vector2i(4, 1), 3)
	var player = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	controller.units = [archer, player]
	controller.active_side = BattleControllerScript.Side.ENEMY
	controller.hit_roll = func() -> float: return 0.0
	controller.crit_roll = func() -> float: return 1.0
	controller.damage_roll = func(_minimum: int, _maximum: int) -> int: return 1

	var steps: Array = controller.run_enemy_turn()

	assert_eq(steps.size(), 1)
	assert_eq(steps[0].type, "attack")
	assert_eq(archer.grid_position, Vector2i(4, 1))
	assert_eq(player.health, 9)


func test_ranged_enemy_repositions_to_a_clear_line_of_sight_before_attacking() -> void:
	var controller := _make_controller()
	var archer = _archer(Vector2i(5, 5))
	var player = UnitScript.new(Vector2i(2, 3), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	var obstacle = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 0)
	controller.units = [archer, player, obstacle]
	controller.active_side = BattleControllerScript.Side.ENEMY
	controller.hit_roll = func() -> float: return 0.0
	controller.crit_roll = func() -> float: return 1.0
	controller.damage_roll = func(_minimum: int, _maximum: int) -> int: return 1

	var steps: Array = controller.run_enemy_turn()

	assert_eq(steps.size(), 2)
	assert_eq(steps[0].type, "move")
	assert_eq(archer.grid_position, Vector2i(5, 3))
	assert_eq(steps[1].type, "attack")
	assert_eq(player.health, 9)


func test_battle_bot_finishes_a_turn_against_a_ranged_enemy_without_looping() -> void:
	var controller := _make_controller()
	var player = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	var archer = _archer(Vector2i(5, 5))
	controller.units = [player, archer]
	controller.hit_roll = func() -> float: return 0.0

	var steps: Array = BattleBot.take_player_turn(controller)

	assert_gt(steps.size(), 0)
	assert_lte(steps.size(), player.max_action_points + 1)
	assert_lte(player.action_points_remaining, player.max_action_points)


## --- Step 6 of docs/plans/2026-08-21-stage-2-party-readiness/
## 06-authored-readiness-patterns.md: "ranged pressure" (docs/designs/
## campaign-loop.md's tier-2 lesson) must be bidirectional, not only the
## Scout's own ranged attack (already proven by test_stage_2_scout_tier_
## two.gd). The two tests above already prove the generic ranged-enemy AI
## (_take_enemy_unit_actions()'s attack-in-range/reposition-for-LoS loop)
## against a hand-built UnitScript archer; these two instead build the exact
## obj_tier2_1_orc_outpost composition (one Orc Bruiser, one Goblin Archer --
## see GameSession.EXPEDITIONS' own entry) through the real ScenarioContract/
## BattleStateFactory pipeline, proving that same generic AI drives a
## factory-hydrated Goblin Archer (real move/GOBLIN_ARCHER_ENEMY_STATS-
## derived range, not a hand-picked stand-in) identically. The Orc Bruiser is
## always the enemy list's first entry so it resolves its own action before
## the Archer -- letting it double as a stationary line-of-sight blocker in
## the second test without a separate zero-AP obstacle unit.
func _tier_two_composition_scenario(archer_action_points_modifier: int, bruiser_position: Dictionary, archer_position: Dictionary, player_position: Dictionary) -> Dictionary:
	return ScenarioContract.normalize({
		"scenario_id": "tier_two_ranged_pressure_is_bidirectional",
		"board": {"width": 6, "height": 6},
		"player": {"units": [{"id": "warrior_1", "template_id": "warrior", "position": player_position}]},
		"enemy": {
			"units": [
				{"id": "orc_bruiser_1", "template_id": "orc_bruiser", "position": bruiser_position},
				{
					"id": "goblin_archer_1", "template_id": "goblin_archer", "position": archer_position,
					"modifiers": {"action_points": archer_action_points_modifier},
				},
			],
		},
	})


func _step_actor(step: Dictionary):
	return step.get("unit", step.get("attacker"))


func test_authored_tier_two_compositions_goblin_archer_attacks_a_stationary_warrior_at_three_tiles_without_moving() -> void:
	# Mirrors test_ranged_enemy_attacks_stationary_player_at_three_tiles_
	# without_moving()'s own geometry (distance 3, same row, clear LoS) --
	# the Archer's own action_points is reduced to 3 (one basic attack's
	# worth) via a scenario modifier so it takes exactly one attack step
	# here too, rather than the full 6 AP letting it attack the still-living
	# Warrior twice. The Orc Bruiser sits far away, out of this single enemy
	# turn's reach, so it never interferes with the Archer's own steps.
	var scenario := _tier_two_composition_scenario(
		-3, {"x": 0, "y": 5}, {"x": 4, "y": 1}, {"x": 1, "y": 1}
	)
	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)
	var archer = controller.get_unit_at(Vector2i(4, 1))
	var warrior = controller.get_unit_at(Vector2i(1, 1))
	controller.active_side = BattleControllerScript.Side.ENEMY
	controller.hit_roll = func() -> float: return 0.0
	controller.crit_roll = func() -> float: return 1.0
	controller.damage_roll = func(_minimum: int, _maximum: int) -> int: return 1

	var steps: Array = controller.run_enemy_turn()
	var archer_steps: Array = steps.filter(func(step): return _step_actor(step) == archer)

	assert_eq(archer_steps.size(), 1)
	assert_eq(archer_steps[0].type, "attack")
	assert_eq(archer.grid_position, Vector2i(4, 1), "The Archer must never move when it already has a clear shot")
	assert_eq(warrior.health, warrior.max_health - 1)


func test_authored_tier_two_compositions_goblin_archer_repositions_around_its_own_bruiser_for_a_clear_line_of_sight() -> void:
	# Mirrors test_ranged_enemy_repositions_to_a_clear_line_of_sight_before_
	# attacking()'s own geometry exactly, but the blocking unit is the
	# composition's own Orc Bruiser (standing at its authored-adjacent
	# formation position) rather than a bespoke zero-AP obstacle -- proving
	# even a real formation's own ally can force this repositioning, not
	# only a hand-placed test fixture.
	var scenario := _tier_two_composition_scenario(
		0, {"x": 4, "y": 4}, {"x": 5, "y": 5}, {"x": 2, "y": 3}
	)
	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)
	var archer = controller.get_unit_at(Vector2i(5, 5))
	var warrior = controller.get_unit_at(Vector2i(2, 3))
	controller.active_side = BattleControllerScript.Side.ENEMY
	controller.hit_roll = func() -> float: return 0.0
	controller.crit_roll = func() -> float: return 1.0
	controller.damage_roll = func(_minimum: int, _maximum: int) -> int: return 1

	var steps: Array = controller.run_enemy_turn()
	var archer_steps: Array = steps.filter(func(step): return _step_actor(step) == archer)

	assert_eq(archer_steps.size(), 2)
	assert_eq(archer_steps[0].type, "move")
	assert_eq(archer.grid_position, Vector2i(5, 3), "The Archer must reposition around its own Bruiser's blocking line of sight")
	assert_eq(archer_steps[1].type, "attack")
	assert_eq(warrior.health, warrior.max_health - 1)
