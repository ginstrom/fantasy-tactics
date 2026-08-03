extends GutTest

const GameMenuScene := preload("res://scenes/ui/game_menu.tscn")


func before_each() -> void:
	GameManager.has_saved_game = false


func test_load_is_disabled_without_a_saved_game() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	assert_true(menu.get_node("Center/VBox/LoadButton").disabled)


func test_return_save_and_quit_are_always_enabled() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	assert_false(menu.get_node("Center/VBox/ReturnButton").disabled)
	assert_false(menu.get_node("Center/VBox/SaveButton").disabled)
	assert_false(menu.get_node("Center/VBox/QuitButton").disabled)


func test_pressing_save_shows_the_not_implemented_status() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	var status: Label = menu.get_node("Center/VBox/StatusLabel")

	menu.get_node("Center/VBox/SaveButton").emit_signal("pressed")

	assert_true(status.visible)
	assert_eq(status.text, "Not implemented yet")
