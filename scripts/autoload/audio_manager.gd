extends Node
## Audio Manager Autoload (docs/plans/2026-08-18-core-loop-and-engagement/
## 08-audio-system-and-soundscape.md): owns the Master/Music/SFX bus
## contract (see default_bus_layout.tres, wired via project.godot's
## `[audio] buses/default_bus_layout`), volume/mute controls, sound-effect
## playback, and music crossfading. Callers (battle_controller.gd,
## encampment.gd, world_map.gd, battlefield.gd, scripts/ui/audio_settings.gd)
## never touch AudioServer, AudioStreamPlayer, or the filesystem directly --
## every bus/playback mechanic lives here.
##
## Persistence: volume/mute settings are a device/user preference, not
## campaign save data (CampaignSnapshot/SaveRepository) -- they must survive
## starting a fresh campaign, loading a different save, or even having no
## save at all yet, and CampaignSnapshot's strict versioned-field contract
## (see docs/plans/2026-08-10-initial-campaign-and-automation/
## 01-campaign-snapshot-contract.md) is the wrong shape for a handful of
## scalar device settings that never need migration/validation history of
## their own. So this owns a small standalone user:// file instead,
## following the same "test-injectable path, atomic-enough single write"
## shape as SaveRepository but far simpler (no versioned envelope, no
## rejection contract -- a missing/corrupt file just falls back to defaults,
## the same failure-mode shape GameConfig uses for its own JSON).

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const BUS_NAMES: Array[String] = ["Master", "Music", "SFX"]
const DEFAULT_SETTINGS_PATH := "user://audio-settings.json"
const SFX_PLAYER_POOL_SIZE := 8
const DEFAULT_CROSSFADE_DURATION := 1.0
const SILENT_DB := -80.0

## Overridable so tests can point this at a throwaway path instead of the
## real user:// settings file (mirrors SaveRepository.save_path's own
## test-injectable constructor parameter).
var settings_path: String = DEFAULT_SETTINGS_PATH

## Random pitch-jitter roll, injectable for deterministic tests (mirrors
## battle_controller.gd's hit_roll/crit_roll/damage_roll Callable pattern).
## Returns a value in [-1.0, 1.0]; play_sfx() scales it by pitch_jitter.
var pitch_jitter_roll: Callable = func() -> float: return randf_range(-1.0, 1.0)

## Observability for tests: the most recent play_sfx()/play_music() calls,
## rather than reaching into AudioStreamPlayer node internals.
var last_sfx_id: String = ""
var last_sfx_pitch_scale: float = 1.0
var current_music_track_id: String = ""

## Observability for tests: total number of play_sfx() calls since the last
## reset() -- lets a test prove a sound played *exactly once* rather than
## only "was eventually played" (see tests/unit/test_game_menu.gd's
## drag-does-not-spam-the-preview-click coverage, added alongside the
## drag_ended debounce in scripts/ui/audio_settings.gd).
var sfx_play_count: int = 0

var _warned_missing_assets: Dictionary = {}

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_music_player: AudioStreamPlayer
var _music_tween: Tween


func _ready() -> void:
	for i in range(SFX_PLAYER_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)

	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = "Music"
	add_child(_music_player_a)
	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = "Music"
	add_child(_music_player_b)
	_active_music_player = _music_player_a

	load_settings()


## Releases every pooled player's stream reference on shutdown. Without
## this, whichever AudioStreamPlayer last played a clip keeps its
## AudioStreamWAV (and the live AudioStreamPlaybackWAV .play() created)
## referenced for the rest of the process's life -- correct and harmless
## during a real play session (this autoload is meant to keep whatever was
## last playing alive right up until the game quits), but it shows up as a
## "resource still in use at exit" / leaked-instance report at the end of an
## automated test run, since nothing else ever explicitly stops the last
## clip a test happened to play. Freeing the reference here (not just
## calling stop(), which alone does not release .stream) is what actually
## clears it.
func _exit_tree() -> void:
	for player in _sfx_players:
		player.stop()
		player.stream = null
	if _music_player_a != null:
		_music_player_a.stop()
		_music_player_a.stream = null
	if _music_player_b != null:
		_music_player_b.stop()
		_music_player_b.stream = null


