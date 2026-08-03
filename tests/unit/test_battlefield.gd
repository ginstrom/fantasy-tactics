extends GutTest

const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")


func after_each() -> void:
	GameManager.close_game_menu()


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	battlefield._unhandled_input(escape_event)

	assert_true(
		battlefield.get_viewport().is_input_handled(),
		"Battlefield must mark Escape input as handled so it doesn't also reach the viewport below"
	)
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
