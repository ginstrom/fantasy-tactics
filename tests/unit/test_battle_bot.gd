extends GutTest

const GridScript := preload("res://scripts/battle/grid.gd")
const UnitScript := preload("res://scripts/battle/unit.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const BattleBot := preload("res://scripts/tools/battle_bot.gd")


func _make_controller(width: int, height: int) -> Node2D:
	var controller: Node2D = BattleControllerScript.new()
	controller.grid = GridScript.new(width, height)
	autofree(controller)
	return controller


func test_moves_toward_the_nearest_enemy_when_out_of_attack_range() -> void:
	var controller := _make_controller(6, 6)
	var player := UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy := UnitScript.new(Vector2i(5, 5), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [player, enemy]

	var steps: Array = BattleBot.take_player_turn(controller)

	assert_ne(player.grid_position, Vector2i(0, 0), "Bot should move the unit toward the enemy")
	assert_false(player.has_acted, "Out of range: no attack should have been made")
	assert_eq(steps.size(), 1)
	assert_eq(steps[0].type, "move")


func test_attacks_an_adjacent_enemy_instead_of_moving() -> void:
	var controller := _make_controller(6, 6)
	var player := UnitScript.new(Vector2i(2, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy := UnitScript.new(Vector2i(3, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [player, enemy]
	controller.hit_roll = func() -> float: return 0.0

	var steps: Array = BattleBot.take_player_turn(controller)

	assert_eq(player.grid_position, Vector2i(2, 2), "Already adjacent: unit should not move")
	assert_true(player.has_acted, "Adjacent enemy should be attacked")
	assert_eq(steps.size(), 1)
	assert_eq(steps[0].type, "attack")
	assert_eq(steps[0].defender, enemy)


func test_moves_then_attacks_in_the_same_turn_once_in_range() -> void:
	var controller := _make_controller(6, 6)
	var player := UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy := UnitScript.new(Vector2i(2, 0), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [player, enemy]
	controller.hit_roll = func() -> float: return 0.0

	var steps: Array = BattleBot.take_player_turn(controller)

	assert_eq(player.grid_position, Vector2i(1, 0), "Should move exactly one tile adjacent, not overshoot")
	assert_true(player.has_acted)
	assert_eq(steps.size(), 2)
	assert_eq(steps[0].type, "move")
	assert_eq(steps[1].type, "attack")


func test_ignores_units_that_are_already_defeated() -> void:
	var controller := _make_controller(6, 6)
	var dead_player := UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	dead_player.health = 0
	var enemy := UnitScript.new(Vector2i(1, 0), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [dead_player, enemy]

	var steps: Array = BattleBot.take_player_turn(controller)

	assert_eq(steps.size(), 0)
	assert_eq(dead_player.grid_position, Vector2i(0, 0))
