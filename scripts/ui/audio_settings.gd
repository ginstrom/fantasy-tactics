extends PanelContainer
## Audio Settings Panel (Technical Design §5, docs/plans/2026-08-18-core-
## loop-and-engagement/08-audio-system-and-soundscape.md): Master/Music/SFX
## volume sliders and per-bus mute toggles, all driving AudioManager
## directly -- this script never touches AudioServer or the filesystem
## itself, matching every other UI script's "GameManager/AudioManager owns
## the mechanics, this only relays intents" convention. Self-contained so it
## can be instanced from anywhere audio controls are wanted (today: embedded
## in game_menu.tscn); refresh() re-syncs every control from AudioManager's
## current state, the same "call once on _ready(), and again whenever the
## parent reopens this panel" pattern game_menu.gd's own refresh() uses.

@onready var master_slider: HSlider = $VBox/MasterRow/MasterSlider
@onready var master_mute_button: CheckButton = $VBox/MasterRow/MasterMuteButton
@onready var music_slider: HSlider = $VBox/MusicRow/MusicSlider
@onready var music_mute_button: CheckButton = $VBox/MusicRow/MusicMuteButton
@onready var sfx_slider: HSlider = $VBox/SFXRow/SFXSlider
@onready var sfx_mute_button: CheckButton = $VBox/SFXRow/SFXMuteButton

## True while one of the three sliders above is being actively mouse-dragged
## (set by that slider's own drag_started/drag_ended signals, connected in
## audio_settings.tscn). A Slider's value_changed signal fires continuously
## on every tick of a drag -- applying live audio on every tick is correct
## and stays on value_changed unconditionally below, but persisting to disk
## (AudioManager.save_settings()) and, for the SFX slider, spam-playing its
## preview click on every one of those ticks is not (see task-1-report.md's
## Finding 1/2 fix notes). Gating "not currently dragging" lets a plain click
## or a keyboard nudge -- neither of which raises drag_started/drag_ended --
## still persist/preview immediately as a single discrete change, while an
## actual mouse drag defers both exactly once, to drag_ended. Shared across
## all three sliders rather than per-slider: only one can be mouse-dragged by
## the user at a time.
var _dragging := false


func _ready() -> void:
	refresh()


func refresh() -> void:
	master_slider.value = AudioManager.get_bus_volume("Master")
	master_mute_button.button_pressed = AudioManager.is_bus_muted("Master")
	music_slider.value = AudioManager.get_bus_volume("Music")
	music_mute_button.button_pressed = AudioManager.is_bus_muted("Music")
	sfx_slider.value = AudioManager.get_bus_volume("SFX")
	sfx_mute_button.button_pressed = AudioManager.is_bus_muted("SFX")


func _on_master_slider_value_changed(value: float) -> void:
	AudioManager.set_bus_volume_live("Master", value)
	if not _dragging:
		AudioManager.save_settings()


func _on_master_slider_drag_started() -> void:
	_dragging = true


func _on_master_slider_drag_ended(_value_changed: bool) -> void:
	_dragging = false
	AudioManager.save_settings()


func _on_master_mute_toggled(pressed: bool) -> void:
	AudioManager.set_bus_mute("Master", pressed)


func _on_music_slider_value_changed(value: float) -> void:
	AudioManager.set_bus_volume_live("Music", value)
	if not _dragging:
		AudioManager.save_settings()


func _on_music_slider_drag_started() -> void:
	_dragging = true


func _on_music_slider_drag_ended(_value_changed: bool) -> void:
	_dragging = false
	AudioManager.save_settings()


func _on_music_mute_toggled(pressed: bool) -> void:
	AudioManager.set_bus_mute("Music", pressed)


## SFX slider changes also play a preview click so the player can hear the
## level they just set (see the step doc's manual-verification script:
## "Move SFX slider and confirm button click sound adjusts in volume") --
## but only once per discrete change, not on every continuous-drag tick: a
## plain click or keyboard nudge previews immediately here, while a mouse
## drag defers the preview to _on_sfx_slider_drag_ended() below, exactly
## once per drag.
func _on_sfx_slider_value_changed(value: float) -> void:
	AudioManager.set_bus_volume_live("SFX", value)
	if not _dragging:
		AudioManager.save_settings()
		AudioManager.play_sfx("sfx_ui_click")


func _on_sfx_slider_drag_started() -> void:
	_dragging = true


func _on_sfx_slider_drag_ended(_value_changed: bool) -> void:
	_dragging = false
	AudioManager.save_settings()
	AudioManager.play_sfx("sfx_ui_click")


func _on_sfx_mute_toggled(pressed: bool) -> void:
	AudioManager.set_bus_mute("SFX", pressed)


func _on_close_pressed() -> void:
	visible = false
