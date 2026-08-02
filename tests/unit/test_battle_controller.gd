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
