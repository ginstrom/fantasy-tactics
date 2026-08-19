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


## --- Task 2: Bus Validation (docs/plans/2026-08-19-core-loop-verification-
## remediation/03-audio-bus-contract.md) ---------------------------------------

func test_validate_buses_reports_every_missing_bus_name_and_emits_an_actionable_error() -> void:
	# "NotARealBus"/"AlsoNotReal" are provably absent -- no default_bus_layout.tres
	# entry or engine built-in bus is ever named this -- so this proves the
	# helper actually detects a genuinely missing bus, unlike a check against
	# today's real BUS_NAMES, which already all exist and would pass
	# vacuously even if the detection logic were broken.
	var missing := AudioManager.validate_buses(["Master", "NotARealBus", "AlsoNotReal"])

	assert_eq(missing, ["NotARealBus", "AlsoNotReal"], "must report every missing bus, not just the first")
	assert_push_error("NotARealBus")
	assert_push_error("AlsoNotReal")


func test_validate_buses_reports_nothing_missing_and_does_not_error_for_a_bus_that_exists() -> void:
	var missing := AudioManager.validate_buses(["Master"])

	assert_eq(missing, [])


func test_validate_buses_with_the_real_bus_names_reports_nothing_missing() -> void:
	# Exercises the exact call _ready() makes on startup (BUS_NAMES against
	# the live AudioServer). Passes only because project.godot's
	# [audio] buses/default_bus_layout and default_bus_layout.tres both
	# correctly declare Master/Music/SFX -- the same regression
	# test_project_audio_contract.gd guards structurally by reading
	# project.godot itself.
	assert_eq(AudioManager.validate_buses(AudioManager.BUS_NAMES), [])


## --- Task 3: Independent Bus Controls (docs/plans/2026-08-19-core-loop-
## verification-remediation/03-audio-bus-contract.md) --------------------------

func test_muting_music_leaves_sfx_unmuted() -> void:
	# Assert both buses actually resolved to real AudioServer indices first --
	# without this, a silently-missing bus would make the mute calls below
	# no-op (_apply_bus_mute()'s `if idx == -1: return`) and the assertions
	# past that point would pass vacuously instead of proving independence.
	assert_ne(AudioServer.get_bus_index("Music"), -1, "Music bus must exist for this test to be meaningful")
	assert_ne(AudioServer.get_bus_index("SFX"), -1, "SFX bus must exist for this test to be meaningful")

	AudioManager.set_bus_mute("Music", true)

	assert_true(AudioManager.is_bus_muted("Music"))
	assert_false(AudioManager.is_bus_muted("SFX"), "Muting Music must not mute SFX")
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")))


func test_muting_sfx_leaves_music_unmuted() -> void:
	assert_ne(AudioServer.get_bus_index("Music"), -1, "Music bus must exist for this test to be meaningful")
	assert_ne(AudioServer.get_bus_index("SFX"), -1, "SFX bus must exist for this test to be meaningful")

	AudioManager.set_bus_mute("SFX", true)

	assert_true(AudioManager.is_bus_muted("SFX"))
	assert_false(AudioManager.is_bus_muted("Music"), "Muting SFX must not mute Music")
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))


func test_setting_music_volume_does_not_change_sfx_volume() -> void:
	assert_ne(AudioServer.get_bus_index("Music"), -1, "Music bus must exist for this test to be meaningful")
	assert_ne(AudioServer.get_bus_index("SFX"), -1, "SFX bus must exist for this test to be meaningful")

	AudioManager.set_bus_volume("SFX", 1.0)
	AudioManager.set_bus_volume("Music", 0.2)

	assert_almost_eq(AudioManager.get_bus_volume("Music"), 0.2, 0.01)
	assert_almost_eq(AudioManager.get_bus_volume("SFX"), 1.0, 0.01, "Changing Music volume must not affect SFX volume")
