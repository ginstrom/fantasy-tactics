extends GutTest


func test_escape_marks_input_handled_before_changing_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/game/game.gd")
	var handle_input_at := source.find("get_viewport().set_input_as_handled()")
	var change_scene_at := source.find("GameManager.go_to_main_menu()")

	assert_ne(handle_input_at, -1, "Game must mark Escape input as handled")
	assert_ne(change_scene_at, -1, "Game must return to the main menu on Escape")
	assert_lt(
		handle_input_at,
		change_scene_at,
		"Game must handle Escape before changing scenes, which detaches its viewport"
	)
