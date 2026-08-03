extends GutTest


func test_escape_marks_input_handled_before_opening_the_game_menu() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/battle/battlefield.gd")
	var handle_input_at := source.find("get_viewport().set_input_as_handled()")
	var open_menu_at := source.find("GameManager.open_game_menu()")

	assert_ne(handle_input_at, -1, "Battlefield must mark Escape input as handled")
	assert_ne(open_menu_at, -1, "Battlefield must open the game menu on Escape")
	assert_lt(
		handle_input_at,
		open_menu_at,
		"Battlefield must handle Escape before opening the overlay"
	)