## Resets to fresh-boot defaults: full volume, unmuted, no music playing.
## Tests call this the same way they call GameSession.reset() in
## before_each, so state from one test cannot leak into the next.
func reset() -> void:
	for bus_name in BUS_NAMES:
		_apply_bus_volume(bus_name, 1.0)
		_apply_bus_mute(bus_name, false)
	stop_music(0.0)
	# stop_music() only guarantees the *active* music player stops; a
	# just-completed crossfade test can still leave the other one mid-clip.
	# Headless test runs use Godot's Dummy audio driver, which never
	# advances playback position on its own, so a played AudioStreamPlayer's
	# `.playing` flag would otherwise stay true indefinitely across tests
	# rather than naturally finishing -- explicit stop() is required here,
	# not just for real playback correctness.
	if _music_player_a != null:
		_music_player_a.stop()
	if _music_player_b != null:
		_music_player_b.stop()
	for player in _sfx_players:
		player.stop()
	current_music_track_id = ""
	last_sfx_id = ""
	last_sfx_pitch_scale = 1.0
	sfx_play_count = 0
	_warned_missing_assets.clear()


## --- Bus volume/mute -------------------------------------------------------

func set_bus_volume(bus_name: String, volume_linear: float) -> void:
	set_bus_volume_live(bus_name, volume_linear)
	_save_settings()


## Applies a bus volume change to the live AudioServer only -- does not
## persist to disk. UI callers whose input fires on every continuous tick
## (e.g. an HSlider's value_changed while being dragged -- see
## scripts/ui/audio_settings.gd) call this instead of set_bus_volume() so
## dragging stays instantly responsive without spamming a disk write per
## tick; the caller is responsible for calling save_settings() once the
## drag/adjustment completes. set_bus_volume() itself (used by every other,
## non-continuous caller: tests, mute toggles' sibling volume state, etc.)
## still applies-and-saves atomically, unchanged.
func set_bus_volume_live(bus_name: String, volume_linear: float) -> void:
	_apply_bus_volume(bus_name, clampf(volume_linear, 0.0, 1.0))


