extends GutTest
## Covers Step 8's Tasks 1-3 (docs/plans/2026-08-18-core-loop-and-engagement/
## 08-audio-system-and-soundscape.md): bus volume/mute control and its
## persistence, sound-effect playback and pitch jitter, and music
## state/crossfade transitions. AudioManager is an autoload (like GameSession/
## GameManager), so tests call the real singleton directly rather than
## instantiating a bare copy -- reset() in before_each/after_each keeps state
## from leaking between tests, mirroring GameSession.reset()'s own
## convention.

const TEST_SETTINGS_PATH := "user://test_audio_manager_settings.json"


func before_each() -> void:
	AudioManager.settings_path = TEST_SETTINGS_PATH
	_remove_test_settings_file()
	AudioManager.reset()


func after_each() -> void:
	_remove_test_settings_file()
	AudioManager.settings_path = AudioManager.DEFAULT_SETTINGS_PATH
	AudioManager.reset()


func _remove_test_settings_file() -> void:
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(TEST_SETTINGS_PATH)


## --- Task 1: Bus & Volume Control -------------------------------------------

func test_set_bus_volume_updates_the_real_audio_server_bus_volume_in_decibels() -> void:
	AudioManager.set_bus_volume("Music", 0.5)

	var idx := AudioServer.get_bus_index("Music")
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), linear_to_db(0.5), 0.01)
	assert_almost_eq(AudioManager.get_bus_volume("Music"), 0.5, 0.01)


func test_set_bus_volume_clamps_to_the_zero_to_one_range() -> void:
	AudioManager.set_bus_volume("SFX", 5.0)
	assert_almost_eq(AudioManager.get_bus_volume("SFX"), 1.0, 0.001)

	AudioManager.set_bus_volume("SFX", -3.0)
	assert_almost_eq(AudioManager.get_bus_volume("SFX"), 0.0, 0.001)


func test_muting_a_bus_sets_the_real_audio_server_mute_flag() -> void:
	AudioManager.set_bus_volume("SFX", 1.0)
	AudioManager.set_bus_mute("SFX", true)

	var idx := AudioServer.get_bus_index("SFX")
	assert_true(AudioServer.is_bus_mute(idx), "AudioServer must actually silence the muted bus")
	assert_true(AudioManager.is_bus_muted("SFX"))
	# Mute and volume are independent controls -- muting must not clobber the
	# slider's own value, so un-muting restores exactly what it was.
	assert_almost_eq(AudioManager.get_bus_volume("SFX"), 1.0, 0.01)


func test_unmuting_restores_the_real_audio_server_mute_flag() -> void:
	AudioManager.set_bus_mute("Master", true)
	AudioManager.set_bus_mute("Master", false)

	assert_false(AudioManager.is_bus_muted("Master"))
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")))


func test_volume_and_mute_settings_persist_across_save_and_load() -> void:
	AudioManager.set_bus_volume("Master", 0.3)
	AudioManager.set_bus_volume("Music", 0.6)
	AudioManager.set_bus_mute("SFX", true)

	# Simulate a fresh boot: reset every bus back to defaults, then reload
	# from the settings file the setters above already wrote.
	AudioManager.reset()
	assert_almost_eq(AudioManager.get_bus_volume("Master"), 1.0, 0.001, "sanity: reset() must clear prior state")

	AudioManager.load_settings()

	assert_almost_eq(AudioManager.get_bus_volume("Master"), 0.3, 0.01)
	assert_almost_eq(AudioManager.get_bus_volume("Music"), 0.6, 0.01)
	assert_true(AudioManager.is_bus_muted("SFX"))
	assert_false(AudioManager.is_bus_muted("Master"))


func test_load_settings_with_no_file_on_disk_leaves_defaults_untouched() -> void:
	AudioManager.load_settings()

	assert_almost_eq(AudioManager.get_bus_volume("Master"), 1.0, 0.001)
	assert_false(AudioManager.is_bus_muted("Master"))


## --- Task 2: Sound Effect Triggers -------------------------------------------

func test_play_sfx_loads_and_starts_playing_the_named_asset() -> void:
	AudioManager.play_sfx("sfx_hit_impact")

	assert_eq(AudioManager.last_sfx_id, "sfx_hit_impact")
	assert_true(AudioManager.is_any_sfx_playing())


func test_play_sfx_with_an_unknown_id_fails_soft_without_crashing() -> void:
	AudioManager.play_sfx("sfx_this_id_does_not_exist")

	assert_eq(AudioManager.last_sfx_id, "sfx_this_id_does_not_exist")
	assert_false(AudioManager.is_any_sfx_playing(), "A missing asset must never start playback")


func test_play_sfx_pitch_jitter_is_applied_within_the_requested_range() -> void:
	AudioManager.pitch_jitter_roll = func() -> float: return 1.0
	AudioManager.play_sfx("sfx_ui_click", 0.05)
	assert_almost_eq(AudioManager.last_sfx_pitch_scale, 1.05, 0.001)

	AudioManager.pitch_jitter_roll = func() -> float: return -1.0
	AudioManager.play_sfx("sfx_ui_click", 0.05)
	assert_almost_eq(AudioManager.last_sfx_pitch_scale, 0.95, 0.001)


func test_play_sfx_pitch_jitter_stays_within_the_specified_range_under_real_randomness() -> void:
	AudioManager.pitch_jitter_roll = func() -> float: return randf_range(-1.0, 1.0)
	for i in range(25):
		AudioManager.play_sfx("sfx_ui_click", 0.05)
		assert_between(AudioManager.last_sfx_pitch_scale, 0.95, 1.05)


## --- Task 3: Music State Transitions -----------------------------------------

func test_play_music_sets_the_current_track_and_starts_playback() -> void:
	AudioManager.play_music("music_encampment", 0.0)

	assert_true(AudioManager.is_music_playing("music_encampment"))


func test_play_music_with_the_already_playing_track_is_a_noop() -> void:
	AudioManager.play_music("music_world_map", 0.0)
	var track_before := AudioManager.current_music_track_id

	AudioManager.play_music("music_world_map", 1.0)

	assert_eq(AudioManager.current_music_track_id, track_before)
	assert_false(AudioManager.is_crossfading(), "Repeating the same track must not start a fresh crossfade")


func test_scene_transitions_request_the_correct_track_and_crossfade_smoothly() -> void:
	# Encampment -> World Map -> Battle -> Victory, the exact sequence the
	# Milestone names (see GameManager's real navigation call sites; this
	# level of the test isolates AudioManager's own contract).
	AudioManager.play_music("music_encampment", 1.0)
	assert_eq(AudioManager.current_music_track_id, "music_encampment")

	AudioManager.play_music("music_world_map", 1.0)
	assert_eq(AudioManager.current_music_track_id, "music_world_map")
	assert_true(AudioManager.is_crossfading(), "A transition to a new track must crossfade, not hard-cut")

	AudioManager.play_music("music_battle", 1.0)
	assert_eq(AudioManager.current_music_track_id, "music_battle")

	AudioManager.play_music("music_victory", 1.0)
	assert_eq(AudioManager.current_music_track_id, "music_victory")


func test_stop_music_clears_the_current_track() -> void:
	AudioManager.play_music("music_defeat", 0.0)

	AudioManager.stop_music(0.0)

	assert_eq(AudioManager.current_music_track_id, "")
