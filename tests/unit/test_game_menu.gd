extends GutTest

const GameMenuScene := preload("res://scenes/ui/game_menu.tscn")
const SaveRepositoryScript := preload("res://scripts/save/save_repository.gd")
const TEST_SAVE_PATH := "user://test_game_menu_campaign.json"


func _escape_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func before_each() -> void:
	GameManager.save_repository = SaveRepositoryScript.new(TEST_SAVE_PATH)
	GameManager.close_game_menu()
	GameSession.reset()


func after_each() -> void:
	GameManager.save_repository = SaveRepositoryScript.new()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)
	GameManager.close_game_menu()
	GameSession.reset()


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


func test_pressing_save_shows_the_success_status_and_writes_the_repository() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	var status: Label = menu.get_node("Center/VBox/StatusLabel")

	menu.get_node("Center/VBox/SaveButton").emit_signal("pressed")

	assert_true(status.visible)
	assert_eq(status.text, "Campaign saved.")
	assert_true(GameManager.has_valid_save())


func test_pressing_save_during_an_active_encounter_shows_a_failure_status_and_writes_nothing() -> void:
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	var status: Label = menu.get_node("Center/VBox/StatusLabel")

	menu.get_node("Center/VBox/SaveButton").emit_signal("pressed")

	assert_true(status.visible)
	assert_eq(status.text, "Save failed.")
	assert_false(GameManager.has_valid_save(), "A blocked save must not write to the repository")
	GameSession.abandon_current_encounter()


func test_pressing_load_with_a_saved_game_imports_it_and_closes_the_menu() -> void:
	GameSession.gold = 321
	GameManager.save_repository.save_campaign(GameSession)
	GameSession.reset()
	GameManager.open_game_menu()
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	menu.get_node("Center/VBox/LoadButton").emit_signal("pressed")

	assert_eq(GameSession.gold, 321)
	assert_false(GameManager.is_game_menu_open())
	assert_false(get_tree().paused)


func test_pressing_load_without_a_saved_game_shows_a_failure_status_and_keeps_the_menu_open() -> void:
	GameManager.open_game_menu()
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	var status: Label = menu.get_node("Center/VBox/StatusLabel")

	menu.get_node("Center/VBox/LoadButton").emit_signal("pressed")

	assert_true(status.visible)
	assert_eq(status.text, "Load failed.")
	assert_true(GameManager.is_game_menu_open(), "A failed load must not close the pause menu")


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

	GameManager.save_repository.save_campaign(GameSession)
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


func test_game_menu_source_never_touches_the_filesystem_repository_or_game_session_directly() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/game_menu.gd")

	assert_false(source.contains("FileAccess"), "Save/Load intents must go through GameManager, never FileAccess directly")
	assert_false(source.contains("DirAccess"), "Save/Load intents must go through GameManager, never DirAccess directly")
	assert_false(source.contains("SaveRepository"), "Save/Load intents must go through GameManager, never SaveRepository directly")
	assert_false(source.contains("GameSession"), "Save/Load intents must go through GameManager, never GameSession directly")


# Quit is intentionally not click-tested here: GameManager.quit_game() calls
# get_tree().quit(), which would terminate the test run. Its disabled state
# is covered by test_return_save_and_quit_are_always_enabled() above.
