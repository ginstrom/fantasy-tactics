extends GutTest

const GameMenuScene := preload("res://scenes/ui/game_menu.tscn")


func _escape_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func before_each() -> void:
	GameManager.has_saved_game = false
	GameManager.close_game_menu()


func after_each() -> void:
	GameManager.has_saved_game = false
	GameManager.close_game_menu()


func test_load_is_disabled_without_a_saved_game() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	assert_true(menu.get_node("Center/VBox/LoadButton").disabled)


func test_return_save_and_quit_are_always_enabled() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	assert_false(menu.get_node("Center/VBox/ReturnButton").disabled)
	assert_false(menu.get_node("Center/VBox/WorldMapButton").disabled)
	assert_false(menu.get_node("Center/VBox/SaveButton").disabled)
	assert_false(menu.get_node("Center/VBox/QuitButton").disabled)


func test_pressing_world_map_closes_the_menu_and_unpauses_the_game() -> void:
	GameManager.open_game_menu()
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	menu.get_node("Center/VBox/WorldMapButton").emit_signal("pressed")

	assert_false(GameManager.is_game_menu_open())
	assert_false(get_tree().paused)


func test_pressing_save_shows_the_not_implemented_status() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	var status: Label = menu.get_node("Center/VBox/StatusLabel")

	menu.get_node("Center/VBox/SaveButton").emit_signal("pressed")

	assert_true(status.visible)
	assert_eq(status.text, "Not implemented yet")


func test_refresh_hides_the_status_label_after_it_was_shown() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	var status: Label = menu.get_node("Center/VBox/StatusLabel")
	menu.get_node("Center/VBox/SaveButton").emit_signal("pressed")
	assert_true(status.visible, "Sanity check: Save should show the status label")

	menu.refresh()

	assert_false(status.visible)


func test_refresh_recomputes_load_button_disabled_state() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	var load_button: Button = menu.get_node("Center/VBox/LoadButton")
	assert_true(load_button.disabled, "Sanity check: no saved game yet")

	GameManager.has_saved_game = true
	menu.refresh()

	assert_false(load_button.disabled)


func test_pressing_return_closes_the_menu_and_unpauses_the_game() -> void:
	GameManager.open_game_menu()
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	menu.get_node("Center/VBox/ReturnButton").emit_signal("pressed")

	assert_false(GameManager.is_game_menu_open())
	assert_false(get_tree().paused)


func test_escape_closes_the_menu_when_it_is_visible() -> void:
	GameManager.open_game_menu()
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	menu.visible = true

	menu._unhandled_input(_escape_event())

	assert_false(GameManager.is_game_menu_open())
	assert_false(get_tree().paused)


func test_escape_is_ignored_while_this_overlay_instance_is_hidden() -> void:
	# Guards the `if visible` check: a hidden overlay must not react to
	# Escape even if something still routes input to it.
	GameManager.open_game_menu()
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	menu.visible = false

	menu._unhandled_input(_escape_event())

	assert_true(GameManager.is_game_menu_open(), "Escape must be ignored while this instance is hidden")


# Quit is intentionally not click-tested here: GameManager.quit_game() calls
# get_tree().quit(), which would terminate the test run. Its disabled state
# is covered by test_return_save_and_quit_are_always_enabled() above.
