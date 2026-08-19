extends GutTest

const GameMenuScene := preload("res://scenes/ui/game_menu.tscn")
const SaveRepositoryScript := preload("res://scripts/save/save_repository.gd")
const TEST_SAVE_PATH := "user://test_game_menu_campaign.json"
## The Audio Settings tests below call AudioManager.set_bus_volume()/
## set_bus_mute(), which persist to disk -- point that write at a throwaway
## path for this file's whole run, mirroring TEST_SAVE_PATH's own reasoning
## just above, so no test run ever touches the real audio-settings.json.
const TEST_AUDIO_SETTINGS_PATH := "user://test_game_menu_audio_settings.json"


func _escape_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func before_each() -> void:
	GameManager.save_repository = SaveRepositoryScript.new(TEST_SAVE_PATH)
	GameManager.close_game_menu()
	GameSession.reset()
	AudioManager.settings_path = TEST_AUDIO_SETTINGS_PATH
	AudioManager.reset()


func after_each() -> void:
	GameManager.save_repository = SaveRepositoryScript.new()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)
	GameManager.close_game_menu()
	GameSession.reset()
	AudioManager.reset()
	AudioManager.settings_path = AudioManager.DEFAULT_SETTINGS_PATH
	if FileAccess.file_exists(TEST_AUDIO_SETTINGS_PATH):
		DirAccess.remove_absolute(TEST_AUDIO_SETTINGS_PATH)


func test_load_is_disabled_without_a_saved_game() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	assert_true(menu.get_node("Center/VBox/LoadButton").disabled)


func test_return_world_map_and_quit_are_always_enabled() -> void:
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	assert_false(menu.get_node("Center/VBox/ReturnButton").disabled)
	assert_false(menu.get_node("Center/VBox/WorldMapButton").disabled)
	assert_false(menu.get_node("Center/VBox/QuitButton").disabled)
	GameSession.abandon_current_encounter()


func test_save_button_is_enabled_when_saving_is_allowed() -> void:
	GameSession.reset()
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	assert_false(menu.get_node("Center/VBox/SaveButton").disabled)


func test_save_button_is_disabled_during_an_active_encounter() -> void:
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)

	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	assert_true(menu.get_node("Center/VBox/SaveButton").disabled)
	GameSession.abandon_current_encounter()


func test_save_button_is_disabled_when_battle_loot_is_unsettled() -> void:
	GameSession.battle_reward = 5

	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	assert_true(menu.get_node("Center/VBox/SaveButton").disabled)


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


## --- Load confirmation (manual-verification fix: Load had no confirm- -----
## --- before-overwrite prompt). Pressing Load in the pause menu must never --
## --- call GameManager.go_to_loaded_campaign() immediately -- it would -----
## --- silently discard whatever unsaved progress is live in GameSession ----
## --- right now. It only raises a confirmation prompt; the prompt's own ----
## --- Confirm action is what actually performs the load a bare press used -
## --- to trigger directly (see the two tests below this block, updated to -
## --- go through the prompt). Start Menu's Continue/Load are deliberately -
## --- NOT covered by this prompt -- see test_start_menu.gd -- there is no -
## --- campaign in progress yet at the Start Menu, so there is nothing to --
## --- lose.


func test_load_confirm_dialog_is_hidden_until_load_is_pressed() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	assert_false(menu.get_node("LoadConfirmDialog").visible)


func test_pressing_load_shows_a_confirmation_dialog_and_does_not_load_immediately() -> void:
	GameSession.gold = 321
	GameManager.save_repository.save_campaign(GameSession)
	GameSession.reset()
	GameSession.gold = 7
	GameManager.open_game_menu()
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	menu.get_node("Center/VBox/LoadButton").emit_signal("pressed")

	assert_true(menu.get_node("LoadConfirmDialog").visible, "Load must raise a confirmation prompt, not load immediately")
	assert_eq(GameSession.gold, 7, "Pressing Load alone must not import the saved campaign yet")
	assert_true(GameManager.is_game_menu_open(), "The pause menu must stay open behind the prompt")


func test_pressing_cancel_on_the_load_confirmation_leaves_everything_untouched() -> void:
	GameSession.gold = 321
	GameManager.save_repository.save_campaign(GameSession)
	GameSession.reset()
	GameSession.gold = 7
	GameManager.open_game_menu()
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	menu.get_node("Center/VBox/LoadButton").emit_signal("pressed")

	menu.get_node("LoadConfirmDialog/VBox/ButtonRow/CancelButton").emit_signal("pressed")

	assert_false(menu.get_node("LoadConfirmDialog").visible, "Cancel must close the prompt")
	assert_eq(GameSession.gold, 7, "Cancel must never import the saved campaign")
	assert_true(GameManager.is_game_menu_open(), "Cancel must leave the pause menu open, not route anywhere")
	assert_true(get_tree().paused, "Cancel must not unpause -- the pause menu it leaves open is still open")


func test_confirming_the_load_dialog_with_a_saved_game_imports_it_and_closes_the_menu() -> void:
	GameSession.gold = 321
	GameManager.save_repository.save_campaign(GameSession)
	GameSession.reset()
	GameManager.open_game_menu()
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	menu.get_node("Center/VBox/LoadButton").emit_signal("pressed")

	menu.get_node("LoadConfirmDialog/VBox/ButtonRow/ConfirmButton").emit_signal("pressed")

	assert_eq(GameSession.gold, 321)
	assert_false(menu.get_node("LoadConfirmDialog").visible)
	assert_false(GameManager.is_game_menu_open())
	assert_false(get_tree().paused)