## Reads back through AudioServer (db_to_linear(get_bus_volume_db())) rather
## than a cached value, so this can never drift from what the engine is
## actually doing with the bus.
func get_bus_volume(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	var db := AudioServer.get_bus_volume_db(idx)
	# Mirrors _apply_bus_volume()'s SILENT_DB special-case for 0.0 -- without
	# this, db_to_linear(SILENT_DB) reads back as a tiny non-zero float
	# instead of an exact 0.0.
	if db <= SILENT_DB:
		return 0.0
	return clampf(db_to_linear(db), 0.0, 1.0)


## Real bus mute (AudioServer.set_bus_mute), not a zeroed volume -- keeps the
## volume slider's own value (get_bus_volume()) intact while muted, so
## un-muting restores the exact prior level rather than a lost "0". Godot's
## own audio engine silences a muted bus's output at the mix stage; this
## does not (and must not) skip play_sfx()/play_music() calls, which is what
## keeps the muted-audio / visual-feedback paths independent (see
## docs/dev/testing.md and tests/unit/test_battlefield.gd's mute-parity
## coverage).
func set_bus_mute(bus_name: String, muted: bool) -> void:
	_apply_bus_mute(bus_name, muted)
	_save_settings()


func is_bus_muted(bus_name: String) -> bool:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return false
	return AudioServer.is_bus_mute(idx)


func _apply_bus_volume(bus_name: String, volume_linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(volume_linear) if volume_linear > 0.0 else SILENT_DB)


func _apply_bus_mute(bus_name: String, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, muted)


## --- Sound effects ----------------------------------------------------------

## Plays a one-shot sound effect on the SFX bus with a randomized pitch
## offset (+/- pitch_jitter, e.g. 0.05 == +/-5%) to reduce repetition
## fatigue. Missing/unloadable assets fail soft: logged once per id (never
## spammed every call) and the caller never blocks or crashes.
func play_sfx(sfx_id: String, pitch_jitter: float = 0.05) -> void:
	var stream := _load_stream(SFX_DIR, sfx_id)
	last_sfx_id = sfx_id
	sfx_play_count += 1
	if stream == null:
		return
	var player := _acquire_sfx_player()
	var jitter: float = pitch_jitter_roll.call() * pitch_jitter
	player.pitch_scale = 1.0 + jitter
	last_sfx_pitch_scale = player.pitch_scale
	player.stream = stream
	player.play()


## Test/observability helper: true while any pooled SFX player is mid-clip.
func is_any_sfx_playing() -> bool:
	for player in _sfx_players:
		if player.playing:
			return true
	return false


func _acquire_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	# Every pooled player busy (should not happen in practice -- turn-based
	# combat never lands this many simultaneous hits): steal the first one
	# rather than growing the pool unboundedly.
	return _sfx_players[0]


## --- Music ------------------------------------------------------------------

## Crossfades to track_id over crossfade_duration seconds. A no-op if
## track_id is already the current track (repeated scene-transition calls,
## e.g. re-entering the same screen, must not restart/pop the track). Missing
## assets fail soft (logged once, current track left playing unchanged).
func play_music(track_id: String, crossfade_duration: float = DEFAULT_CROSSFADE_DURATION) -> void:
	if track_id == current_music_track_id:
		return
	var stream := _load_stream(MUSIC_DIR, track_id)
	if stream == null:
		return

	var outgoing := _active_music_player
	var incoming := _music_player_b if _active_music_player == _music_player_a else _music_player_a

	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()
	_active_music_player = incoming
	current_music_track_id = track_id

	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	var was_playing := outgoing.playing and outgoing != incoming
	if crossfade_duration <= 0.0 or not is_inside_tree():
		incoming.volume_db = 0.0
		if was_playing:
			outgoing.stop()
		return

	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.tween_property(incoming, "volume_db", 0.0, crossfade_duration)
	if was_playing:
		_music_tween.tween_property(outgoing, "volume_db", SILENT_DB, crossfade_duration)
		_music_tween.chain().tween_callback(outgoing.stop)


## Fades the current track to silence and stops it. A no-op if nothing is
## playing.
func stop_music(fade_out: float = DEFAULT_CROSSFADE_DURATION) -> void:
	var outgoing := _active_music_player
	current_music_track_id = ""
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	if not outgoing.playing:
		return
	if fade_out <= 0.0 or not is_inside_tree():
		outgoing.stop()
		outgoing.volume_db = 0.0
		return
	_music_tween = create_tween()
	_music_tween.tween_property(outgoing, "volume_db", SILENT_DB, fade_out)
	_music_tween.tween_callback(outgoing.stop)
	_music_tween.tween_callback(func() -> void: outgoing.volume_db = 0.0)


func is_music_playing(track_id: String) -> bool:
	return current_music_track_id == track_id


## True while a play_music()/stop_music() fade is actively animating a
## volume tween (Task 3's "crossfade smoothly" is otherwise unobservable
## from outside this node).
func is_crossfading() -> bool:
	return _music_tween != null and _music_tween.is_valid()


## --- Asset loading ------------------------------------------------------------

func _load_stream(dir: String, id: String) -> AudioStream:
	var path := "%s%s.wav" % [dir, id]
	if not ResourceLoader.exists(path):
		_warn_missing_once(id, path)
		return null
	var stream := ResourceLoader.load(path)
	if stream == null or not (stream is AudioStream):
		_warn_missing_once(id, path)
		return null
	return stream


func _warn_missing_once(id: String, path: String) -> void:
	if _warned_missing_assets.has(id):
		return
	_warned_missing_assets[id] = true
	push_warning("AudioManager: missing or unloadable audio asset '%s' (%s) -- playback skipped" % [id, path])


## --- Persistence --------------------------------------------------------------

func save_settings() -> void:
	_save_settings()


func load_settings() -> void:
	if not FileAccess.file_exists(settings_path):
		return
	var file := FileAccess.open(settings_path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("AudioManager: %s is not valid JSON, using default audio settings" % settings_path)
		return
	var data: Dictionary = json.data
	var volumes: Dictionary = data.get("volumes", {})
	var mutes: Dictionary = data.get("mutes", {})
	for bus_name in BUS_NAMES:
		if volumes.has(bus_name):
			_apply_bus_volume(bus_name, clampf(float(volumes[bus_name]), 0.0, 1.0))
		if mutes.has(bus_name):
			_apply_bus_mute(bus_name, bool(mutes[bus_name]))


func _save_settings() -> void:
	var volumes := {}
	var mutes := {}
	for bus_name in BUS_NAMES:
		volumes[bus_name] = get_bus_volume(bus_name)
		mutes[bus_name] = is_bus_muted(bus_name)
	var data := {"volumes": volumes, "mutes": mutes}
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file == null:
		push_error("AudioManager: could not open %s for writing (error %d)" % [settings_path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data))
	file.close()
