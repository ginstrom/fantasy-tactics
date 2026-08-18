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
	var player := UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var enemy := UnitScript.new(Vector2i(5, 5), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [player, enemy]

	var steps: Array = BattleBot.take_player_turn(controller)

	assert_ne(player.grid_position, Vector2i(0, 0), "Bot should move the unit toward the enemy")
	assert_eq(player.action_points_remaining, 0, "The bot spends its AP moving toward the target")
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
	assert_eq(player.action_points_remaining, 0, "Adjacent attacks spend the full AP budget")
	assert_eq(steps.size(), 1)
	assert_eq(steps[0].type, "attack")
	assert_eq(steps[0].defender, enemy)


func test_moves_then_attacks_in_the_same_turn_once_in_range() -> void:
	var controller := _make_controller(6, 6)
	var player := UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var enemy := UnitScript.new(Vector2i(2, 0), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [player, enemy]
	controller.hit_roll = func() -> float: return 0.0

	var steps: Array = BattleBot.take_player_turn(controller)

	assert_eq(player.grid_position, Vector2i(1, 0), "Should move exactly one tile adjacent, not overshoot")
	assert_eq(player.action_points_remaining, 2)
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


## BattleController._nearest_living_unit() breaks distance ties with reading
## order (top-to-bottom, left-to-right), not with units-array order. The bot
## mirrors that policy, so the enemy listed second here still wins the tie.
func test_equidistant_enemies_are_tie_broken_by_reading_order() -> void:
	var controller := _make_controller(6, 6)
	var player := UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var later_in_reading_order := UnitScript.new(Vector2i(0, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	var earlier_in_reading_order := UnitScript.new(Vector2i(1, 0), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [player, later_in_reading_order, earlier_in_reading_order]
	controller.hit_roll = func() -> float: return 0.0

	var steps: Array = BattleBot.take_player_turn(controller)

	assert_eq(steps.size(), 1)
	assert_eq(steps[0].type, "attack")
	assert_eq(
		steps[0].defender,
		earlier_in_reading_order,
		"A distance tie must resolve to the enemy earliest in reading order, not the first one in units"
	)


## BattleController.get_legal_attack_targets() now allows a range-one weapon
## to strike any of the eight neighboring tiles (see Grid.is_attack_adjacent()
## and battle_controller.gd's diagonal-melee slice). The bot must drive that
## same public rule (controller.get_legal_attack_targets(unit).has(target)),
## not its own four-directional controller.grid.get_adjacent() check, so a
## diagonally-adjacent enemy is attacked in place rather than stepped toward.
func test_attacks_a_diagonally_adjacent_enemy_instead_of_moving() -> void:
	var controller := _make_controller(6, 6)
	var player := UnitScript.new(Vector2i(2, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy := UnitScript.new(Vector2i(3, 3), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [player, enemy]
	controller.hit_roll = func() -> float: return 0.0

	var steps: Array = BattleBot.take_player_turn(controller)

	assert_eq(player.grid_position, Vector2i(2, 2), "Already diagonally adjacent: unit should not move")
	assert_eq(player.action_points_remaining, 0, "Adjacent attacks spend the full AP budget")
	assert_eq(steps.size(), 1)
	assert_eq(steps[0].type, "attack")
	assert_eq(steps[0].defender, enemy)


## Mirrors test_moves_then_attacks_in_the_same_turn_once_in_range: the bot
## moves the unit adjacent, then attacks -- and both the move step and the
## attack step must update the acting unit's facing (see Unit.facing /
## BattleController.try_move_selected_unit()/try_attack_selected_unit()),
## since the bot drives those same public methods.
func test_take_player_turn_updates_facing_on_move_and_on_attack() -> void:
	var controller := _make_controller(6, 6)
	var player := UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var enemy := UnitScript.new(Vector2i(2, 0), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [player, enemy]
	controller.hit_roll = func() -> float: return 0.0

	BattleBot.take_player_turn(controller)

	assert_eq(player.grid_position, Vector2i(1, 0))
	assert_eq(player.facing, Vector2i.RIGHT, "Attacking a target directly to the east must face the attacker east")


## BattleController._best_move_toward() seeds has_candidate := false, so the
## first legal move is accepted unconditionally and the unit always relocates
## when any legal move exists — even one that does not close the gap. The bot
## mirrors that rather than the more "sensible" stay-put behaviour.
func test_best_move_relocates_even_when_no_legal_move_gets_closer() -> void:
	var controller := _make_controller(4, 4)
	var player := UnitScript.new(Vector2i(2, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 1)
	# Both tiles that would close the gap toward (0, 0) are occupied, leaving
	# only (3, 2) and (2, 3) — each one step further away than standing still.
	var blocker_north := UnitScript.new(Vector2i(2, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 1)
	var blocker_west := UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 1)
	controller.units = [player, blocker_north, blocker_west]

	var destination: Vector2i = BattleBot._best_move_toward(controller, player, Vector2i(0, 0))

	assert_ne(destination, player.grid_position, "The enemy AI always relocates when a legal move exists")
	assert_eq(
		destination,
		Vector2i(3, 2),
		"Among equally-distant non-improving moves, reading order picks (3, 2) over (2, 3)"
	)