func test_confirming_the_load_dialog_without_a_saved_game_shows_a_failure_status_and_keeps_the_menu_open() -> void:
	GameManager.open_game_menu()
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	var status: Label = menu.get_node("Center/VBox/StatusLabel")
	menu.get_node("Center/VBox/LoadButton").emit_signal("pressed")

	menu.get_node("LoadConfirmDialog/VBox/ButtonRow/ConfirmButton").emit_signal("pressed")

	assert_false(menu.get_node("LoadConfirmDialog").visible, "The prompt must close even when the load it triggers fails")
	assert_true(status.visible)
	assert_eq(status.text, "Load failed.")
	assert_true(GameManager.is_game_menu_open(), "A failed load must not close the pause menu")


func test_refresh_hides_the_load_confirm_dialog_after_it_was_shown() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	menu.get_node("Center/VBox/LoadButton").emit_signal("pressed")
	assert_true(menu.get_node("LoadConfirmDialog").visible, "Sanity check: Load should show the prompt")

	menu.refresh()

	assert_false(menu.get_node("LoadConfirmDialog").visible)


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
# is covered by test_return_world_map_and_quit_are_always_enabled() above.


## --- Audio Settings (Task 4, docs/plans/2026-08-18-core-loop-and-engagement/
## 08-audio-system-and-soundscape.md) --- the panel is embedded directly in
## this scene (scenes/ui/audio_settings.tscn, instanced as the "AudioSettings"
## node) and toggled by the Audio button, mirroring LoadConfirmDialog's own
## show/hide pattern. Its sliders/mute toggles drive AudioManager directly
## (see scripts/ui/audio_settings.gd) -- these tests only prove the Game
## Menu's own wiring (button toggles the panel; the panel's controls really
## do move AudioManager's bus state) rather than re-testing AudioManager
## itself (see tests/unit/test_audio_manager.gd for that).

func test_audio_settings_panel_is_hidden_until_the_audio_button_is_pressed() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	assert_false(menu.get_node("AudioSettings").visible)


func test_pressing_the_audio_button_shows_the_audio_settings_panel() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	menu.get_node("Center/VBox/AudioButton").emit_signal("pressed")

	assert_true(menu.get_node("AudioSettings").visible)


func test_pressing_the_audio_button_again_hides_the_panel() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	menu.get_node("Center/VBox/AudioButton").emit_signal("pressed")

	menu.get_node("Center/VBox/AudioButton").emit_signal("pressed")

	assert_false(menu.get_node("AudioSettings").visible)


func test_refresh_hides_the_audio_settings_panel_after_it_was_shown() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	menu.get_node("Center/VBox/AudioButton").emit_signal("pressed")
	assert_true(menu.get_node("AudioSettings").visible, "Sanity check: Audio should show the panel")

	menu.refresh()

	assert_false(menu.get_node("AudioSettings").visible)


func test_moving_the_master_slider_in_the_game_menu_adjusts_the_audio_manager_bus() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	menu.get_node("Center/VBox/AudioButton").emit_signal("pressed")
	var slider: HSlider = menu.get_node("AudioSettings/VBox/MasterRow/MasterSlider")

	slider.value = 0.4

	assert_almost_eq(AudioManager.get_bus_volume("Master"), 0.4, 0.01)


func test_moving_the_music_slider_in_the_game_menu_adjusts_the_audio_manager_bus() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	menu.get_node("Center/VBox/AudioButton").emit_signal("pressed")
	var slider: HSlider = menu.get_node("AudioSettings/VBox/MusicRow/MusicSlider")

	slider.value = 0.7

	assert_almost_eq(AudioManager.get_bus_volume("Music"), 0.7, 0.01)


func test_moving_the_sfx_slider_in_the_game_menu_adjusts_the_audio_manager_bus() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	menu.get_node("Center/VBox/AudioButton").emit_signal("pressed")
	var slider: HSlider = menu.get_node("AudioSettings/VBox/SFXRow/SFXSlider")

	slider.value = 0.1

	assert_almost_eq(AudioManager.get_bus_volume("SFX"), 0.1, 0.01)


func test_toggling_the_master_mute_button_in_the_game_menu_mutes_the_audio_manager_bus() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	menu.get_node("Center/VBox/AudioButton").emit_signal("pressed")
	var mute_button: CheckButton = menu.get_node("AudioSettings/VBox/MasterRow/MasterMuteButton")

	mute_button.button_pressed = true

	assert_true(AudioManager.is_bus_muted("Master"))


func test_opening_the_audio_panel_shows_the_audio_managers_current_bus_state() -> void:
	AudioManager.set_bus_volume("SFX", 0.25)
	AudioManager.set_bus_mute("Music", true)
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	menu.get_node("Center/VBox/AudioButton").emit_signal("pressed")

	var sfx_slider: HSlider = menu.get_node("AudioSettings/VBox/SFXRow/SFXSlider")
	var music_mute_button: CheckButton = menu.get_node("AudioSettings/VBox/MusicRow/MusicMuteButton")
	assert_almost_eq(sfx_slider.value, 0.25, 0.01)
	assert_true(music_mute_button.button_pressed)
