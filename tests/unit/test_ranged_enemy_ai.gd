extends GutTest

const GridScript := preload("res://scripts/battle/grid.gd")
const UnitScript := preload("res://scripts/battle/unit.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const BattleBot := preload("res://scripts/tools/battle_bot.gd")


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
