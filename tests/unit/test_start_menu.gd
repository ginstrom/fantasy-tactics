extends GutTest

const StartMenuScene := preload("res://scenes/ui/start_menu.tscn")
const SaveRepositoryScript := preload("res://scripts/save/save_repository.gd")
const TEST_SAVE_PATH := "user://test_start_menu_campaign.json"


func before_each() -> void:
	GameSession.reset()
	GameManager.save_repository = SaveRepositoryScript.new(TEST_SAVE_PATH)


func after_each() -> void:
	GameManager.save_repository = SaveRepositoryScript.new()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)
	GameManager.route_context_id = ""


func test_continue_and_load_are_disabled_without_a_saved_game() -> void:
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)

	assert_true(screen.get_node("Center/VBox/ContinueButton").disabled)
	assert_true(screen.get_node("Center/VBox/LoadButton").disabled)


func test_continue_and_load_are_enabled_with_a_saved_game() -> void:
	GameManager.save_repository.save_campaign(GameSession)
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


func test_random_button_fills_the_name_field_with_one_of_the_two_choices() -> void:
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)

	screen._on_random_button_pressed()

	var name_input: LineEdit = screen.get_node("Center/VBox/NameEntry/NameInput")
	assert_true(name_input.text in ["The Black Company", "Company of Saints"])


func test_random_button_enables_the_begin_button() -> void:
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)
	var begin_button: Button = screen.get_node("Center/VBox/NameEntry/BeginButton")
	assert_true(begin_button.disabled)

	screen._on_random_button_pressed()

	assert_false(begin_button.disabled)


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


func test_continue_loads_the_saved_campaign() -> void:
	GameSession.player_name = "Saved Name"
	GameSession.gold = 88
	GameManager.save_repository.save_campaign(GameSession)
	GameSession.reset()
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)

	screen._on_continue_pressed()

	assert_eq(GameSession.player_name, "Saved Name")
	assert_eq(GameSession.gold, 88)


func test_load_button_loads_the_saved_campaign() -> void:
	GameSession.player_name = "Saved Name"
	GameManager.save_repository.save_campaign(GameSession)
	GameSession.reset()
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)

	screen._on_load_pressed()

	assert_eq(GameSession.player_name, "Saved Name")


func test_continue_without_a_saved_game_leaves_game_session_untouched() -> void:
	GameSession.player_name = "Unchanged"
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)

	screen._on_continue_pressed()

	assert_eq(GameSession.player_name, "Unchanged")


func test_start_menu_source_never_touches_the_filesystem_or_a_repository_directly() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/start_menu.gd")

	assert_false(source.contains("FileAccess"), "Save/Load intents must go through GameManager, never FileAccess directly")
	assert_false(source.contains("DirAccess"), "Save/Load intents must go through GameManager, never DirAccess directly")
	assert_false(source.contains("SaveRepository"), "Save/Load intents must go through GameManager, never SaveRepository directly")
	assert_false(source.contains("GameSession"), "Save/Load intents must go through GameManager, never GameSession directly")


## The pause menu's Load gained a confirm-before-overwrite prompt (see
## test_game_menu.gd) because a live campaign might be running when it's
## pressed. At the Start Menu there is no campaign in progress yet -- it's
## the entry point -- so Continue/Load have nothing to lose and must stay
## exactly as immediate as they've always been. Asserted at the source
## level (rather than only via test_continue_loads_the_saved_campaign() /
## test_load_button_loads_the_saved_campaign() above already calling
## go_to_loaded_campaign() with no dialog step in between) so this is a
## direct, structural guarantee: no dialog/confirmation node or reference
## ever gates the Start Menu's own load path, now or if this file grows.
func test_start_menu_load_path_is_not_gated_by_any_confirmation_dialog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/start_menu.gd")

	assert_false(source.contains("Dialog"), "Start Menu's Continue/Load must never be gated by a confirmation dialog")
	assert_false(source.contains("confirm"), "Start Menu's Continue/Load must never be gated by a confirmation step")
