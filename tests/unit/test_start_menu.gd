extends GutTest

const StartMenuScene := preload("res://scenes/ui/start_menu.tscn")


func before_each() -> void:
	GameManager.has_saved_game = false
	GameSession.reset()


func after_each() -> void:
	GameManager.has_saved_game = false


func test_continue_and_load_are_disabled_without_a_saved_game() -> void:
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)

	assert_true(screen.get_node("Center/VBox/ContinueButton").disabled)
	assert_true(screen.get_node("Center/VBox/LoadButton").disabled)


func test_continue_and_load_are_enabled_with_a_saved_game() -> void:
	GameManager.has_saved_game = true
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)

	assert_false(screen.get_node("Center/VBox/ContinueButton").disabled)
	assert_false(screen.get_node("Center/VBox/LoadButton").disabled)


func test_new_game_and_quit_are_always_enabled() -> void:
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)

	assert_false(screen.get_node("Center/VBox/NewGameButton").disabled)
	assert_false(screen.get_node("Center/VBox/QuitButton").disabled)


func test_new_game_reveals_name_entry_and_hides_the_main_menu_buttons() -> void:
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)

	screen._on_new_game_pressed()

	assert_true(screen.get_node("Center/VBox/NameEntry").visible)
	assert_false(screen.get_node("Center/VBox/ContinueButton").visible)
	assert_false(screen.get_node("Center/VBox/NewGameButton").visible)
	assert_false(screen.get_node("Center/VBox/LoadButton").visible)
	assert_false(screen.get_node("Center/VBox/QuitButton").visible)


func test_begin_button_is_disabled_until_a_name_is_entered() -> void:
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)
	var begin_button: Button = screen.get_node("Center/VBox/NameEntry/BeginButton")
	assert_true(begin_button.disabled)

	screen._on_name_input_text_changed("Aria")
	assert_false(begin_button.disabled)

	screen._on_name_input_text_changed("   ")
	assert_true(begin_button.disabled, "Whitespace-only input must not count as a name")


func test_begin_button_starts_a_new_game_with_the_entered_player_name() -> void:
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)
	screen.get_node("Center/VBox/NameEntry/NameInput").text = "Aria"

	screen._on_begin_pressed()

	assert_eq(GameSession.player_name, "Aria")


func test_begin_button_does_nothing_when_the_name_is_blank() -> void:
	GameSession.player_name = "Unchanged"
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)
	screen.get_node("Center/VBox/NameEntry/NameInput").text = "   "

	screen._on_begin_pressed()

	assert_eq(GameSession.player_name, "Unchanged")


func test_continue_reuses_the_current_player_name() -> void:
	GameSession.player_name = "Aria"
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)

	screen._on_continue_pressed()

	assert_eq(GameSession.player_name, "Aria")
