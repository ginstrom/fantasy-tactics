extends GutTest

const GridScript := preload("res://scripts/battle/grid.gd")
const UnitScript := preload("res://scripts/battle/unit.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")


func _make_controller(width: int, height: int) -> Node2D:
	var controller: Node2D = BattleControllerScript.new()
	controller.grid = GridScript.new(width, height)
	autofree(controller)
	return controller


func test_unit_moves_to_an_unoccupied_adjacent_tile() -> void:
	var controller := _make_controller(4, 4)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE)
	controller.units = [mover]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))

	assert_true(moved, "Move to an empty adjacent tile should succeed")
	assert_eq(mover.grid_position, Vector2i(2, 1))


func test_unit_cannot_move_onto_an_occupied_adjacent_tile() -> void:
	var controller := _make_controller(4, 4)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE)
	var blocker = UnitScript.new(Vector2i(2, 1), Color.INDIAN_RED)
	controller.units = [mover, blocker]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))

	assert_false(moved, "Move onto an occupied tile should be rejected")
	assert_eq(mover.grid_position, Vector2i(1, 1), "Rejected move must not change position")


func test_unit_cannot_move_to_a_non_adjacent_tile() -> void:
	var controller := _make_controller(4, 4)
	var mover = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE)
	controller.units = [mover]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(3, 3))

	assert_false(moved, "Move to a non-adjacent tile should be rejected")
	assert_eq(mover.grid_position, Vector2i(0, 0))


func test_unit_can_move_multiple_tiles_within_its_move_range() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(4, 1))

	assert_true(moved, "Move within the unit's move range should succeed")
	assert_eq(mover.grid_position, Vector2i(4, 1))


func test_unit_cannot_move_beyond_its_move_range() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 2)
	controller.units = [mover]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(4, 1))

	assert_false(moved, "Move beyond the move range should be rejected")
	assert_eq(mover.grid_position, Vector2i(1, 1))


func test_unit_cannot_move_through_an_occupied_tile() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var blocker = UnitScript.new(Vector2i(2, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 1)
	controller.units = [mover, blocker]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(3, 1))

	assert_false(moved, "Movement cannot pass through an occupied tile")
	assert_eq(mover.grid_position, Vector2i(1, 1))


func test_unit_cannot_move_a_second_time_in_the_same_turn() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover
	controller.try_move_selected_unit(Vector2i(2, 1))
	controller.selected_unit = mover

	var moved_again: bool = controller.try_move_selected_unit(Vector2i(3, 1))

	assert_false(moved_again, "A unit that already moved this turn cannot move again")
	assert_eq(mover.grid_position, Vector2i(2, 1))


func test_move_is_rejected_for_a_unit_on_the_inactive_side() -> void:
	var controller := _make_controller(6, 6)
	var enemy = UnitScript.new(Vector2i(1, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [enemy]
	controller.selected_unit = enemy
	controller.active_side = BattleControllerScript.Side.PLAYER

	var moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))

	assert_false(moved, "A unit cannot move on the opposing side's turn")
	assert_eq(enemy.grid_position, Vector2i(1, 1))


func test_end_turn_switches_the_active_side_and_resets_movement() -> void:
	var controller := _make_controller(6, 6)
	var player_unit = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 2)
	var enemy_unit = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 2)
	controller.units = [player_unit, enemy_unit]
	controller.active_side = BattleControllerScript.Side.PLAYER
	controller.selected_unit = player_unit
	controller.try_move_selected_unit(Vector2i(2, 1))

	controller.end_turn()

	assert_eq(controller.active_side, BattleControllerScript.Side.ENEMY, "End turn hands control to the other side")
	assert_false(enemy_unit.has_moved, "The newly active side's units have not moved yet")

	controller.end_turn()

	assert_eq(controller.active_side, BattleControllerScript.Side.PLAYER, "End turn returns control to the first side")
	assert_false(player_unit.has_moved, "The player's unit regains its movement on its next turn")
