extends GutTest


func test_escape_marks_input_handled_before_changing_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/battle/battlefield.gd")
	var handle_input_at := source.find("get_viewport().set_input_as_handled()")
	var change_scene_at := source.find("GameManager.go_to_start_menu()")

	assert_ne(handle_input_at, -1, "Battlefield must mark Escape input as handled")
	assert_ne(change_scene_at, -1, "Battlefield must return to the start menu on Escape")
	assert_lt(
		handle_input_at,
		change_scene_at,
		"Battlefield must handle Escape before changing scenes, which detaches its viewport"
	)
