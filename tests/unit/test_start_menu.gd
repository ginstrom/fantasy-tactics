extends GutTest

const StartMenuScene := preload("res://scenes/ui/start_menu.tscn")


func test_continue_and_load_are_disabled_without_a_saved_game() -> void:
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)

	assert_true(screen.get_node("Center/VBox/ContinueButton").disabled)
	assert_true(screen.get_node("Center/VBox/LoadButton").disabled)


func test_new_game_and_quit_are_always_enabled() -> void:
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)

	assert_false(screen.get_node("Center/VBox/NewGameButton").disabled)
	assert_false(screen.get_node("Center/VBox/QuitButton").disabled)
